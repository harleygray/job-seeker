defmodule JobHunt.Resume.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :string
    field :name, :string
    field :description, :string
    field :technologies, {:array, :string}, default: []
    field :highlights, {:array, :string}, default: []
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :id,
      :name,
      :description,
      :technologies,
      :highlights
    ])
    |> validate_required([:name, :description]) # Example validation
  end
end
