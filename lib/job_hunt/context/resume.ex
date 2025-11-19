defmodule JobHunt.Resume.Context do
  @moduledoc """
  The context for managing Resumes.
  """

  import Ecto.Query, warn: false
  alias JobHunt.Repo

  alias JobHunt.Resume # Alias the main Ecto schema

  @doc """
  Returns the list of resumes.

  ## Examples

      iex> list_resumes()
      [%Resume{}, ...]

  """
  def list_resumes do
    Repo.all(Resume)
  end

  @doc """
  Gets the most recently updated resume.

  Returns nil if no resume exists.

  ## Examples

      iex> get_most_recent_resume()
      %Resume{}

      iex> get_most_recent_resume()
      nil

  """
  def get_most_recent_resume do
    Resume
    |> order_by([r], desc: r.updated_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets a single resume.

  Raises `Ecto.NoResultsError` if the Resume does not exist.

  ## Examples

      iex> get_resume!(123)
      %Resume{}

      iex> get_resume!(456)
      ** (Ecto.NoResultsError)

  """
  def get_resume!(id), do: Repo.get!(Resume, id)

  @doc """
  Creates a resume.

  ## Examples

      iex> create_resume(%{field: value})
      {:ok, %Resume{}} # Changeset is valid

      iex> create_resume(%{field: bad_value})
      {:error, %Ecto.Changeset{}} # Changeset is invalid

  """
  def create_resume(attrs \\ %{}) do
    %Resume{}
    |> Resume.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resume.

  ## Examples

      iex> update_resume(resume, %{field: new_value})
      {:ok, %Resume{}} # Changeset is valid

      iex> update_resume(resume, %{field: bad_value})
      {:error, %Ecto.Changeset{}} # Changeset is invalid

  """
  def update_resume(%Resume{} = resume, attrs) do
    resume
    |> Resume.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resume.

  ## Examples

      iex> delete_resume(resume)
      {:ok, %Resume{}}

      iex> delete_resume(resume)
      {:error, %Ecto.Changeset{}}

  """
  def delete_resume(%Resume{} = resume) do
    Repo.delete(resume)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resume changes.

  ## Examples

      iex> change_resume(resume)
      %Ecto.Changeset{source: %Resume{}}

  """
  def change_resume(%Resume{} = resume, attrs \\ %{}) do
    Resume.changeset(resume, attrs)
  end

  @doc """
  Duplicates a resume with a new name "{original_name} - Copy".

  ## Examples

      iex> duplicate_resume(resume)
      {:ok, %Resume{}}

      iex> duplicate_resume(resume)
      {:error, %Ecto.Changeset{}}

  """
  def duplicate_resume(%Resume{} = resume) do
    # Helper function to generate a unique ID
    generate_id = fn ->
      :crypto.strong_rand_bytes(16)
      |> Base.encode16(case: :lower)
    end

    # Convert embedded structs to maps and generate new IDs
    attrs = %{
      name: "#{resume.name} - Copy",
      experience: Enum.map(resume.experience, fn exp ->
        %{
          id: generate_id.(),
          company: exp.company,
          positions: exp.positions,
          start_date: exp.start_date,
          end_date: exp.end_date,
          highlights: exp.highlights,
          relevant_experience: exp.relevant_experience,
          technologies: exp.technologies
        }
      end),
      education: Enum.map(resume.education, fn edu ->
        %{
          id: generate_id.(),
          institution: edu.institution,
          courses: edu.courses,
          highlights: edu.highlights
        }
      end),
      projects: Enum.map(resume.projects, fn proj ->
        %{
          id: generate_id.(),
          name: proj.name,
          description: proj.description,
          technologies: proj.technologies,
          highlights: proj.highlights
        }
      end),
      skills: Enum.map(resume.skills, fn skill ->
        %{
          id: generate_id.(),
          category: skill.category,
          items: skill.items
        }
      end)
    }

    create_resume(attrs)
  end
end
