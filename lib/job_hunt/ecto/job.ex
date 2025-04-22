defmodule JobHunt.Job do
  use Ecto.Schema
  import Ecto.Changeset

  schema "jobs" do
    field :title, :string
    field :employer, :string
    field :location, :string
    field :salary, :string
    field :apply_link, :string
    field :description, :string
    field :seek_job_id, :string
    field :formatted_description, :string
    field :data_analyst_score, :integer
    field :data_engineer_score, :integer
    field :data_scientist_score, :integer
    field :software_engineer_score, :integer
    field :ai_engineer_score, :integer
    field :product_owner_score, :integer
    field :applied, :boolean, default: false
    field :archived, :boolean, default: false

    timestamps()
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :title,
      :employer,
      :location,
      :salary,
      :apply_link,
      :description,
      :seek_job_id,
      :formatted_description,
      :data_analyst_score,
      :data_engineer_score,
      :data_scientist_score,
      :software_engineer_score,
      :ai_engineer_score,
      :product_owner_score,
      :applied,
      :archived
    ])
    |> validate_required([:title, :employer, :location])
  end
end
