defmodule JobHunt.GroqClient do
  require Logger

  @api_url "https://api.groq.com/openai/v1/chat/completions"

  @spec process_job(any(), any(), any()) ::
          {:error,
           :api_error
           | :failed_generation_parse
           | :http_error
           | :unexpected_error_format
           | :unexpected_response
           | JSON.DecodeError.t()}
          | {:ok, any()}
  def process_job(title, employer, description) do
    prompt = """
    For the given job details, provide:
    - Relevancy scores (out of 100) for the following roles: data engineer, data analyst, data scientist, software engineer
    - Formatted markdown position description segments that are most relevant to the highest relevancy role

    Return the results in strictly the following JSON format:
    {
      "relevancy_scores": {
        "data_engineer": int,
        "data_analyst": int,
        "data_scientist": int,
        "software_engineer": int
      },
      "formatted_description": "string"
    }

    Ensure that the "formatted_description" is a single line string with all newlines replaced by \\n and all double quotes escaped with \\.


    Here are the job details:
    Title: #{title}
    Employer: #{employer}
    Description: #{description}
    """

    case make_api_request(prompt) do
      {:ok, response} ->
        case JSON.decode(response) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> parse_failed_generation(response)
        end

      {:error, :api_error, body} ->
        parse_failed_generation(body)

      error ->
        error
    end
  end

  defp make_api_request(prompt) do
    headers = [
      {"Authorization", "Bearer #{System.get_env("GROQ_API_KEY")}"},
      {"Content-Type", "application/json"}
    ]

    body =
      JSON.encode!(%{
        model: "llama3-70b-8192",
        response_format: %{type: "json_object"},
        messages: [%{role: "user", content: prompt}]
      })

    case HTTPoison.post(@api_url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        parsed_response = JSON.decode!(body)

        case parsed_response do
          %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
            {:ok, content}

          _ ->
            Logger.error(
              "Unexpected response structure from Groq API: #{inspect(parsed_response)}"
            )

            {:error, :unexpected_response}
        end

      {:ok, %HTTPoison.Response{status_code: 400, body: body}} ->
        Logger.error("Groq API returned status code 400: #{body}")
        {:error, :api_error, body}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Groq API returned status code #{status_code}: #{body}")
        {:error, :api_error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error calling Groq API: #{inspect(reason)}")
        {:error, :http_error}
    end
  end

  def cover_letter_generate(
        position_description,
        formatted_experience,
        template_cover_letter
      ) do
    prompt = """
    For the given Position Description and my Resume / Job Experience, provide a cover letter in markdown. Please use the template cover letter as a guide for the format and length of the cover letter, including the tone of voice. Do not include any preamble, introduction, salutation, or sign-off.

    Return the results in strictly the following JSON format:
    {
      "formatted_cover_letter": "string"
    }

    Ensure that the "formatted_cover_letter" is a single line string with all newlines replaced by \\n and all double quotes escaped with \\. Make sure the formatted_cover_letter is interpretable as markdown, and be liberal with paragraph breaks to ensure readability. Make specific reference to the responsibilities and requirements of the position description in a natural way, including relevant parts of my experience.


    Here are the job details:
    Position Description: #{position_description}
    My Resume / Job Experience: #{formatted_experience}
    Template Cover Letter: #{template_cover_letter}
    """

    case make_api_request(prompt) do
      {:ok, response} ->
        case JSON.decode(response) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> parse_failed_generation(response)
        end

      {:error, :api_error, body} ->
        parse_failed_generation(body)

      error ->
        error
    end
  end

  defp parse_failed_generation(body) do
    case JSON.decode(body) do
      {:ok, %{"error" => %{"failed_generation" => failed_generation}}} ->
        case JSON.decode(failed_generation) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:error, :failed_generation_parse}
        end

      _ ->
        {:error, :unexpected_error_format}
    end
  end
end
