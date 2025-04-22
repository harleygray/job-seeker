defmodule JobHunt.Repo.Migrations.UpdateJobsRelevancyScores do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :data_analyst_score, :integer
      add :ai_engineer_score, :integer
      add :product_owner, :integer
      add :data_engineer_score, :integer
      add :data_scientist_score, :integer
      add :software_engineer_score, :integer
    end

    execute """
    UPDATE jobs
    SET
      data_analyst_score = CAST(relevancy_score->>'data_analyst' AS INTEGER),
      ai_engineer_score = CAST(relevancy_score->>'ai_engineer' AS INTEGER),
      product_owner = CAST(relevancy_score->>'product_owner' AS INTEGER),
      data_engineer_score = CAST(relevancy_score->>'data_engineer' AS INTEGER),
      data_scientist_score = CAST(relevancy_score->>'data_scientist' AS INTEGER),
      software_engineer_score = CAST(relevancy_score->>'software_engineer' AS INTEGER)
    """

    alter table(:jobs) do
      remove :relevancy_score
    end
  end
end
