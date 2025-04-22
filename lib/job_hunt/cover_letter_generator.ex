defmodule JobHunt.CoverLetterGenerator do
  require EEx
  alias JobHunt.GroqClient

  left_column_template_path =
    Path.join(
      :code.priv_dir(:job_hunt),
      "static/templates/left_column.html.heex"
    )

  EEx.function_from_file(:def, :render_left_column, left_column_template_path, [:assigns])

  def generate_html(position_description, addressee, company_name) do
    # For now, we'll use the content string arbitrarily
    # In a real scenario, you'd use this to customize the HTML

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

    # Extract relevant resume information from the YAML file
    resume_content = YamlElixir.read_from_file!("#{File.cwd!()}/priv/static/resume.yaml")
    formatted_cv = CoverLetterFormatter.format_resume(resume_content)

    # Generate HTML for experience section from resume YAML
    formatted_experience_text =
      [:experience]
      |> Enum.map(fn section_key ->
        section = Map.get(formatted_cv, section_key)

        """
        #{section.heading}

        #{Enum.map(section.items, fn item -> """
          #{item.sub_heading}

          Relevant Experience: #{item.relevant_experience}

          #{if Map.has_key?(item, :technologies), do: "Technologies: #{item.technologies}", else: ""}
          """ end) |> Enum.join("\n\n")}
        """
      end)
      |> Enum.join("\n\n")

    # Generate salutation
    salutation =
      if addressee == "Not specified" do
        "To the hiring manager at #{company_name},"
      else
        "Dear #{addressee},"
      end

    template_cover_letter = File.read!("priv/static/templates/cover_letter_template.txt")

    formatted_cover_letter_html =
      case GroqClient.cover_letter_generate(
             position_description,
             formatted_experience_text,
             template_cover_letter
           ) do
        {:ok, %{"formatted_cover_letter" => formatted_cover_letter}} ->
          Phoenix.HTML.raw(Earmark.as_html!(formatted_cover_letter))

        {:error, reason} ->
          IO.puts("Failed to generate cover letter: #{inspect(reason)}")
          "<p>Failed to generate cover letter. Please try again.</p>"
      end

    left_column_content =
      render_left_column(%{
        profile_image: profile_image,
        email_svg: email_svg,
        phone_svg: phone_svg,
        linked_in_svg: linked_in_svg,
        x_svg: x_svg
      })

    # Generate HTML content for page 1
    html_content =
      generate_html_content(
        salutation,
        formatted_cover_letter_html,
        css_styles,
        left_column_content
      )

    {html_content}
  end

  def generate_pdf(html_content, company_name) do
    try do
      # Generate the directory structure
      base_pdf_dir = "priv/static/generated_pdfs"
      output_dir = Path.join(base_pdf_dir, company_name)
      File.mkdir_p!(output_dir)

      # Generate timestamp (testing)
      # timestamp = DateTime.utc_now() |> Calendar.strftime("%d-%m-%H-%M-%S")

      # Define the output path
      final_output_path = Path.join(output_dir, "Harley Gray Cover Letter.pdf")

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

      ChromicPDF.print_to_pdf({:html, html_content},
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
         salutation,
         formatted_cover_letter,
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
            <h4 style="font-size: 16pt; margin-top: 10px; margin-bottom: 0px; padding-bottom: 0px;">#{salutation}</h1>

            #{Phoenix.HTML.safe_to_string(formatted_cover_letter)}

            <p>Kind regards,<br>Harley Gray</p>
          </div>
        </div>
      </body>
    </html>
    """
  end
end
