defmodule JobHuntWeb.JobLive do
  use JobHuntWeb, :live_view
  alias JobHunt.{Repo, Job, GroqClient}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    jobs = list_jobs("data_analyst_score")
    {:ok, assign(socket, jobs: jobs, selected_job: nil, sort_by: "data_analyst_score")}
  end

  @impl true
  def handle_event("select_job", %{"id" => id}, socket) do
    job = Repo.get(Job, id)
    {:noreply, assign(socket, selected_job: job)}
  end

  @impl true
  def handle_event("process_all_jobs", _, socket) do
    Task.async(fn -> process_jobs(self()) end)
    {:noreply, socket}
  end

  @impl true
  def handle_event("sort_jobs", %{"sort_select" => sort_by}, socket) do
    jobs = list_jobs(sort_by)
    {:noreply, assign(socket, jobs: jobs, sort_by: sort_by)}
  end

  @impl true
  def handle_info({:job_updated, updated_job}, socket) do
    jobs = update_job_in_list(socket.assigns.jobs, updated_job)
    {:noreply, assign(socket, jobs: jobs)}
  end

  defp update_job_in_list(jobs, updated_job) do
    Enum.map(jobs, fn job ->
      if job.id == updated_job.id, do: updated_job, else: job
    end)
  end

  defp list_jobs(sort_by) do
    Job
    |> where([j], field(j, ^String.to_existing_atom(sort_by)) >= 50)
    |> where([j], j.archived == false and j.applied == false)
    |> order_by([j], desc: field(j, ^String.to_existing_atom(sort_by)))
    |> Repo.all()
  end

  defp process_jobs(pid) do
    query =
      from j in Job,
        where:
          is_nil(j.data_analyst_score) or
            is_nil(j.data_engineer_score) or
            is_nil(j.data_scientist_score) or
            is_nil(j.software_engineer_score) or
            is_nil(j.formatted_description)

    jobs = Repo.all(query)
    total_jobs = length(jobs)

    jobs
    |> Enum.with_index(1)
    |> Enum.each(fn {job, index} ->
      case GroqClient.process_job(job.title, job.employer, job.description) do
        {:ok, %{"relevancy_scores" => scores, "formatted_description" => formatted_desc}} ->
          job
          |> Ecto.Changeset.change(%{
            data_analyst_score: scores["data_analyst"],
            data_engineer_score: scores["data_engineer"],
            data_scientist_score: scores["data_scientist"],
            software_engineer_score: scores["software_engineer"],
            formatted_description: formatted_desc
          })
          |> Repo.update!()

        {:error, reason} ->
          IO.puts("Failed to process job #{job.id}: #{inspect(reason)}")
      end

      send(pid, {:job_processed, job.id, total_jobs, index})

      if index < total_jobs do
        # 10 seconds delay
        Process.sleep(15_000)
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container-fluid mx-auto vh-100 d-flex flex-column">
      <div class="d-flex justify-content-between align-items-center mt-3">
        <h1 class="mb-0">Job Listings</h1>
        <button phx-click="process_all_jobs" class="btn btn-primary">
          Process All Jobs
        </button>
      </div>

      <.simple_form
        for={%{}}
        as={:sort}
        phx-change="sort_jobs"
        class="bg-white my-3"
        style="width: 40%;"
      >
        <.input
          type="select"
          label="Sort by:"
          id="sort_select"
          class="my-1"
          name="sort_select"
          value={@sort_by}
          options={[
            {"Data Analyst Score", "data_analyst_score"},
            {"Data Engineer Score", "data_engineer_score"},
            {"Data Scientist Score", "data_scientist_score"},
            {"Software Engineer Score", "software_engineer_score"}
          ]}
        />
      </.simple_form>

      <div class="row flex-grow-1">
        <div class="col-2 d-flex flex-column pe-0">
          <div class="job-list-container" style="height: 70vh; overflow-y: auto;">
            <div class="list-group">
              <%= for job <- @jobs do %>
                <a
                  href="#"
                  phx-click="select_job"
                  phx-value-id={job.id}
                  class="list-group-item list-group-item-action"
                >
                  <strong><%= job.title %></strong>
                  <br /><%= job.employer %>
                  <br />Score: <%= Map.get(job, String.to_existing_atom(@sort_by)) %>
                </a>
              <% end %>
            </div>
          </div>
        </div>
        <div class="col-10 d-flex flex-column ps-0">
          <%= if @selected_job do %>
            <.live_component
              module={JobHuntWeb.JobDetailComponent}
              id={@selected_job.id}
              job={@selected_job}
            />
          <% else %>
            <p>Select a job to view details</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
