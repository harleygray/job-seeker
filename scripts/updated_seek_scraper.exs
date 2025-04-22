Mix.start()
Mix.Task.run("app.start")

defmodule UpdatedSeekScraper do
  use Wallaby.DSL
  import Wallaby.Query, only: [css: 1, css: 2, xpath: 1, xpath: 2]
  alias JobHunt.{Repo, Job}

  def run do
    IO.puts("Starting UpdatedSeekScraper...")
    Application.ensure_all_started(:wallaby)
    IO.puts("Wallaby started.")

    IO.puts("Initializing Wallaby session...")

    {:ok, session} =
      Wallaby.start_session(
        headless: false,
        capabilities: %{
          chromeOptions: %{
            args: [
              "--start-maximized",
              "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
              "--no-sandbox",
              "--disable-setuid-sandbox",
              "--disable-infobars",
              "--window-position=0,0",
              "--ignore-certifcate-errors",
              "--ignore-certifcate-errors-spki-list"
            ],
            useAutomationExtension: false,
            excludeSwitches: ["enable-automation"]
          }
        }
      )

    IO.puts("Wallaby session initialized.")

    try do
      IO.puts("Attempting to visit Seek website...")

      session
      |> visit(
        "https://www.seek.com.au/Data-Analyst-jobs/in-Queensland-QLD?daterange=3&worktype=244%2C242"
      )

      # |> visit("https://www.seek.com.au/data-jobs/in-Queensland-QLD?daterange=3")

      IO.puts("Successfully visited Seek website.")

      IO.puts("Waiting for page to load...")
      wait_for_page_load(session)
      IO.puts("Page loaded.")

      process_all_job_cards(session)

      IO.puts("Finished processing job cards.")
    rescue
      e in Wallaby.QueryError ->
        IO.puts("A query error occurred: #{inspect(e)}")
        IO.puts("Error message: #{e.message}")

      # Remove the line that tries to access e.query
      e in Wallaby.StaleReferenceError ->
        IO.puts("A stale reference error occurred: #{inspect(e)}")
        IO.puts("Error message: #{e.message}")

      e ->
        IO.puts("An unexpected error occurred: #{inspect(e)}")
        IO.puts("Error stacktrace: #{Exception.format_stacktrace()}")
    after
      IO.puts("Closing Wallaby session...")
      Wallaby.end_session(session)
      IO.puts("Wallaby session closed.")
    end
  end

  defp extract_employer_text(span_element) do
    Wallaby.Element.text(span_element)
    |> String.split("<svg", parts: 2)
    |> List.first()
    |> String.trim()
  end

  defp process_job_card(session, card) do
    try do
      IO.puts("  Clicking on job card...")
      Wallaby.Element.click(card)

      IO.puts("  Waiting for job details to load...")

      case wait_for_job_details(session) do
        {:ok, session} ->
          job_details = extract_job_details(session)
          seek_job_id = extract_seek_job_id(session)

          upsert_job(Map.put(job_details, :seek_job_id, seek_job_id))

          IO.puts("Job details saved to database.")
          {:ok, session}

        {:error, :timeout} ->
          IO.puts(
            "Job details did not load within the specified timeout. Skipping to next job card."
          )

          {:ok, session}
      end
    rescue
      e ->
        IO.puts("Error processing job card: #{inspect(e)}")
        # Changed from {:error, e} to {:ok, session} to continue processing
        {:ok, session}
    end
  end

  defp extract_seek_job_id(session) do
    current_url = Wallaby.Browser.current_url(session)
    Regex.run(~r/jobId=(\d+)/, current_url) |> List.last()
  end

  defp upsert_job(attrs) do
    case Repo.get_by(Job, seek_job_id: attrs.seek_job_id) do
      nil -> %Job{}
      job -> job
    end
    |> Job.changeset(attrs)
    |> Repo.insert_or_update()
  end

  defp wait_for_page_load(session) do
    session
    |> assert_has(css("article[data-automation='normalJob']", count: :any))
  end

  defp wait_for_job_details(session) do
    try do
      session
      |> assert_has(css("h1[data-automation='job-detail-title']"))

      {:ok, session}
    rescue
      Wallaby.QueryError ->
        IO.puts("  Job details did not load. Skipping to next card.")
        {:error, :timeout}
    end
  end

  defp extract_job_details(session) do
    IO.puts("  Extracting job details...")

    try do
      title_element = find(session, css("h1[data-automation='job-detail-title']"))
      title = Wallaby.Element.text(title_element)
      IO.puts("  Title extracted: #{title}")

      employer =
        try do
          case Wallaby.Browser.find(session, css("span[data-automation='advertiser-name']")) do
            {:ok, span_element} ->
              IO.puts("  Employer span found")
              Wallaby.Element.text(span_element)

            %Wallaby.Element{} = span_element ->
              IO.puts("  Employer span found")
              Wallaby.Element.text(span_element)
          end
        rescue
          e in Wallaby.QueryError ->
            IO.puts("  Error finding employer span: #{inspect(e)}")
            "Not specified"
        end

      IO.puts("  Employer extracted: #{employer}")

      location =
        session
        |> find(css("span[data-automation='job-detail-location']"))
        |> Wallaby.Element.text()

      IO.puts("  Location extracted: #{location}")

      salary =
        try do
          case Wallaby.Browser.find(session, css("span[data-automation='job-detail-salary']")) do
            {:ok, element} -> Wallaby.Element.text(element)
            %Wallaby.Element{} = element -> Wallaby.Element.text(element)
            _ -> "Not specified"
          end
        rescue
          e ->
            IO.puts("Error extracting salary: #{inspect(e)}")
            "Not specified"
        end

      IO.puts("  Salary extracted: #{salary}")

      apply_link =
        session
        |> find(css("a[data-automation='job-detail-apply']"))
        |> Wallaby.Element.attr("href")

      IO.puts("  Apply link extracted: #{apply_link}")

      description =
        session
        |> find(css("div[data-automation='jobAdDetails']"))
        |> Wallaby.Element.text()

      IO.puts("  Description extracted: #{description}")

      %{
        title: title,
        employer: employer,
        location: location,
        salary: salary,
        apply_link: apply_link,
        description: description
      }
    rescue
      e ->
        IO.puts("Error extracting job details: #{inspect(e)}")
        IO.puts("Current URL: #{Wallaby.Browser.current_url(session)}")
        reraise e, __STACKTRACE__
    end
  end

  defp find_job_cards(session) do
    session
    |> all(css("article[data-automation='normalJob']"))
  end

  defp find_next_button(session) do
    try do
      next_button =
        session
        |> find(css("a[rel='nofollow next'][data-automation^='page-']"))

      {:ok, next_button}
    rescue
      Wallaby.QueryError ->
        IO.puts("Next button not found. Trying alternative selector...")

        try do
          next_button =
            session
            |> find(css("a[rel='nofollow next']"))

          {:ok, next_button}
        rescue
          Wallaby.QueryError ->
            IO.puts("Next button not found with alternative selector either.")
            {:error, :not_found}
        end
    end
  end

  defp process_page(session, page_number) do
    IO.puts("Processing page #{page_number}...")
    job_cards = find_job_cards(session)
    IO.puts("Found #{length(job_cards)} job cards on page #{page_number}.")

    Enum.reduce_while(job_cards, {session, 1}, fn card, {session, index} ->
      IO.puts("Processing job card #{index} of #{length(job_cards)} on page #{page_number}...")

      case process_job_card(session, card) do
        {:ok, session} -> {:cont, {session, index + 1}}
        {:error, _reason} -> {:halt, {session, index}}
      end
    end)

    case find_next_button(session) do
      {:ok, next_button} ->
        IO.puts("Clicking 'Next' button to go to page #{page_number + 1}...")
        Wallaby.Element.click(next_button)
        # Wait for the next page to load
        :timer.sleep(2000)
        wait_for_page_load(session)
        process_page(session, page_number + 1)

      {:error, :not_found} ->
        IO.puts("No 'Next' button found. Finished processing all pages.")
        session
    end
  end

  defp process_all_job_cards(session) do
    IO.puts("Processing job cards across all pages...")
    process_page(session, 1)
  end
end

JobHunt.Repo.start_link()

IO.puts("Starting UpdatedSeekScraper.run()...")
UpdatedSeekScraper.run()
IO.puts("UpdatedSeekScraper.run() completed.")
