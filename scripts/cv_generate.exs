defmodule PDFGenerator do
  def generate_pdf(path, content) do
    # Generate the directory structure
    base_pdf_dir = "priv/static/generated_pdfs"
    output_dir = Path.join(base_pdf_dir, path)
    File.mkdir_p!(output_dir)

    # Generate timestamp
    timestamp = DateTime.utc_now() |> Calendar.strftime("%d-%m-%H-%M-%S")

    # Define the output path
    final_output_path = Path.join(output_dir, "final_#{timestamp}.pdf")

    # For now, we'll use the content string arbitrarily
    # In a real scenario, you'd use this to customize the HTML
    custom_content = "<p>#{content}</p>"

    # Read the SVG files
    phone_svg = File.read!("#{File.cwd!()}/priv/static/images/phone.svg")
    linked_in_svg = File.read!("#{File.cwd!()}/priv/static/images/linked_in.svg")
    x_svg = File.read!("#{File.cwd!()}/priv/static/images/x.svg")
    email_svg = File.read!("#{File.cwd!()}/priv/static/images/email.svg")

    # Extract relevant resume information from the YAML file
    resume_content = YamlElixir.read_from_file!("#{File.cwd!()}/priv/static/resume.yaml")
    formatted_resume = ResumeFormatter.format_resume(resume_content)

    # Generate HTML for introduction and projects sections from resume YAML
    formatted_resume_html_pg1 =
      [:projects]
      |> Enum.map(fn section_key ->
        section = Map.get(formatted_resume, section_key)

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
            #{if Map.has_key?(item, :technologies), do: Enum.map(item.technologies, fn tech -> "<span class=\"technology-card\">#{tech}</span>" end) |> Enum.join(" "), else: ""}
          </div>
          """ end) |> Enum.join("\n")}
        """
      end)
      |> Enum.join("\n")

    # Generate HTML for experience and education sections from resume YAML
    formatted_resume_html_pg2 =
      [:experience, :education]
      |> Enum.map(fn section_key ->
        section = Map.get(formatted_resume, section_key)

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
          """ end) |> Enum.join("\n")}c
        """
      end)
      |> Enum.join("\n")

    css_styles = """
    <head>
      <style>
        @font-face {
          font-family: 'DM Sans';
          src: local('DM Sans'), local('DMSans-Regular');
        }
        body {
          font-family: 'DM Sans', Arial, sans-serif;
          font-size: 12pt;
          margin: 0;
          padding: 0;
          line-height: 1.6;
          height: 100%;
          opacity: 1;
        }
        .highlights-list {
          list-style-type: none;
          padding-left: 0;
          margin-left: -5px;
          margin-top: 6px;
          margin-bottom: 5px;
        }
        .highlights-list-item {
          margin-top: 7px;
          display: block;
        }
        .highlights-list-item span {
          background-color: #e7ebed;
          display: inline;
          padding: 4px 5px;
          border-radius: 3px;
          box-decoration-break: clone;
          -webkit-box-decoration-break: clone;
          line-height: 1.6;
        }
        .profile-image {
          width: 155px;
          height: 155px;
          border-radius: 40%;
          margin: 10px auto;
          display: block;
          position: relative;
          left: -12.5px;
          padding-top: 20px;
        }
        .heading-option {
          background-color: #0d334b;
          color: white;
          font-weight: bold;
          font-size: 20pt;
          display: inline-block;
          border-radius: 7px;
          padding: 0 4px;
          margin-top: 3px;
          margin-bottom: 0px;
          margin-left: -5px;
        }
        .sub-heading-title {
          font-size: 18pt;
          color: black;
          margin-top: 0px;
          margin-bottom: -10px;
        }
        .date-text {
          font-size: 11pt;
          color: black;
          margin-top: 0px;
          margin-bottom: -12px;
          font-style: italic;
          font-weight: normal;
        }
        .container {
          display: flex;
          min-height: 100vh;
          max-width: 100%;
        }
        .left-column {
          width: 25%;
          position: relative;
        }
        .left-column-content {
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          padding-left: 25px;
          color: rgb(255,255,255);
          fill: rgb(255,255,255);
        }

        .right-column {
          width: 75%;
          padding-top: 15px;
          padding-left: 25px;
          box-sizing: border-box;
          color: black;
          padding-right: 25px;
        }

        ul {
          padding-left: 20px;
        }
        .svg-background {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          z-index: 0;
        }

        .item-container {
          display: flex;
          flex-wrap: wrap;
          align-items: center;
          margin-bottom: 7px;
        }

        .sub-heading-container {
          flex: 1;
        }

        .technologies-container {
          display: flex;
          flex-wrap: wrap;
          gap: 5px;
          margin-bottom: 16px;
          margin-top: 4px;
          margin-left: -5px;
        }

        .technology-card {
          background-color: #f3f3f3;
          padding: 2px 5px;
          border-radius: 3px;
          font-size: 9pt;
          white-space: nowrap;

        }
        </style>
      </head>
    """

    left_column_content = """
      <div class="left-column">
        <svg class="svg-background" width="100%" height="100%">
          <rect width="100%" height="100%" fill="#0d334b" />
        </svg>
        <div class="left-column-content">
          <img src="file:///#{File.cwd!()}/priv/static/images/profile.jpg" class="profile-image">

          <h2 style="text-decoration: underline; margin-bottom: 0px;">Contact</h2>
          <div style="display: flex; align-items: center; margin-top: 0px;">
            <div style="flex: 1; margin-top: 0px;">
              #{email_svg}
            </div>
            <div style="flex: 3; margin-top: 0px;">
              <p>harley.gray.96<br>@gmail.com</p>
            </div>
          </div>

          <div style="display: flex; align-items: center;">
            <div style="flex: 1;">
            #{phone_svg}
            </div>
            <div style="flex: 3;">
              <p>0488 005 801</p>
            </div>
          </div>


          <h2 style="text-decoration: underline; margin-bottom: 10px;">Online</h2>

          <div style="display: flex; align-items: center;  margin-top: 0px">
            <div style="flex: 1;">
              #{linked_in_svg}
            </div>
            <div style="flex: 3;">
              <p>harleygray1996</p>
            </div>
          </div>

            <div style="display: flex; align-items: center;">
            <div style="flex: 1;">
              #{x_svg}
            </div>
            <div style="flex: 3;">
              <p>harleyraygray</p>
            </div>
          </div>

          <h2 style="text-decoration: underline; margin-bottom: 0px;">References</h2>
           <p>Contact details of <br> two references available on request</p>
        </div>
      </div>
    """

    # Generate HTML content for page 1
    html_content1 =
      generate_html_content(:page1, formatted_resume_html_pg1, css_styles, left_column_content)

    # Generate HTML content for page 2
    html_content2 =
      generate_html_content(:page2, formatted_resume_html_pg2, css_styles, left_column_content)

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
  end

  defp generate_html_content(:page1, formatted_resume_html_pg1, css_styles, left_column_content) do
    """
    <html>
      #{css_styles}
      <body>
        <div class="container">
          #{left_column_content}
          <div class="right-column">
            <h1 style="font-size: 32pt; margin-top: 0px; margin-bottom: 0px; padding-bottom: 0px;">Harley Gray</h1>
            <p style="font-size: 14pt; margin-top: -5px; line-height: 1.2; padding-top: 0px; margin-bottom: 14px;">Data enthusiast experienced with utilising state-of-the-art technology to drive efficiency</p>
            #{custom_content}

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

Logger.configure(level: :debug)

# Run the generator
PDFGenerator.generate_pdf()

# Stop the ChromicPDF Supervisor
Supervisor.stop(ChromicPDF)
