defmodule JobHunt.Resume.Education do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :string
    field :institution, :string
    field :courses, {:array, :string}, default: []
    field :highlights, {:array, :string}, default: []
  end

  def changeset(education, attrs) do
    education
    |> cast(attrs, [
      :id,
      :institution,
      :courses,
      :highlights
    ])
    |> validate_required([:institution])
  end
end
