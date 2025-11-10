defmodule JobHunt.SelectionCriteriaGenerator do
  @moduledoc """
  Generates Selection Criteria Response documents in HTML and PDF format.
  """
  require EEx

  left_column_template_path =
    Path.join(
      :code.priv_dir(:job_hunt),
      "static/left_column.html.heex"
    )

  EEx.function_from_file(:def, :render_left_column, left_column_template_path, [:assigns])

  def generate_html(job_description, employer) do
    css_styles_path = Path.join(:code.priv_dir(:job_hunt), "static/cv_styles.html")
    css_styles = File.read!(css_styles_path)

    # Read the SVG files (using same names as cover letter generator)
    phone_svg = File.read!("#{File.cwd!()}/priv/static/images/phone.svg")
    linked_in_svg = File.read!("#{File.cwd!()}/priv/static/images/linked_in.svg")
    github_svg = File.read!("#{File.cwd!()}/priv/static/images/github-logo.svg")
    cf_svg = File.read!("#{File.cwd!()}/priv/static/images/civic_forum.svg")
    email_svg = File.read!("#{File.cwd!()}/priv/static/images/email.svg")
    image_path = Path.join(:code.priv_dir(:job_hunt), "static/images/profile.jpg")
    image_data = File.read!(image_path) |> Base.encode64()
    profile_image = "<img src=\"data:image/jpeg;base64,#{image_data}\" class=\"profile-image\">"

    left_column_content = render_left_column(%{
      profile_image: profile_image,
      email_svg: email_svg,
      phone_svg: phone_svg,
      linked_in_svg: linked_in_svg,
      github_svg: github_svg,
      cf_svg: cf_svg
    })

    # Generate selection criteria content
    selection_criteria_content = generate_selection_criteria_content(job_description, employer)

    # Generate HTML content for page 1
    html_content1 = generate_html_content(
      :page1,
      selection_criteria_content[:page1],
      css_styles,
      left_column_content
    )

    # Generate HTML content for page 2
    html_content2 = generate_html_content(
      :page2,
      selection_criteria_content[:page2],
      css_styles,
      left_column_content
    )

    {html_content1, html_content2}
  end

  defp generate_selection_criteria_content(_job_description, _employer) do
    # This is a placeholder - you would customize this based on the job requirements
    page1_content = """
    <h2 class="heading-option">Selection Criteria Responses</h2>

    <div class="item-container" style="padding-top: 4px;">
      <div class="sub-heading-container">
        <h3 class="sub-heading-title">Criterion 1: Technical Expertise</h3>
      </div>
    </div>
    <p class="criteria-response">
      I possess extensive technical expertise in data analysis, software engineering, and AI/ML technologies.
      My experience includes working with Python, R, SQL, and various machine learning frameworks to deliver
      data-driven solutions that drive business value.
    </p>

    <div class="item-container">
      <div class="sub-heading-container">
        <h3 class="sub-heading-title">Criterion 2: Problem-Solving Abilities</h3>
      </div>
    </div>
    <p class="criteria-response">
      Throughout my career, I have demonstrated strong analytical and problem-solving skills by identifying
      complex business challenges and developing innovative solutions. My approach involves systematic analysis,
      stakeholder collaboration, and iterative improvement to ensure optimal outcomes.
    </p>

    <div class="item-container">
      <div class="sub-heading-container">
        <h3 class="sub-heading-title">Criterion 3: Communication and Collaboration</h3>
      </div>
    </div>
    <p class="criteria-response">
      I excel at translating technical concepts into business language and working effectively with
      cross-functional teams. My experience includes presenting findings to senior leadership,
      mentoring junior team members, and facilitating workshops to drive organizational change.
    </p>
    """

    page2_content = """
    <div class="item-container">
      <div class="sub-heading-container">
        <h3 class="sub-heading-title">Criterion 4: Project Management</h3>
      </div>
    </div>
    <p class="criteria-response">
      I have successfully managed multiple data science and engineering projects from conception to delivery.
      My project management approach emphasizes clear communication, risk mitigation, and stakeholder alignment
      to ensure projects are delivered on time and within scope.
    </p>

    <div class="item-container">
      <div class="sub-heading-container">
        <h3 class="sub-heading-title">Criterion 5: Continuous Learning</h3>
      </div>
    </div>
    <p class="criteria-response">
      I am committed to continuous professional development and staying current with industry trends.
      I regularly participate in professional development opportunities, contribute to open-source projects,
      and engage with the broader data science and technology community.
    </p>

    <div class="item-container">
      <div class="sub-heading-container">
        <h3 class="sub-heading-title">Conclusion</h3>
      </div>
    </div>
    <p class="criteria-response">
      I am confident that my combination of technical expertise, problem-solving abilities, and collaborative
      approach makes me an ideal candidate for this position. I look forward to the opportunity to contribute
      to your organization's success and discuss how my skills align with your specific requirements.
    </p>
    """

    %{
      page1: page1_content,
      page2: page2_content
    }
  end

  defp generate_html_content(:page1, content, css_styles, left_column_content) do
    """
    <html>
      #{css_styles}
      <body>
        <div class="container">
          #{left_column_content}
          <div class="right-column">
          <div style="height: 11px;"></div>
            #{content}
          </div>
        </div>
      </body>
    </html>
    """
  end

  defp generate_html_content(:page2, content, css_styles, left_column_content) do
    """
    <html>
      #{css_styles}
      <body>
        <div class="container">
          #{left_column_content}
          <div class="right-column">
            <div style="height: 11px;"></div>
            #{content}
          </div>
        </div>
      </body>
    </html>
    """
  end
end
