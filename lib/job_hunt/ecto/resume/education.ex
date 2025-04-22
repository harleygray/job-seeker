defmodule JobHunt.Resume.Education do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :institution, :string
    field :courses, {:array, :string}, default: []
    field :highlights, {:array, :string}, default: []
  end

  def changeset(education, attrs) do
    education
    |> cast(attrs, [
      :institution,
      :courses,
      :highlights
      ])
  end
end
