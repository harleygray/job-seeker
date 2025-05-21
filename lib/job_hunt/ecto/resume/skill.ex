defmodule JobHunt.Resume.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :string
    field :category, :string
    field :items, {:array, :string}, default: []
  end

  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [
      :id,
      :category,
      :items
    ])
    |> validate_required([:category]) # Example validation
  end
end
