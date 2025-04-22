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
end
