defmodule JobHunt.Repo.Migrations.AddNameToResumes do
  use Ecto.Migration

  def change do
    alter table(:resumes) do
      add :name, :string
    end
  end
end
