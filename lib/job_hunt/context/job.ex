defmodule JobHunt.Job.Context do
  import Ecto.Query
  alias JobHunt.Job
  alias JobHunt.Repo

  @doc """
  Returns a list of all jobs.
  """
  def list_jobs do
    Repo.all(Job)
  end

  @doc """
  Gets a single job by ID.

  Raises `Ecto.NoResultsError` if the job with the given ID doesn't exist.
  """
  def get_job!(id), do: Repo.get!(Job, id)

  @doc """
  Creates a job.
  """
  def create_job(attrs \\ %{}) do
    %Job{}
    |> Job.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a job.
  """
  def update_job(%Job{} = job, attrs) do
    job
    |> Job.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a job.
  """
  def delete_job(%Job{} = job) do
    Repo.delete(job)
  end

  @doc """
  Returns a list of jobs filtered by the given criteria.

  ## Examples

      iex> list_jobs_filtered(applied: true)
      [%Job{...}, ...]

      iex> list_jobs_filtered(archived: false, applied: false)
      [%Job{...}, ...]

  """
  def list_jobs_filtered(filters \\ []) do
    Job
    |> where(^filter_query(filters))
    |> Repo.all()
  end

  # Helper to build the dynamic filter query
  defp filter_query(filters) do
    Enum.reduce(filters, dynamic(true), fn
      {:applied, value}, query -> dynamic([j], ^query and j.applied == ^value)
      {:archived, value}, query -> dynamic([j], ^query and j.archived == ^value)
      # Add more filters here as needed
      {_, _}, query -> query # Ignore unknown filters
    end)
  end
end
