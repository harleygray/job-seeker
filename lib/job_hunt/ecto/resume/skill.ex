defmodule JobHunt.Resume.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :category, :string
    field :items, {:array, :string}, default: []
  end

  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [:category, :items])
    |> validate_required([:category]) # Example validation
  end
end
