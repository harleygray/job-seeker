defmodule JobHunt.Repo.Migrations.AddArchivedToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :archived, :boolean, default: false
    end
  end
end
