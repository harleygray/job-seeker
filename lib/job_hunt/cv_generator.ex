defmodule JobHunt.CVGenerator do
  require EEx
  alias JobHunt.Resume.Context

  left_column_template_path =
    Path.join(
      :code.priv_dir(:job_hunt),
      "static/templates/left_column.html.heex"
    )

  EEx.function_from_file(:def, :render_left_column, left_column_template_path, [:assigns])

  def generate_html() do
    css_styles_path = Path.join(:code.priv_dir(:job_hunt), "static/cv_styles.html")
    css_styles = File.read!(css_styles_path)

    # Read the SVG files
    phone_svg = File.read!("#{File.cwd!()}/priv/static/images/phone.svg")
    linked_in_svg = File.read!("#{File.cwd!()}/priv/static/images/linked_in.svg")
    x_svg = File.read!("#{File.cwd!()}/priv/static/images/x.svg")
    email_svg = File.read!("#{File.cwd!()}/priv/static/images/email.svg")
    image_path = Path.join(:code.priv_dir(:job_hunt), "static/images/harley.jpg")
    image_data = File.read!(image_path) |> Base.encode64()
    profile_image = "<img src=\"data:image/jpeg;base64,#{image_data}\" class=\"profile-image\">"

    # Get the most recent resume from the database
    resume = Context.get_most_recent_resume()

    if is_nil(resume) do
      raise "No resume found in the database"
    end

    # Format the resume data
    formatted_resume = %{
      projects: %{
        heading: "Projects",
        items: (resume.projects || []) |> Enum.map(fn project ->
          %{
            sub_heading: project.name,
            description: project.description,
            highlights: project.highlights || [],
            technologies: project.technologies || []
          }
        end)
      },
      experience: %{
        heading: "Experience",
        items: (resume.experience || []) |> Enum.map(fn exp ->
          %{
            sub_heading: exp.company,
            date: "#{exp.start_date} - #{exp.end_date}",
            highlights: exp.highlights || [],
            technologies: exp.technologies || []
          }
        end)
      },
      education: %{
        heading: "Education",
        items: (resume.education || []) |> Enum.map(fn edu ->
          %{
            sub_heading: edu.institution,
            highlights: edu.highlights || []
          }
        end)
      }
    }

    # Generate HTML for introduction and projects sections from resume
    formatted_resume_html_pg1 =
      [:projects]
      |> Enum.map(fn section_key ->
        section = Map.get(formatted_resume, section_key, %{heading: "", items: []})

        """
        <h2 class="heading-option">#{section.heading}</h2>
        #{Enum.map(section.items, fn item -> """
          <div class="item-container">
            <div class="sub-heading-container">
              <h3 class="sub-heading-title">#{item.sub_heading}</h3>
              #{if Map.has_key?(item, :description), do: "<p class=\"date-text\" style=\"margin-bottom: 0px;\">#{item.description}</p>", else: ""}
            </div>
          </div>
          <ul class="highlights-list">
            #{Enum.map(item.highlights, fn highlight -> "<li class=\"highlights-list-item\"><span>#{highlight}</span></li>" end) |> Enum.join("\n")}
          </ul>
          <div class="technologies-container">
          #{if Map.has_key?(item, :technologies),
            do: Enum.map(item.technologies, fn tech ->
              trimmed_tech = String.trim(tech)
              if String.starts_with?(trimmed_tech, "*") and String.ends_with?(trimmed_tech, "*") do
                highlighted_tech = trimmed_tech |> String.replace(~r/^\*(.+)\*$/, "\\1") |> String.trim()
                "<span class=\"technology-card highlighted-tech\">#{highlighted_tech}</span>"
              else
                "<span class=\"technology-card\">#{trimmed_tech}</span>"
              end
            end) |> Enum.join(" "),
            else: ""}
          </div>
          """ end) |> Enum.join("\n")}
        """
      end)
      |> Enum.join("\n")

    # Generate HTML for experience and education sections from resume
    formatted_resume_html_pg2 =
      [:experience, :education]
      |> Enum.map(fn section_key ->
        section = Map.get(formatted_resume, section_key, %{heading: "", items: []})

        """
        <h2 class="heading-option">#{section.heading}</h2>
        #{Enum.map(section.items, fn item -> """
          <div class="item-container">
            <div class="sub-heading-container">
              <h3 class="sub-heading-title">#{item.sub_heading}
                #{if Map.has_key?(item, :date), do: "<span class=\"date-text\">#{item.date}</span>", else: ""}
              </h3>
            </div>
          </div>
          <ul class="highlights-list">
            #{Enum.map(item.highlights, fn highlight -> "<li class=\"highlights-list-item\"><span>#{highlight}</span></li>" end) |> Enum.join("\n")}
          </ul>
          """ end) |> Enum.join("\n")}
        """
      end)
      |> Enum.join("\n")

    left_column_content =
      render_left_column(%{
        profile_image: profile_image,
        email_svg: email_svg,
        phone_svg: phone_svg,
        linked_in_svg: linked_in_svg,
        x_svg: x_svg
      })

    # Generate HTML content for page 1
    html_content1 =
      generate_html_content(
        :page1,
        formatted_resume_html_pg1,
        css_styles,
        left_column_content
      )

    # Generate HTML content for page 2
    html_content2 =
      generate_html_content(:page2, formatted_resume_html_pg2, css_styles, left_column_content)

    {html_content1, html_content2}
  end

  def generate_pdf(html_content1, html_content2, company_name) do
    try do
      # Generate the directory structure
      base_pdf_dir = "priv/static/generated_pdfs"
      output_dir = Path.join(base_pdf_dir, company_name)
      File.mkdir_p!(output_dir)

      # Define the output path
      final_output_path = Path.join(output_dir, "Harley Gray CV.pdf")

      pdf_options = [
        size: :a4
      ]

      print_to_pdf_options = %{
        preferCSSPageSize: true,
        printBackground: true,
        marginTop: 0,
        marginLeft: 0,
        marginRight: 0,
        marginBottom: 0
      }

      ChromicPDF.print_to_pdf([{:html, html_content1}, {:html, html_content2}],
        output: final_output_path,
        pdf_options: pdf_options,
        print_to_pdf: print_to_pdf_options
      )

      IO.puts("Final PDF generated: #{final_output_path}")
      {:ok, final_output_path}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp generate_html_content(
         :page1,
         formatted_resume_html_pg1,
         css_styles,
         left_column_content
       ) do
    """
    <html>
      #{css_styles}
      <body>
        <div class="container">
          #{left_column_content}
          <div class="right-column">
            <h1 style="font-size: 32pt; margin-top: 0px; margin-bottom: 0px; padding-bottom: 0px;">Harley Gray</h1>
            <p style="font-size: 14pt; margin-top: -5px; line-height: 1.2; padding-top: 0px; margin-bottom: 14px;">Data enthusiast experienced with utilising state-of-the-art technology to drive efficiency</p>
            #{formatted_resume_html_pg1}
          </div>
        </div>
      </body>
    </html>
    """
  end

  defp generate_html_content(:page2, formatted_resume_html_pg2, css_styles, left_column_content) do
    """
    <html>
      #{css_styles}
      <body>
        <div class="container">
          #{left_column_content}
          <div class="right-column">
            <div style="height: 11px;"></div>
            #{formatted_resume_html_pg2}
          </div>
        </div>
      </body>
    </html>
    """
  end
end
