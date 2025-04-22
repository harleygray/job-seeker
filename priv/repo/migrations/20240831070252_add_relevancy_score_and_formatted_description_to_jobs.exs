defmodule JobHunt.Repo.Migrations.AddRelevancyScoreAndFormattedDescriptionToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :relevancy_score, :map
      add :formatted_description, :text
    end
  end
end
