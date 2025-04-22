defmodule JobHunt.Resume.Experience do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :company, :string
    field :positions, {:array, :string}
    field :start_date, :date
    field :end_date, :date
    field :highlights, {:array, :string}
    field :relevant_experience, {:array, :string}
    field :technologies, {:array, :string}
  end

  def changeset(experience, attrs) do
    experience
    |> cast(attrs, [
      :company,
      :positions,
      :start_date,
      :end_date,
      :highlights,
      :relevant_experience,
      :technologies
      ])
  end
end
