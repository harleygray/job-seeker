defmodule JobHuntWeb.JobLive.Resume do
  use JobHuntWeb, :live_view
  use LiveSvelte.Components
  # Assuming a Context module exists for Resumes
  alias JobHunt.Resume.Context
  alias JobHunt.Resume # Alias the main Ecto schema

  @impl true
  def mount(_params, _session, socket) do
    IO.inspect(socket.assigns.live_action, label: "Live Action in mount")

    socket =
      socket
      |> assign(:page_title, "Resumes")
      |> assign(:resumes, [])
      |> assign(:selected_resume_id, nil)
      |> assign(:selected_resume, nil)
      |> assign(:creating_resume, false)

    if connected?(socket) do
      send(self(), :load_resumes)
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    IO.inspect(assigns.live_action, label: "Live Action in render")
    ~H"""
    <div id="resume-container" class="h-screen flex flex-col bg-gray-50">
      <div class="z-50">
        <.safe_svelte name="Navbar" socket={@socket} props={%{currentPath: "/resume"}} />
      </div>

      <div class="h-full flex overflow-hidden">
        <!-- Resume List (1/4 width) -->
        <.safe_svelte
            name="admin/components/ResumeList"
            props={
              %{
                resumes: @resumes,
                selectedResumeId: @selected_resume_id
              }
            }
            socket={@socket}
            class="w-1/4"
          />

        <!-- Resume Detail (3/4 width) -->
        <.safe_svelte
            name="admin/components/ResumeDetail"
            props={
              %{
                selectedResume: @selected_resume,
                creatingResume: @creating_resume
              }
            }
            socket={@socket}
            class="w-3/4"
          />
      </div>
    </div>
    """
  end

  @impl true
  def handle_info(:load_resumes, socket) do
    # Assuming Context.list_resumes/0 exists
    resumes = Context.list_resumes()
    encoded_resumes = Enum.map(resumes, &encode_resume/1)
    socket = assign(socket, :resumes, encoded_resumes)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_resume", %{"id" => resume_id}, socket) do
    # Assuming Context.get_resume!/1 exists
    selected_resume = Context.get_resume!(resume_id)
    encoded_resume = encode_resume(selected_resume)

    socket =
      socket
      |> assign(:selected_resume_id, resume_id)
      |> assign(:selected_resume, encoded_resume)
      |> assign(:creating_resume, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_new_resume", _params, socket) do
    socket =
      socket
      |> assign(:creating_resume, true)
      |> assign(:selected_resume_id, nil)
      |> assign(:selected_resume, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_create_resume", _params, socket) do
    socket = assign(socket, :creating_resume, false)
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_resume", resume_params, socket) do
    IO.inspect(resume_params, label: "Attempting to create resume with params")
    # Assuming Context.create_resume/1 exists
    result = Context.create_resume(resume_params)
    IO.inspect(result, label: "Context.create_resume result")

    case result do
      {:ok, resume} ->
        IO.puts("Resume creation successful, sending :load_resumes")
        send(self(), :load_resumes)
        encoded_resume = encode_resume(resume)

        socket =
          socket
          |> assign(:creating_resume, false)
          |> assign(:selected_resume_id, resume.id)
          |> assign(:selected_resume, encoded_resume)
          |> put_flash(:info, "Resume created successfully.")

        {:reply, %{success: true, message: "Resume created successfully.", resume_id: resume.id}, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Changeset errors on create")
        {:reply, %{success: false, errors: translate_errors(changeset)}, socket}

      other ->
        IO.inspect(other, label: "Unexpected result from Context.create_resume")
        {:reply, %{success: false, message: "Unexpected error creating resume."}, socket}
    end
  end

  @impl true
  def handle_event("update_resume", %{"id" => resume_id} = resume_params, socket) do
    # Assuming Context.get_resume!/1 exists
    resume = Context.get_resume!(resume_id)

    # Use all params except id for update
    update_attrs = Map.delete(resume_params, "id")

    IO.inspect(update_attrs, label: "Attrs for Context.update_resume")
    # Assuming Context.update_resume/2 exists
    case Context.update_resume(resume, update_attrs) do
      {:ok, updated_resume} ->
        send(self(), :load_resumes)
        encoded_resume = encode_resume(updated_resume)

        socket =
          socket
          |> assign(:selected_resume, encoded_resume)
          |> put_flash(:info, "Resume updated successfully.")

        {:reply, %{success: true, message: "Resume updated successfully."}, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Changeset errors on update")
        {:reply, %{success: false, errors: translate_errors(changeset)}, socket}

      other ->
        IO.inspect(other, label: "Unexpected result from Context.update_resume")
        {:reply, %{success: false, message: "Unexpected error updating resume."}, socket}
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  # --- Resume Encoding ---
  # Adapt this based on the actual Resume schema and embedded schemas
  defp encode_resume(nil), do: nil
  defp encode_resume(%JobHunt.Resume{} = resume) do
    %{
      "id" => resume.id,
      "experience" => Enum.map(resume.experience, &encode_experience/1),
      "education" => Enum.map(resume.education, &encode_education/1),
      "projects" => Enum.map(resume.projects, &encode_project/1),
      "skills" => Enum.map(resume.skills, &encode_skill/1),
      "created_at" => resume.inserted_at,
      "updated_at" => resume.updated_at
    }
  end

  defp encode_experience(nil), do: nil
  defp encode_experience(%JobHunt.Resume.Experience{} = exp) do
     %{
      "company" => exp.company,
      "positions" => exp.positions,
      "start_date" => exp.start_date,
      "end_date" => exp.end_date,
      "highlights" => exp.highlights,
      "relevant_experience" => exp.relevant_experience,
      "technologies" => exp.technologies
     }
  end

  defp encode_education(nil), do: nil
  defp encode_education(%JobHunt.Resume.Education{} = edu) do
    %{
      "institution" => edu.institution,
      "courses" => edu.courses,
      "highlights" => edu.highlights
    }
  end

  defp encode_project(nil), do: nil
  defp encode_project(%JobHunt.Resume.Project{} = proj) do
     %{
      "name" => proj.name,
      "description" => proj.description,
      "technologies" => proj.technologies,
      "highlights" => proj.highlights
     }
  end

  defp encode_skill(nil), do: nil
  defp encode_skill(%JobHunt.Resume.Skill{} = skill) do
     %{
      "category" => skill.category,
      "items" => skill.items
     }
  end
end
