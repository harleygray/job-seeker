defmodule JobHuntWeb.JobLive.Resume do
  use JobHuntWeb, :live_view
  use LiveSvelte.Components
  # Assuming a Context module exists for Resumes
  alias JobHunt.Resume.Context

  @impl true
  def mount(_params, _session, socket) do
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
      |> assign(:selected_resume, %{
        "experience" => [],
        "education" => [],
        "projects" => [],
        "skills" => []
      })

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

    # Get the current state from the socket
    current_resume = socket.assigns.selected_resume

    # Use all params except id for update, or use the current resume data if no params
    update_attrs = if map_size(resume_params) > 1 do
      Map.delete(resume_params, "id")
    else
      %{
        "experience" => current_resume["experience"],
        "education" => current_resume["education"],
        "projects" => current_resume["projects"],
        "skills" => current_resume["skills"]
      }
    end

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

  @impl true
  def handle_event("form_updated", %{"id" => item_id, "form" => form_data}, socket) do
    item_id_str = to_string(item_id)

    if socket.assigns.creating_resume do
      current_data = socket.assigns.selected_resume || %{"experience" => [], "education" => [], "projects" => [], "skills" => []}

      # Find which section contains this ID
      section = cond do
        Enum.any?(current_data["experience"], &(&1["id"] == item_id_str)) -> "experience"
        Enum.any?(current_data["education"], &(&1["id"] == item_id_str)) -> "education"
        Enum.any?(current_data["projects"], &(&1["id"] == item_id_str)) -> "projects"
        Enum.any?(current_data["skills"], &(&1["id"] == item_id_str)) -> "skills"
        true -> nil
      end

      # If we found a section, update it
      updated_data = if section do
        current_items = current_data[section]
        updated_items = Enum.map(current_items, fn item ->
          if item["id"] == item_id_str do
            Map.put(form_data, "id", item_id_str)
          else
            item
          end
        end)
        Map.put(current_data, section, updated_items)
      else
        # If we didn't find the ID in any section, determine the section from the form data
        # and add it as a new item
        new_section = cond do
          Map.has_key?(form_data, "positions") -> "experience"
          Map.has_key?(form_data, "courses") -> "education"
          Map.has_key?(form_data, "description") -> "projects"
          Map.has_key?(form_data, "category") -> "skills"
          true -> nil
        end

        if new_section do
          current_items = current_data[new_section]
          updated_items = [Map.put(form_data, "id", item_id_str) | current_items]
          Map.put(current_data, new_section, updated_items)
        else
          current_data
        end
      end

      socket =
        socket
        |> assign(:selected_resume, updated_data)
        |> assign(:creating_resume, true)
      {:noreply, socket}
    else
      # In editing mode, update the socket state
      current_resume = socket.assigns.selected_resume
      if current_resume do
        # Find which section contains this ID
        existing_section = cond do
          Enum.any?(current_resume["experience"], &(&1["id"] == item_id_str)) -> "experience"
          Enum.any?(current_resume["education"], &(&1["id"] == item_id_str)) -> "education"
          Enum.any?(current_resume["projects"], &(&1["id"] == item_id_str)) -> "projects"
          Enum.any?(current_resume["skills"], &(&1["id"] == item_id_str)) -> "skills"
          true -> nil
        end

        updated_data_for_socket =
          if existing_section do
            # Update existing item in the section
            current_items = current_resume[existing_section]
            updated_items = Enum.map(current_items, fn item ->
              if item["id"] == item_id_str do
                # form_data already includes the "id" from the client
                form_data
              else
                item
              end
            end)
            Map.put(current_resume, existing_section, updated_items)
          else
            # New item: ID not found, determine section and add
            # This handles items added via "Add Experience/Education/etc." in ResumeDetail.svelte while editing
            new_item_section = cond do
              # Heuristic to determine section based on typical fields
              Map.has_key?(form_data, "company") || Map.has_key?(form_data, "positions") -> "experience"
              Map.has_key?(form_data, "institution") || Map.has_key?(form_data, "courses") -> "education"
              Map.has_key?(form_data, "name") && Map.has_key?(form_data, "description") -> "projects" # "name" is common, "description" helps disambiguate
              Map.has_key?(form_data, "category") -> "skills"
              true -> nil # Could not determine section
            end

            if new_item_section do
              current_items = Map.get(current_resume, new_item_section, []) # Ensure list exists, default to empty
              # form_data from client already contains the temporary "id"
              # Prepend new item to the list for that section
              updated_items = [form_data | current_items]
              Map.put(current_resume, new_item_section, updated_items)
            else
              # Could not determine section for the new item, log or handle as error?
              # For now, return current_resume unchanged to avoid crashing.
              IO.inspect(form_data, label: "Could not determine section for new item in form_updated (edit mode)")
              current_resume
            end
          end
        socket = assign(socket, :selected_resume, updated_data_for_socket)
        {:noreply, socket}
      else
        # No current_resume selected, though this path implies editing an existing one.
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("save_experience_item", %{"id" => item_id}, socket) do
    item_id_str = to_string(item_id)
    current_resume = socket.assigns.selected_resume

    if current_resume do
      # Find the experience item in the current state
      experience_item = Enum.find(current_resume["experience"], &(&1["id"] == item_id_str))

      if experience_item do
        # Update the database
        resume = Context.get_resume!(socket.assigns.selected_resume_id)
        case Context.update_resume(resume, current_resume) do
          {:ok, updated_resume} ->
            encoded_resume = encode_resume(updated_resume)
            send(self(), :load_resumes)
            socket = assign(socket, :selected_resume, encoded_resume)
            {:reply, %{success: true, message: "Experience item saved successfully.", resume: encoded_resume}, socket}
          {:error, changeset} ->
            IO.inspect(changeset, label: "Error saving experience item")
            {:reply, %{success: false, message: "Error saving experience item."}, socket}
        end
      else
        {:reply, %{success: false, message: "Experience item not found."}, socket}
      end
    else
      {:reply, %{success: false, message: "No resume selected."}, socket}
    end
  end

  @impl true
  def handle_event("remove_experience_item", %{"id" => item_id_to_remove}, socket) do
    item_id_str = to_string(item_id_to_remove)

    if socket.assigns.creating_resume do
      # In creating mode, just update the socket state
      current_data = socket.assigns.selected_resume || %{"experience" => []}

      # Match either the string ID or the struct's id field
      updated_experience = Enum.reject(current_data["experience"], fn item ->
        case item do
          %{"id" => id} when is_binary(id) ->
            id == item_id_str
          %{id: id} when is_binary(id) ->
            id == item_id_str
          _ ->
            false
        end
      end)

      updated_socket_data = %{current_data | "experience" => updated_experience}

      socket =
        socket
        |> assign(:selected_resume, updated_socket_data)
        |> assign(:creating_resume, true)

      {:noreply, socket}
    else
      # In editing mode, update the database
      resume_id = socket.assigns.selected_resume_id
      if resume_id do
        resume = Context.get_resume!(resume_id)
        # Match either the string ID or the struct's id field
        updated_experience_list = Enum.reject(resume.experience, fn exp ->
          case exp do
            %{id: id} when is_binary(id) -> id == item_id_str
            _ -> false
          end
        end)

        case Context.update_resume(resume, %{experience: updated_experience_list}) do
          {:ok, updated_resume_db} ->
            encoded_resume = encode_resume(updated_resume_db)
            send(self(), :load_resumes) # Reload list to reflect changes
            socket = assign(socket, :selected_resume, encoded_resume)
            {:noreply, socket}
          {:error, changeset} ->
            IO.inspect(changeset, label: "Error removing experience item")
            {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("remove_education_item", %{"id" => item_id_to_remove}, socket) do
    item_id_str = to_string(item_id_to_remove)

    if socket.assigns.creating_resume do
      # In creating mode, just update the socket state
      current_data = socket.assigns.selected_resume || %{"education" => []}
      # Match either the string ID or the struct's id field
      updated_education = Enum.reject(current_data["education"], fn item ->
        case item do
          %{"id" => id} when is_binary(id) -> id == item_id_str
          %{id: id} when is_binary(id) -> id == item_id_str
          _ -> false
        end
      end)
      updated_socket_data = %{current_data | "education" => updated_education}

      socket =
        socket
        |> assign(:selected_resume, updated_socket_data)
        |> assign(:creating_resume, true)

      {:noreply, socket}
    else
      # In editing mode, update the database
      resume_id = socket.assigns.selected_resume_id
      if resume_id do
        resume = Context.get_resume!(resume_id)
        # Match either the string ID or the struct's id field
        updated_education_list = Enum.reject(resume.education, fn edu ->
          case edu do
            %{id: id} when is_binary(id) -> id == item_id_str
            _ -> false
          end
        end)

        case Context.update_resume(resume, %{education: updated_education_list}) do
          {:ok, updated_resume_db} ->
            encoded_resume = encode_resume(updated_resume_db)
            send(self(), :load_resumes) # Reload list to reflect changes
            socket = assign(socket, :selected_resume, encoded_resume)
            {:noreply, socket}
          {:error, changeset} ->
            IO.inspect(changeset, label: "Error removing education item")
            {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("remove_project_item", %{"id" => item_id_to_remove}, socket) do
    item_id_str = to_string(item_id_to_remove)
    current_data = socket.assigns.selected_resume || %{"projects" => []}

    updated_projects = Enum.reject(current_data["projects"], &(&1["id"] == item_id_str))
    updated_data = %{current_data | "projects" => updated_projects}

    socket = assign(socket, :selected_resume, updated_data)
    socket = if socket.assigns.creating_resume, do: assign(socket, :creating_resume, true), else: socket

    # If we're not in creating mode, update the resume in the database
    if !socket.assigns.creating_resume && socket.assigns.selected_resume_id do
      case Context.update_resume(socket.assigns.selected_resume_id, updated_data) do
        {:ok, _updated_resume} -> {:noreply, socket}
        {:error, _changeset} -> {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_skill_item", %{"id" => item_id_to_remove}, socket) do
    item_id_str = to_string(item_id_to_remove)
    current_data = socket.assigns.selected_resume || %{"skills" => []}

    updated_skills = Enum.reject(current_data["skills"], &(&1["id"] == item_id_str))
    updated_data = %{current_data | "skills" => updated_skills}

    socket = assign(socket, :selected_resume, updated_data)
    socket = if socket.assigns.creating_resume, do: assign(socket, :creating_resume, true), else: socket

    # If we're not in creating mode, update the resume in the database
    if !socket.assigns.creating_resume && socket.assigns.selected_resume_id do
      case Context.update_resume(socket.assigns.selected_resume_id, updated_data) do
        {:ok, _updated_resume} -> {:noreply, socket}
        {:error, _changeset} -> {:noreply, socket}
      end
    else
      {:noreply, socket}
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
  defp encode_resume(nil), do: nil
  defp encode_resume(%JobHunt.Resume{} = resume) do
    %{
      "id" => resume.id,
      "name" => resume.name,
      "experience" => Enum.map(resume.experience, &encode_experience/1),
      "education" => Enum.map(resume.education, &encode_education/1),
      "projects" => Enum.map(resume.projects, &encode_project/1),
      "skills" => Enum.map(resume.skills, &encode_skill/1),
      "created_at" => format_datetime(resume.inserted_at),
      "updated_at" => format_datetime(resume.updated_at)
    }
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(%NaiveDateTime{} = ndt) do
    DateTime.from_naive!(ndt, "Etc/UTC") |> DateTime.to_iso8601()
  end

  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp encode_experience(nil), do: nil
  defp encode_experience(%JobHunt.Resume.Experience{} = exp) do
     %{
      "id" => exp.id,
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
      "id" => edu.id,
      "institution" => edu.institution,
      "courses" => edu.courses,
      "highlights" => edu.highlights
    }
  end

  defp encode_project(nil), do: nil
  defp encode_project(%JobHunt.Resume.Project{} = proj) do
    %{
      "id" => proj.id,
      "name" => proj.name,
      "description" => proj.description,
      "technologies" => proj.technologies,
      "highlights" => proj.highlights
    }
  end

  defp encode_skill(nil), do: nil
  defp encode_skill(%JobHunt.Resume.Skill{} = skill) do
    %{
      "id" => skill.id,
      "category" => skill.category,
      "items" => skill.items
    }
  end
end
