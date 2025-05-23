defmodule JobHunt.Resume do
  use Ecto.Schema
  import Ecto.Changeset
  alias JobHunt.Resume.Experience
  alias JobHunt.Resume.Education
  alias JobHunt.Resume.Project
  alias JobHunt.Resume.Skill

  schema "resumes" do
    field :name, :string
    embeds_many :experience, Experience, on_replace: :delete
    embeds_many :education, Education, on_replace: :delete
    embeds_many :projects, Project, on_replace: :delete
    embeds_many :skills, Skill, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(resume, attrs) do
    resume
    |> cast(attrs, [:name])
    |> cast_embed(:experience, with: &Experience.changeset/2)
    |> cast_embed(:education, with: &Education.changeset/2)
    |> cast_embed(:projects, with: &Project.changeset/2)
    |> cast_embed(:skills, with: &Skill.changeset/2)
  end
end
