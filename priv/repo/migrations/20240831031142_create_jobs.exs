defmodule JobHunt.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :title, :string
      add :employer, :string
      add :location, :string
      add :salary, :string
      add :apply_link, :string
      add :description, :text
      add :seek_job_id, :string

      timestamps()
    end

    create unique_index(:jobs, [:seek_job_id])
  end
end
