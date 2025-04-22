defmodule JobHuntWeb.JobDetailComponent do
  use JobHuntWeb, :live_component
  alias Earmark
  alias JobHunt.{CVGenerator, CoverLetterGenerator, Job, Repo}
  @dialyzer {:nowarn_function, handle_event: 3}

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       cv_html_content1: nil,
       cv_html_content2: nil,
       cover_letter_html_content: nil,
       edited_cover_letter_content: nil,
       edited_cv1_content: nil,
       edited_cv2_content: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="d-flex">
      <div class={
        if assigns[:cv_html_content1] && assigns[:cv_html_content2],
          do: "card me-3 job-details",
          else: "card w-100 job-details"
      }>
        <div class="card-body overflow-auto" style="max-height: calc(100vh - 200px);">
          <div class="d-flex justify-content-between align-items-center sticky-top bg-white py-2">
            <h5 class="card-title mb-0"><%= @job.title %></h5>
            <div class="d-flex justify-content-between align-items-center">
              <div class="form-check me-2">
                <input
                  type="checkbox"
                  class="form-check-input"
                  id="applied-checkbox"
                  phx-click="toggle_applied"
                  phx-target={@myself}
                  phx-value-id={@job.id}
                  checked={@job.applied}
                />
                <label class="form-check-label" for="applied-checkbox">Applied</label>
              </div>
              <a href={@job.apply_link} class="btn btn-primary me-2" target="_blank">Apply</a>
              <button
                phx-click="generate_pdf"
                phx-target={@myself}
                phx-value-path="desired_path"
                class="btn btn-secondary me-2"
              >
                Generate PDF
              </button>

              <div class="form-group">
                <button
                  class="btn btn-secondary"
                  phx-click="toggle_archived"
                  phx-target={@myself}
                  phx-value-id={@job.id}
                >
                  <%= if @job.archived, do: "Unarchive", else: "Archive" %>
                </button>
              </div>
            </div>
          </div>
          <h6 class="card-subtitle mb-2 text-muted"><%= @job.employer %></h6>
          <p class="card-text"><strong>Location:</strong> <%= @job.location %></p>
          <p class="card-text"><strong>Salary:</strong> <%= @job.salary %></p>

          <h6 class="mt-4"><strong>Relevancy Scores:</strong></h6>
          <div class="d-flex justify-content-between mb-3">
            <%= render_score_box(assigns, "Data Analyst", @job.data_analyst_score, "bg-primary") %>
            <%= render_score_box(assigns, "Data Engineer", @job.data_engineer_score, "bg-success") %>
            <%= render_score_box(assigns, "Data Scientist", @job.data_scientist_score, "bg-info") %>
            <%= render_score_box(
              assigns,
              "Software Engineer",
              @job.software_engineer_score,
              "bg-warning"
            ) %>
          </div>
          <%= if @job.formatted_description do %>
            <h6><strong>Formatted Description:</strong></h6>
            <div><%= Phoenix.HTML.raw(Earmark.as_html!(@job.formatted_description)) %></div>
          <% end %>

          <p class="card-text"><strong>Raw Description:</strong> <%= @job.description %></p>
        </div>
      </div>

      <%= if assigns[:cv_html_content1] && assigns[:cv_html_content2] && assigns[:cover_letter_html_content] do %>
        <div class="card cv-preview">
          <div class="card-body d-flex flex-column">
            <h5 class="card-title">Generated CV Preview</h5>
            <button phx-click="confirm_pdf" phx-target={@myself} class="btn btn-primary mt-3 mb-3">
              Confirm and Generate PDF
            </button>
            <div class="cv-preview-pages">
              <div class="cv-preview-container mt-0">
                <iframe
                  id="cv-editor-frame1"
                  class="cv-preview-iframe mb-3"
                  srcdoc={iframe_content(@cv_html_content1)}
                  phx-hook="CVEditor1"
                  phx-target={@myself}
                >
                </iframe>

                <iframe
                  id="cv-editor-frame2"
                  class="cv-preview-iframe"
                  srcdoc={iframe_content(@cv_html_content2)}
                  phx-hook="CVEditor2"
                  phx-target={@myself}
                >
                </iframe>

                <iframe
                  id="cover-letter-editor-frame"
                  class="cv-preview-iframe"
                  srcdoc={iframe_content(@cover_letter_html_content)}
                  phx-hook="CoverLetterEditor"
                  phx-target={@myself}
                >
                </iframe>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp iframe_content(content) do
    """
    <html>
      <head>
        <style>
          body {
            font-family: Arial, sans-serif;
            font-size: 12pt;
            line-height: 1.5;
            padding: 20mm;
            margin: 0;
            outline: none;
            min-height: 297mm;
          }
        </style>
      </head>
      <body contenteditable="true">
        #{content}
      </body>
    </html>
    """
  end

  defp render_score_box(assigns, role, score, color_class) when is_integer(score) do
    assigns = assign(assigns, role: role, score: score, color_class: color_class)

    ~H"""
    <div class={@color_class <> " text-white p-2 rounded"}>
      <small><%= @role %></small>
      <div class="fw-bold"><%= @score %></div>
    </div>
    """
  end

  def handle_event("update_cover_letter", %{"content" => content}, socket) do
    {:noreply, assign(socket, edited_cover_letter_content: content)}
  end

  def handle_event("update_cv1", %{"content" => content}, socket) do
    {:noreply, assign(socket, edited_cv1_content: content)}
  end

  def handle_event("update_cv2", %{"content" => content}, socket) do
    {:noreply, assign(socket, edited_cv2_content: content)}
  end

  def handle_event("toggle_applied", %{"id" => id} = params, socket) do
    job = Repo.get(Job, id)
    applied = Map.get(params, "value", "off") == "on"

    case Repo.update(Job.changeset(job, %{applied: applied})) do
      {:ok, updated_job} ->
        {:noreply, assign(socket, job: updated_job)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update application status")}
    end
  end

  def handle_event("toggle_archived", %{"id" => id}, socket) do
    job = Repo.get(Job, id)
    new_archived_status = not job.archived

    case Repo.update(Job.changeset(job, %{archived: new_archived_status})) do
      {:ok, updated_job} ->
        send(self(), {:job_updated, updated_job})
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update archive status")}
    end
  end

  def handle_event("generate_pdf", _, socket) do
    {cv_html_content1, cv_html_content2} = CVGenerator.generate_html()

    company_name = socket.assigns.job.employer
    addressee = "Not specified"
    position_description = socket.assigns.job.description

    {cover_letter_html_content} =
      CoverLetterGenerator.generate_html(position_description, addressee, company_name)

    {:noreply,
     assign(socket,
       cv_html_content1: cv_html_content1,
       cv_html_content2: cv_html_content2,
       cover_letter_html_content: cover_letter_html_content
     )}
  end

  def handle_event("confirm_pdf", _, socket) do
    %{
      cv_html_content1: cv_html_content1,
      cv_html_content2: cv_html_content2,
      cover_letter_html_content: cover_letter_html_content
    } = socket.assigns

    # Use the edited content if available, otherwise fall back to the original
    cover_letter_content =
      Map.get(socket.assigns, :edited_cover_letter_content, cover_letter_html_content)

    cv_html_content1 = Map.get(socket.assigns, :edited_cv1_content, cv_html_content1)
    cv_html_content2 = Map.get(socket.assigns, :edited_cv2_content, cv_html_content2)

    company_name = socket.assigns.job.employer

    cv_result = CVGenerator.generate_pdf(cv_html_content1, cv_html_content2, company_name)

    _cover_letter_result =
      CoverLetterGenerator.generate_pdf(cover_letter_content, company_name)

    # Stop the ChromicPDF Supervisor
    Supervisor.stop(ChromicPDF)

    case cv_result do
      {:ok, cv_pdf_path} ->
        {:noreply, assign(socket, cv_pdf_path: cv_pdf_path)}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to generate PDF")}
    end
  end
end
