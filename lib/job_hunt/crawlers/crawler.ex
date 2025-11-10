defmodule CivicForum.Crawlers.Crawler do
  @moduledoc """
  Controls the Node.js-based Crawlee crawler through a port.
  """

  require Logger

  # Use our simple test crawler for debugging
  # @crawler_script "lib/civic_forum/crawlers/simple_test_crawler.js"
  # Original crawler script
  @crawler_script "lib/civic_forum/crawlers/crawler.js"

  # Store crawler process information
  @crawler_info :crawler_info

  def start_crawler(urls, opts \\ [], callback_fn \\ nil) do
    # Logger.info("Starting crawler with URLs: #{inspect(urls)}")

    # Check if crawler is already running
    case is_crawler_running() do
      true ->
        Logger.warning("Crawler is already running, ignoring duplicate start request", [])
        {:error, :already_running}

      false ->
        # Start the crawler
        start_new_crawler(urls, opts, callback_fn)
    end
  end

  # Check if a crawler is already running
  defp is_crawler_running do
    case :ets.info(@crawler_info) do
      :undefined ->
        # Create the ETS table if it doesn't exist
        :ets.new(@crawler_info, [:set, :public, :named_table])
        false

      _ ->
        # Check if there's a running crawler
        case :ets.lookup(@crawler_info, :running) do
          [{:running, port, _pid}] ->
            # Check if port is still alive
            case Port.info(port) do
              nil ->
                # Clean up stale entry
                :ets.delete(@crawler_info, :running)
                false
              _ ->
                # Crawler is still running
                true
            end
          [] ->
            false
        end
    end
  end

  # Mark crawler as running
  defp mark_crawler_running(port) do
    :ets.insert(@crawler_info, {:running, port, self()})
  end

  # Mark crawler as not running
  defp mark_crawler_stopped do
    :ets.delete(@crawler_info, :running)
  end

  defp start_new_crawler(urls, opts, callback_fn) do
    # Ensure Node.js dependencies are installed
    case install_dependencies() do
      :ok ->
        # Force headless mode in production environment
        opts = if Application.get_env(:civic_forum, :environment) == :prod do
          Logger.info("Running in production environment, forcing headless mode")
          Keyword.put(opts, :headless, true)
        else
          opts
        end

        start_node_process(urls, opts, callback_fn)
      {:error, reason} ->
        Logger.error("Failed to install dependencies: #{inspect(reason)}")
        {:error, "dependency_installation_failed: #{inspect(reason)}"}
    end
  end

  defp start_node_process(urls, opts, callback_fn) do
    # Logger.info("Starting Node.js process")

    # Get the full path to Node.js
    case System.find_executable("node") do
      nil ->
        Logger.error("Node.js not found in PATH")
        {:error, "node_not_found"}
      node_path ->
        # Logger.info("Found Node.js at: #{node_path}")

        # Start Node.js process with explicit path
        script_path = Path.join(File.cwd!(), @crawler_script)

        case File.exists?(script_path) do
          true ->
            # Logger.info("Found crawler script at: #{script_path}")

            # Create port with stdin/stdout communication and stderr redirection
            port = Port.open(
              {:spawn_executable, node_path},
              [:binary, :use_stdio, :stderr_to_stdout, :exit_status, args: [script_path]]
            )

            case Port.info(port) do
              nil -> Logger.error("Port info not available - port may already be closed")
              info -> Logger.debug("Port info: #{inspect(info)}")
            end

            # Mark crawler as running
            mark_crawler_running(port)

            # Build configuration for Node.js with pagination options
            config = %{
              urls: urls,
              headless: Keyword.get(opts, :headless, true),
              maxRequestsPerCrawl: Keyword.get(opts, :maxRequestsPerCrawl, 100),
              maxConcurrency: Keyword.get(opts, :maxConcurrency, 10),
              navigationTimeoutSecs: Keyword.get(opts, :navigationTimeoutSecs, 60),
              minDelayBetweenRequests: Keyword.get(opts, :minDelayBetweenRequests, 2000),
              maxDelayBetweenRequests: Keyword.get(opts, :maxDelayBetweenRequests, 5000),
              # Add pagination configuration options
              enablePagination: Keyword.get(opts, :enable_pagination, true),
              maxPages: Keyword.get(opts, :max_pages, 100)
            }

            # Log pagination settings if enabled
            if Keyword.get(opts, :enable_pagination, false) do
              Logger.info("Pagination enabled: Will crawl up to #{Keyword.get(opts, :max_pages, 5)} pages")
            end

            # Logger.info("Sending configuration to Node.js: #{inspect(config)}")
            config_json = Jason.encode!(config)
            Logger.debug("Configuration JSON: #{config_json}")

            # Send configuration to Node.js via stdin with extra tracing
            # Logger.info("Sending #{byte_size(config_json) + 1} bytes to Node.js")
            Logger.debug("Sending with trailing newline: #{inspect(config_json <> "\n")}")
            _result = Port.command(port, config_json <> "\n")
            # Logger.info("Port.command result: #{inspect(result)}")

            # Process messages from Node.js and collect data or pass to callback
            if callback_fn do
              # Start collecting data and pass to callback as it comes in
              process_port_with_callback(port, callback_fn)
            else
              # Collect all data and return at the end (original behavior)
              process_port_output(port, [])
            end

          false ->
            Logger.error("Crawler script not found at: #{script_path}")
            {:error, "script_not_found"}
        end
    end
  end

  # Process output from Node.js with callback for each page of results
  defp process_port_with_callback(port, callback_fn) do
    # Initialize the process dictionary with a unique key for this port
    port_key = {:chunked_data, port}
    Process.put(port_key, %{chunks: []})

    # Monitor the port in a separate process
    monitoring_pid = spawn_link(fn ->
      monitor_port_with_callback(port, callback_fn, %{chunks: [], start_time: System.monotonic_time(:millisecond)})
    end)

    # Start a watchdog process to ensure we don't hang indefinitely
    spawn(fn ->
      Process.monitor(monitoring_pid)
      # Set a watchdog timeout of 5 minutes
      receive do
        {:DOWN, _, :process, ^monitoring_pid, reason} when reason != :normal ->
          Logger.error("Port monitoring process crashed: #{inspect(reason)}")
          cleanup_port(port)
          mark_crawler_stopped()
        after
          1_800_000 ->  # 30 minute timeout
            Logger.error("Watchdog timeout: Port monitoring process has been running for too long")
            Process.exit(monitoring_pid, :kill)
            cleanup_port(port)
            mark_crawler_stopped()
      end
    end)

    {:ok, port}
  end

  defp monitor_port_with_callback(port, callback_fn, acc) do
    Logger.debug("Waiting for port data in monitor_port_with_callback, port: #{inspect(port)}")
    receive do
      {^port, {:data, data}} ->
        Logger.debug("Received RAW port data of size: #{byte_size(data)} bytes")

        # Filter PlaywrightCrawler completion and statistics messages to debug level
        if is_binary(data) &&
           (String.contains?(data, "PlaywrightCrawler: All requests from the queue have been processed") ||
            String.contains?(data, "PlaywrightCrawler: Final request statistics:") ||
            String.contains?(data, "PlaywrightCrawler: Finished! Total")) do
          # Log at debug level instead of info
          Logger.debug("Crawler stats: #{String.trim(data)}")
        end

        # Check for page_complete confirmations
        page_complete_confirmation = String.match?(data, ~r/CRITICAL_MESSAGE_SENT: page_complete/)

        # Check for ELIXIR_JSON_MESSAGE markers and process them through CrawlerServer
        message_processed = if String.contains?(data, "ELIXIR_JSON_MESSAGE") do
          Logger.info("Found ELIXIR_JSON_MESSAGE marker in port data")

          # Forward to the CrawlerServer to process the structured message
          case CivicForum.Crawlers.CrawlerServer.process_message(data) do
            {:ok, :page_complete} ->
              # Logger.info("Successfully processed page_complete message")
              true
            {:ok, _} ->
              # Other messages were processed
              true
            _ ->
              # No valid messages processed
              false
          end
        else
          false
        end

        # Handle page_complete confirmations even if no full JSON message was processed
        if page_complete_confirmation && !message_processed do
          # Logger.info("Detected page_complete confirmation message")

          # Create a minimal completion data structure with the essentials
          complete_data = %{
            "status" => "success",
            "completed" => true,
            "confirmed_at" => System.system_time(:millisecond),
            "source" => "confirmation_message"
          }

          # Call the callback directly with the completion data
          # Logger.info("Calling callback with synthesized page_complete data from confirmation")
          callback_fn.({:page_complete, complete_data})

          # This was a completion message, so we can clean up
          Logger.info("Crawler completion detected via confirmation, cleaning up")
          cleanup_port(port)
          mark_crawler_stopped()

          # Exit this monitoring process
          exit(:normal)
        end

        # Check if this is a page_complete message
        complete_via_marker = String.contains?(data, "\"type\":\"page_complete\"") ||
                             String.contains?(data, "CRITICAL_MESSAGE_SENT: page_complete")

        if complete_via_marker && !message_processed do
          Logger.info("Found unprocessed page_complete marker in raw data")

          # Extract the JSON if needed and send to CrawlerServer
          if String.contains?(data, "ELIXIR_JSON_MESSAGE") do
            # This may have failed in the earlier step, retry with more aggressive extraction
            [_, _json_part] = String.split(data, "ELIXIR_JSON_MESSAGE:", parts: 2)

            complete_data = %{"status" => "success", "completed" => true}
            callback_fn.({:page_complete, complete_data})
          else
            # If no marker but we see the completion message, try regex extraction
            case extract_json_from_string(data) do
              {:ok, %{"type" => "page_complete", "data" => complete_data}} ->
                callback_fn.({:page_complete, complete_data})
              _ ->
                # No JSON found, but we know it's a completion message
                complete_data = %{"status" => "success", "completed" => true}
                callback_fn.({:page_complete, complete_data})
            end
          end

          # This was a completion message, so we can clean up
          Logger.info("Crawler completion detected via markers, calling callback and cleaning up")
          cleanup_port(port)
          mark_crawler_stopped()

          # Exit this monitoring process
          exit(:normal)
        end

        # Check if we have a status update from normal logs
        {updated_acc, complete} = check_for_status_update(acc, data)

        if complete do
          Logger.info("Crawler run completed, calling callback")
          # Some result data and run-level status
          result = %{
            status: updated_acc.status,
            pages_processed: updated_acc.pages_processed,
            pages_failed: updated_acc.pages_failed
          }
          callback_fn.(result)
          cleanup_port(port)
          # Mark crawler as stopped
          mark_crawler_stopped()
        else
          # Continue monitoring
          monitor_port_with_callback(port, callback_fn, updated_acc)
        end

      {^port, {:exit_status, status}} ->
        Logger.info("Node.js process exited with status: #{status}")

        result = case status do
          0 ->
            %{status: "success", exit_code: status}
          _ ->
            %{status: "error", exit_code: status, error: "Node.js process exited with non-zero status code"}
        end

        callback_fn.(result)
        # Mark crawler as stopped
        mark_crawler_stopped()
    after
      1_800_000 ->  # 30 minute timeout
        Logger.error("Timeout waiting for Node.js to respond")
        Logger.error("Last state: #{inspect(acc)}")
        callback_fn.({:error, "timeout_waiting_for_node_response"})
        cleanup_port(port)
        # Mark crawler as stopped
        mark_crawler_stopped()
    end
  end

  # Helper function to extract JSON from a string with other content
  defp extract_json_from_string(string) do
    # First check for our explicit marker
    if String.contains?(string, "ELIXIR_JSON_MESSAGE:") do
      # Split by the marker and take the part after it
      [_ | parts] = String.split(string, "ELIXIR_JSON_MESSAGE:", parts: 2)

      if parts && length(parts) > 0 do
        json_part = List.first(parts) |> String.trim()

        # Try to parse what's after the marker until the first non-JSON character
        case Jason.decode(json_part) do
          {:ok, decoded} ->
            Logger.info("Successfully extracted JSON after ELIXIR_JSON_MESSAGE marker")
            {:ok, decoded}
          {:error, %Jason.DecodeError{} = err} ->
            # Try to extract just the JSON object or array
            case Regex.scan(~r/(\{.*?\}|\[.*?\])/s, json_part) do
              [] ->
                Logger.error("No JSON object found after marker: #{inspect(err)}")
                {:error, "No JSON object found after marker"}
              matches ->
                # Try each match
                Enum.find_value(matches, {:error, "No valid JSON found in matches"}, fn [match | _] ->
                  case Jason.decode(match) do
                    {:ok, decoded} -> {:ok, decoded}
                    _ -> nil
                  end
                end)
            end
        end
      else
        {:error, "Found marker but no content after it"}
      end
    else
      # Fall back to the regex approach for legacy support
      case Regex.scan(~r/(\{.*?\}|\[.*?\])/s, string) do
        [] -> {:error, "No JSON-like patterns found"}
        matches ->
          # Try each potential JSON object
          Enum.find_value(matches, {:error, "No valid JSON found"}, fn [potential_json | _] ->
            case Jason.decode(potential_json) do
              {:ok, decoded} -> {:ok, decoded}
              _ -> nil
            end
          end)
      end
    end
  end

  # Original process output from Node.js in a loop (for backwards compatibility)
  defp process_port_output(port, collected_data) do
    receive do
      {^port, {:data, data}} ->
        # First check if this looks like a log message (not JSON)
        cond do
          # Filter PlaywrightCrawler statistics messages to debug level
          is_binary(data) &&
          (String.contains?(data, "PlaywrightCrawler: All requests from the queue have been processed") ||
           String.contains?(data, "PlaywrightCrawler: Final request statistics:") ||
           String.contains?(data, "PlaywrightCrawler: Finished! Total")) ->
            Logger.debug("Crawler stats: #{String.trim(data)}")
            process_port_output(port, collected_data)

          # Handle other log messages
          String.starts_with?(data, "\e[") || String.contains?(data, "INFO") || String.contains?(data, "DEBUG") || String.contains?(data, "ERROR") ->
            # This is likely a log message, just log it at debug level
            Logger.debug("Crawler log: #{inspect(String.trim(data))}")
            process_port_output(port, collected_data)

          # Continue with the rest of the function
          true ->
            # Try to decode as JSON
            case Jason.decode(data) do
              {:ok, %{"type" => "page_results", "data" => page_data}} ->
                # Continue collecting data
                process_port_output(port, [page_data | collected_data])

              {:ok, %{"type" => "complete"}} ->
                Logger.info("Crawler completed successfully")
                # Mark crawler as stopped
                mark_crawler_stopped()
                {:ok, port, Enum.reverse(collected_data)}

              {:ok, %{"type" => "error", "data" => error}} ->
                Logger.error("Crawler failed: #{inspect(error)}")
                # Mark crawler as stopped
                mark_crawler_stopped()
                {:error, error}

              {:error, _decode_error} ->
                # This is likely stderr output, just log it at debug level
                Logger.debug("Crawler output: #{inspect(data)}")
                process_port_output(port, collected_data)

                # Handle any other format that might come from the Node.js process
                {:ok, other} ->
                  Logger.debug("Unhandled message format: #{inspect(other)}")
                  process_port_output(port, collected_data)
            end
        end

      {^port, {:exit_status, 0}} ->
        Logger.info("Node.js process exited successfully")
        # Mark crawler as stopped
        mark_crawler_stopped()
        {:ok, port, Enum.reverse(collected_data)}

      {^port, {:exit_status, status}} ->
        Logger.error("Node.js process exited with status: #{status}")
        # Mark crawler as stopped
        mark_crawler_stopped()
        {:error, "node_exit_with_status_#{status}"}

    after
        120_000 ->  # 120 second timeout (2 minutes)
        Logger.error("Timeout waiting for Node.js to complete")
        # Check if port is alive before trying to close it
          cleanup_port(port)
          # Mark crawler as stopped
          mark_crawler_stopped()
        {:error, "timeout_waiting_for_completion"}
    end
  end

  # Check data for status updates like completion or progress
  defp check_for_status_update(acc, data) do
    # Initialize or use existing acc
    acc = if is_map(acc), do: acc, else: %{
      status: "running",
      pages_processed: 0,
      pages_failed: 0,
      complete: false
    }

    # Skip processing PlaywrightCrawler statistics messages
    if is_binary(data) &&
       (String.contains?(data, "PlaywrightCrawler: All requests from the queue have been processed") ||
        String.contains?(data, "PlaywrightCrawler: Final request statistics:") ||
        String.contains?(data, "PlaywrightCrawler: Finished! Total")) do
      # Return unchanged state for these messages
      {acc, false}
    else
      # Look for status indicators in the output
      cond do
        # Check for successful page processing
        String.contains?(data, "Successfully processed page") ->
          Logger.info("Detected successful page processing")
          updated_acc = Map.update(acc, :pages_processed, 1, &(&1 + 1))
          {updated_acc, false} # Not complete yet

        # Check for page processing failure
        String.contains?(data, "Error processing") ->
          Logger.info("Detected page processing error")
          updated_acc = Map.update(acc, :pages_failed, 1, &(&1 + 1))
          {updated_acc, false} # Not complete yet

        # Check for crawler completion message
        String.contains?(data, "Crawler run completed") ->
          Logger.info("Detected crawler completion message")
          updated_acc = acc
            |> Map.put(:status, "success")
            |> Map.put(:complete, true)
          {updated_acc, true} # Complete

        # Check for fatal errors
        String.contains?(data, "FATAL ERROR") ->
          Logger.error("Detected fatal error in crawler output")
          updated_acc = acc
            |> Map.put(:status, "error")
            |> Map.put(:complete, true)
          {updated_acc, true} # Complete with error

        # Default - no status update
        true ->
          {acc, false} # Not complete, no change
      end
    end
  end

  # Clean up port resources
  defp cleanup_port(port) do
    Logger.debug("Cleaning up port resources")
    try do
      Port.close(port)
    rescue
      e ->
        Logger.warning("Error closing port: #{Exception.message(e)}")
    end
  end

  defp install_dependencies do
    # Logger.info("Checking Node.js dependencies")

    # Check if package.json exists in the crawler directory
    crawler_dir = Path.dirname(@crawler_script)
    package_json = Path.join(crawler_dir, "package.json")

    # Flag to track if we need to install Playwright browsers
    need_to_install_browsers = false

    unless File.exists?(package_json) do
      Logger.info("Creating package.json")
      # Create package.json if it doesn't exist
      File.write!(package_json, Jason.encode!(%{
        "name" => "civic-forum-crawler",
        "version" => "1.0.0",
        "dependencies" => %{
          "crawlee" => "^3.13.0",
          "playwright" => "^1.51.0"
        }
      }, pretty: true))

      # Install dependencies
      # Logger.info("Installing Node.js dependencies")
      case System.cmd("npm", ["install"], cd: crawler_dir) do
        {_output, 0} ->
          Logger.info("Dependencies installed successfully")
          _need_to_install_browsers = true
        {output, _code} ->
          Logger.error("Failed to install dependencies: #{inspect(output)}")
          {:error, "npm_install_failed: #{inspect(output)}"}
      end
    else
      # Logger.info("package.json already exists")
      # Check if node_modules exists, if not, run npm install
      node_modules_path = Path.join(crawler_dir, "node_modules")
      unless File.exists?(node_modules_path) do
        Logger.info("node_modules not found, installing dependencies")
        case System.cmd("npm", ["install"], cd: crawler_dir) do
          {_output, 0} ->
            Logger.info("Dependencies installed successfully")
            _need_to_install_browsers = true
          {output, _code} ->
            Logger.error("Failed to install dependencies: #{inspect(output)}")
            {:error, "npm_install_failed: #{inspect(output)}"}
        end
      end
    end

    # Check if browsers exist and install them if needed
    browser_check_path = Path.join([System.get_env("HOME"), ".cache", "ms-playwright"])
    if !File.exists?(browser_check_path) || need_to_install_browsers do
      Logger.info("Installing Playwright browsers")
      case System.cmd("npx", ["playwright", "install", "--with-deps"], cd: crawler_dir) do
        {_output, 0} ->
          Logger.info("Playwright browsers installed successfully")
          :ok
        {output, _code} ->
          Logger.error("Failed to install Playwright browsers: #{inspect(output)}")
          {:error, "playwright_browsers_installation_failed: #{inspect(output)}"}
      end
    else
      # Logger.info("Playwright browsers already installed")
      :ok
    end
  end

end
