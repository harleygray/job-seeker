defmodule JobHuntWeb.JobLive.Interface do
  use JobHuntWeb, :live_view
  use LiveSvelte.Components
  alias JobHunt.Job.Context

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Job Interface")
      |> assign(:jobs, [])
      |> assign(:selected_job_id, nil)
      |> assign(:selected_job, nil)
      |> assign(:creating_job, false)

    if connected?(socket) do
      send(self(), :load_jobs)
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="interface-container" class="h-screen flex flex-col bg-gray-50" style="min-width: 100vw;">
      <div class="z-50">
        <.safe_svelte name="Navbar" socket={@socket} currentPath="/" />
      </div>

      <div class="h-full relative overflow-hidden" style="min-width: 100%;">
        <!-- Job List (1/4 width) - Fixed position -->
        <div class="absolute left-0 top-0 bottom-0" style="width: 25%; min-width: 25%; max-width: 25%;">
          <.safe_svelte
              name="admin/components/JobList"
              props={
                %{
                  jobs: @jobs,
                  selectedJobId: @selected_job_id
                }
              }
              socket={@socket}
              class="w-full h-full"
            />
        </div>

        <!-- Job Detail (3/4 width) - Fixed position -->
        <div class="absolute right-0 top-0 bottom-0" style="width: 75%; min-width: 75%; max-width: 75%;">
          <.safe_svelte
            name="admin/components/JobDetail"
            props={%{selectedJob: @selected_job, creatingJob: @creating_job}}
            socket={@socket}
            class="w-full h-full"
          />
        </div>
      </div>

      </div>

    """
  end


  @impl true
  def handle_info(:load_jobs, socket) do
    jobs = Context.list_jobs_filtered(archived: false, applied: false)
    encoded_jobs = Enum.map(jobs, &encode_job/1)
    # IO.inspect(encoded_jobs, label: "Encoded jobs")
    socket = assign(socket, :jobs, encoded_jobs)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_job", %{"id" => job_id}, socket) do
    selected_job = Context.get_job!(job_id)
    encoded_job = encode_job(selected_job)

    socket =
      socket
      |> assign(:selected_job_id, job_id)
      |> assign(:selected_job, encoded_job) # Assign encoded job
      |> assign(:creating_job, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_new_job", _params, socket) do
    socket =
      socket
      |> assign(:creating_job, true)
      |> assign(:selected_job_id, nil)
      |> assign(:selected_job, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_create_job", _params, socket) do
    socket = assign(socket, :creating_job, false)
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_job", job_params, socket) do
    IO.inspect(job_params, label: "Attempting to create job with params")
    result = Context.create_job(job_params)
    IO.inspect(result, label: "Context.create_job result")

    case result do
      {:ok, job} ->
        IO.puts("Job creation successful, sending :load_jobs")
        send(self(), :load_jobs)
        encoded_job = encode_job(job)

        socket =
          socket
          |> assign(:creating_job, false)
          |> assign(:selected_job_id, job.id)
          |> assign(:selected_job, encoded_job) # Assign encoded job
          |> put_flash(:info, "Job created successfully.")

        {:reply, %{success: true, message: "Job created successfully.", job_id: job.id}, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Changeset errors on create")
        {:reply, %{success: false, errors: translate_errors(changeset)}, socket}

      other ->
        IO.inspect(other, label: "Unexpected result from Context.create_job")
        {:reply, %{success: false, message: "Unexpected error creating job."}, socket}
    end
  end

  @impl true
  def handle_event("update_job", %{"id" => job_id} = job_params, socket) do
    job = Context.get_job!(job_id)

    # Translate incoming status to actual DB fields if present
    update_attrs =
      if status = job_params["status"] do
         params_from_status(status)
      else
        # If status isn't the only param, handle others (e.g., from full form save)
        job_params
        |> Map.delete("id") # Remove id as it's not a schema field
        |> Map.delete("status") # Remove derived status if present
      end

    IO.inspect(update_attrs, label: "Attrs for Context.update_job")

    case Context.update_job(job, update_attrs) do
      {:ok, updated_job} ->
        send(self(), :load_jobs)
        encoded_job = encode_job(updated_job)

        socket =
          socket
          |> assign(:selected_job, encoded_job)
          |> put_flash(:info, "Job updated successfully.")

        {:reply, %{success: true, message: "Job updated successfully."}, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Changeset errors on update")
        {:reply, %{success: false, errors: translate_errors(changeset)}, socket}

      other ->
        IO.inspect(other, label: "Unexpected result from Context.update_job")
        {:reply, %{success: false, message: "Unexpected error updating job."}, socket}
    end
  end

  @impl true
  def handle_event("generate_cv", %{"jobId" => job_id}, socket) do
    job = Context.get_job!(job_id)
    {html_content1, html_content2} = JobHunt.CVGenerator.generate_html()
    {cover_letter} = JobHunt.CoverLetterGenerator.generate_html(
      job.description,
      "Not specified",  # We can add a field for addressee later if needed
      job.employer
    )

    {:reply, %{
      success: true,
      cv_page1: html_content1,
      cv_page2: html_content2,
      cover_letter: cover_letter
    }, socket}
  end

  @impl true
  def handle_event("generate_pdf", %{
    "cv_content1" => content1,
    "cv_content2" => content2,
    "cover_letter_content" => cover_letter,
    "companyName" => company_name
  }, socket) do
    try do
            # Create the generated_pdfs/company directory if it doesn't exist
      safe_company_name = String.replace(company_name, ~r/[^a-zA-Z0-9_-]/, "_")
      company_dir = Path.join([Application.app_dir(:job_hunt, "priv"), "static", "generated_pdfs", safe_company_name])
      File.mkdir_p!(company_dir)

      # Generate unique filename with timestamp
      timestamp = DateTime.utc_now() |> DateTime.to_unix()

      # PDF generation options - no margins
      pdf_options = %{
        format: "A4",
        margin: %{
          top: "0",
          bottom: "0",
          left: "0",
          right: "0"
        }
      }

      print_to_pdf_options = %{
        print_background: true,
        prefer_css_page_size: false,
        display_header_footer: false,
        margin_top: 0,
        margin_bottom: 0,
        margin_left: 0,
        margin_right: 0
      }

            # Generate CV PDF (2 pages)
      cv_filename = "CV_#{timestamp}.pdf"
      cv_output_path = Path.join(company_dir, cv_filename)

      # Generate Cover Letter PDF (separate file)
      cover_filename = "CoverLetter_#{timestamp}.pdf"
      cover_output_path = Path.join(company_dir, cover_filename)

      # Add CSS to remove only page margins, preserve content styling, and force background colors
      css_reset = "<style>@page { margin: 0 !important; } html, body { margin: 0 !important; padding: 0 !important; } * { -webkit-print-color-adjust: exact !important; color-adjust: exact !important; print-color-adjust: exact !important; }</style>"
      content1_with_css = String.replace(content1, "<head>", "<head>#{css_reset}", global: false) |>
                          (&if String.contains?(&1, "<head>"), do: &1, else: "#{css_reset}#{content1}").()
      content2_with_css = String.replace(content2, "<head>", "<head>#{css_reset}", global: false) |>
                          (&if String.contains?(&1, "<head>"), do: &1, else: "#{css_reset}#{content2}").()
      cover_letter_with_css = String.replace(cover_letter, "<head>", "<head>#{css_reset}", global: false) |>
                              (&if String.contains?(&1, "<head>"), do: &1, else: "#{css_reset}#{cover_letter}").()

      # Generate CV PDF
      cv_result = ChromicPDF.print_to_pdf([{:html, content1_with_css}, {:html, content2_with_css}],
        output: cv_output_path,
        pdf_options: pdf_options,
        print_to_pdf: print_to_pdf_options
      )

      # Generate Cover Letter PDF
      cover_result = ChromicPDF.print_to_pdf([{:html, cover_letter_with_css}],
        output: cover_output_path,
        pdf_options: pdf_options,
        print_to_pdf: print_to_pdf_options
      )

      case {cv_result, cover_result} do
        {:ok, :ok} ->
          # Return relative paths for both files
          cv_relative_path = "/generated_pdfs/#{safe_company_name}/#{cv_filename}"
          cover_relative_path = "/generated_pdfs/#{safe_company_name}/#{cover_filename}"
          {:reply, %{
            success: true,
            cv_path: cv_relative_path,
            cover_letter_path: cover_relative_path
          }, socket}


        other ->
          {:reply, %{success: false, error: "Unexpected PDF generation result: #{inspect(other)}"}, socket}
      end
    rescue
      error ->
        {:reply, %{success: false, error: "PDF generation failed: #{inspect(error)}"}, socket}
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  # Encoder function for Job struct
  defp encode_job(nil), do: nil
  defp encode_job(%JobHunt.Job{} = job) do
    %{
      "id" => job.id,
      "title" => job.title,
      "employer" => job.employer,
      "location" => job.location || "",
      "salary" => job.salary || "",
      "apply_link" => job.apply_link || "",
      "description" => job.description || "",
      "status" => job_status(job),
      "seek_job_id" => job.seek_job_id || "",
      "formatted_description" => job.formatted_description || "",
      "data_analyst_score" => job.data_analyst_score || 0,
      "data_engineer_score" => job.data_engineer_score || 0,
      "data_scientist_score" => job.data_scientist_score || 0,
      "software_engineer_score" => job.software_engineer_score || 0,
      "ai_engineer_score" => job.ai_engineer_score || 0,
      "product_owner_score" => job.product_owner_score || 0,
      "applied" => job.applied || false,
      "archived" => job.archived || false,
      "created_at" => job.inserted_at,
      "updated_at" => job.updated_at
    }
  end

  # Helper to translate status string back to DB fields
  defp params_from_status("Active") do
    %{archived: false} # Active means not archived
  end
  defp params_from_status("Archived") do
    %{archived: true} # Archived means archived
  end
  # Fallback for unknown status - maybe return empty map or log error
  defp params_from_status(unknown_status) do
    IO.inspect(unknown_status, label: "Received unknown status for update")
    %{} # Return empty map - don't change archive status for unknown input
  end

  # Helper to determine status for encoding (adjust logic as needed)
  defp job_status(%JobHunt.Job{archived: true}), do: "Archived"
  defp job_status(_), do: "Active" # Default to Active if not archived
end
