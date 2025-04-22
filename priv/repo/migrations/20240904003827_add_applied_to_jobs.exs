defmodule JobHunt.Repo.Migrations.AddAppliedToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :applied, :boolean, default: false
    end
  end
end
