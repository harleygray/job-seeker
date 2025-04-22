defmodule ResumeFormatter do
  def format_resume(resume_content) do
    %{
      experience: format_experience(resume_content["experience"], 2),
      education: format_education(resume_content["education"]),
      projects: format_projects(resume_content["projects"]),
      skills: resume_content["skills"]
    }
  end

  defp format_experience(experience, num_highlights) do
    %{
      heading: "Experience",
      items:
        Enum.map(experience, fn exp ->
          %{
            sub_heading: "<i>#{exp["company"]}</i> - #{List.first(exp["position"])}",
            date: "#{exp["start_date"]} - #{exp["end_date"]}",
            highlights: Enum.take(exp["highlights"], num_highlights)
          }
        end)
    }
  end

  defp format_education(education) do
    %{
      heading: "Education",
      items:
        Enum.map(education, fn edu ->
          %{
            sub_heading: "<i>#{edu["institution"]}</i> - #{edu["course"]}",
            highlights: edu["highlights"]
          }
        end)
    }
  end

  defp format_projects(projects) do
    %{
      heading: "Projects",
      items:
        Enum.map(projects, fn project ->
          %{
            sub_heading: project["name"],
            description: project["description"],
            technologies: project["technologies"],
            highlights: project["highlights"]
          }
        end)
    }
  end
end
