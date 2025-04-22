defmodule JobHunt.Repo.Migrations.CreateResumes do
  use Ecto.Migration

  def change do
    create table(:resumes) do
      add :experience, :map, default: %{}
      add :education, :map, default: %{}
      add :projects, :map, default: %{}
      add :skills, :map, default: %{}

      timestamps()
    end
  end
end
