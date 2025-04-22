defmodule JobHunt.Resume do
  use Ecto.Schema
  import Ecto.Changeset
  alias JobHunt.Resume.Experience
  alias JobHunt.Resume.Education
  alias JobHunt.Resume.Project
  alias JobHunt.Resume.Skill

  schema "resumes" do
    embeds_many :experience, Experience
    embeds_many :education, Education
    embeds_many :projects, Project
    embeds_many :skills, Skill

    timestamps()
  end

  @doc false
  def changeset(resume, attrs) do
    resume
    |> cast(attrs, [])
    |> cast_embed(:experience, with: &Experience.changeset/2)
    |> cast_embed(:education, with: &Education.changeset/2)
    |> cast_embed(:projects, with: &Project.changeset/2)
    |> cast_embed(:skills, with: &Skill.changeset/2)
  end
end
