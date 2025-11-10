defmodule JobHunt.Repo.Migrations.CreateJobsIncludeSelectionCriteria do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :include_selection_criteria, :boolean, default: false, null: false
    end
  end
end
