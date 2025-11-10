defmodule CivicForum.Crawlers.CrawlerServer do
  @moduledoc """
  GenServer that manages the crawler state and handles crawled data.
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_crawling(urls, opts \\ [], process_fn \\ nil) do
    # Increase timeout to 360 seconds (6 minutes) to account for Node.js startup + processing
    GenServer.call(__MODULE__, {:start_crawling, urls, opts, process_fn}, 360_000)
  end

  # Convenience function to start crawling with pagination
  def start_crawling_with_pagination(urls, max_pages \\ 5, opts \\ [], process_fn \\ nil) do
    # Add pagination options to the opts
    pagination_opts = Keyword.merge(opts, [
      enable_pagination: true,
      max_pages: max_pages
    ])

    # Call the regular start_crawling with pagination options
    start_crawling(urls, pagination_opts, process_fn)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Set up exit trap to handle cleanup
    Process.flag(:trap_exit, true)

    Logger.info("Starting CrawlerServer")
    {:ok, %{
      status: :idle,
      current_urls: [],
      crawled_data: [],
      errors: [],
      port: nil,
      processor_pid: nil,
      job_meta: nil
    }}
  end

  @impl true
  def handle_call({:start_crawling, urls, opts, process_fn}, from, state) do
    # Logger.info("Starting crawler with URLs: #{inspect(urls)}")

    # Clean up any existing port
    cleanup_port(state.port)

    # Set status to running first to avoid race conditions
    state = %{state |
      status: :running,
      current_urls: urls,
      crawled_data: [],
      errors: [],
      processor_pid: nil
    }

    # Create the callback function that will handle data as it's received
    crawler_callback = fn message ->
      send(self(), {:crawler_message, message})
    end

    # Start a timer to handle potential timeouts gracefully
    # This will send a message to handle timeout before GenServer.call times out
    timer_ref = Process.send_after(self(), {:crawling_timeout, from}, 1_799_990) # 350 seconds (slightly less than the 360s call timeout)

    # Start the crawler with callback function
    case CivicForum.Crawlers.Crawler.start_crawler(urls, opts, crawler_callback) do
      {:ok, port} ->
        Logger.debug("Crawler started successfully with port #{inspect(port)}")

        # Store the caller pid for replying later when process completes
        updated_state = %{state |
          port: port,
          job_meta: %{
            caller: from,
            process_fn: process_fn,
            timer_ref: timer_ref
          }
        }

        # Don't reply now, we'll do it when all data is processed
        {:noreply, updated_state}

      {:error, :already_running} ->
        # Cancel the timeout timer since we're replying now
        Process.cancel_timer(timer_ref)

        Logger.warning("Crawler is already running, ignoring duplicate request", [])
        {:reply, {:error, :already_running}, state}

      {:error, error} ->
        # Cancel the timeout timer since we're replying now
        Process.cancel_timer(timer_ref)

        Logger.error("Crawler failed to start: #{inspect(error)}")
        {:reply, {:error, error}, %{state | status: :error, errors: [error | state.errors]}}
    end
  rescue
    error ->
      Logger.error("Exception in start_crawling: #{Exception.message(error)}")
      Logger.error(Exception.format_stacktrace(__STACKTRACE__))
      {:reply, {:error, "exception: #{Exception.message(error)}"}, %{state | status: :error, errors: ["Exception: #{Exception.message(error)}" | state.errors]}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:crawler_message, {:log, log_data}}, state) do
    # Handle structured log messages from the crawler
    level = log_data["level"] || "debug"
    message = log_data["message"] || "(no message)"

    # Use appropriate log level
    case level do
      "debug" -> Logger.debug("Crawler: #{message}")
      "info" -> Logger.info("Crawler: #{message}")
      "warning" -> Logger.warning("Crawler: #{message}", [])
      "error" -> Logger.error("Crawler: #{message}")
      _ -> Logger.debug("Crawler (#{level}): #{message}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:crawler_message, {:pagination_links, pagination_data}}, state) do
    # Handle pagination links message specifically
    current_url = pagination_data["current_url"] || "(unknown url)"
    next_page = pagination_data["next_page"]
    last_page = pagination_data["last_page"]
    page_links = pagination_data["page_links"] || []

    # Log the pagination information at info level for visibility
    Logger.info("PAGINATION: Found pagination links for #{current_url}")

    if next_page do
      Logger.info("PAGINATION: Next page link: #{next_page}")
    else
      Logger.info("PAGINATION: No next page link found")
    end

    # Log all page links at debug level to avoid overwhelming logs
    if length(page_links) > 0 do
      Logger.debug("PAGINATION: Found #{length(page_links)} page links")
      Enum.each(page_links, fn link ->
        page_number = link["page"]
        page_url = link["url"]
        Logger.debug("PAGINATION: Page #{page_number} -> #{page_url}")
      end)
    end

    if last_page do
      Logger.info("PAGINATION: Last page link: #{last_page}")
    end

    # Store the pagination data in state for potential future use
    updated_state = Map.put(state, :pagination_data, pagination_data)

    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:crawler_message, {:page_metadata, metadata}}, state) do
    # Check if metadata includes pagination information
    pagination_info = metadata["pagination"]

    # Initialize results collection with pagination tracking if available
    updated_state = Map.put(state, :results_collection, %{
      metadata: metadata,
      results: [],
      start_time: System.system_time(:millisecond),
      # Include pagination info if present
      pagination: pagination_info
    })

    if pagination_info do
      pages_discovered = pagination_info["pages_discovered"] || 0
      current_page = pagination_info["current_page"] || 1
      max_pages = pagination_info["max_pages"] || 5

      Logger.info("PAGINATION INFO: Processing page #{current_page} of #{max_pages} max (discovered #{pages_discovered} pages so far)")
    end

    Logger.debug("STATE UPDATED: Initialized results_collection in state")
    Logger.debug("WAITING FOR: Expecting page_results messages next")

    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:crawler_message, {:page_results, results_data}}, state) do
    # Get results from the data
    results = results_data["results"] || []
    metadata = results_data["metadata"] || %{}
    pagination = results_data["pagination"]

    # Safely extract chunk info with defaults to prevent KeyError
    chunk_info = %{
      index: results_data["chunk_index"] || 0,
      total: results_data["chunk_total"],
      size: results_data["chunk_size"]
    }

    # Log the chunk reception with pagination info if available
    if length(results) > 0 do
      chunk_number = "#{chunk_info.index + 1}/#{chunk_info.total || "?"}"

      pagination_info = if pagination do
        pages_discovered = pagination["pages_discovered"] || 0
        current_page = pagination["current_page"] || 1
        max_pages = pagination["max_pages"] || 5

        " - Page #{current_page}/#{max_pages} max (#{pages_discovered} pages discovered)"
      else
        ""
      end

      Logger.info("RECEIVED CHUNK: #{chunk_number}#{pagination_info} with #{length(results)} items")
    end

    # Start immediate processing if we have a process function
    if length(results) > 0 && state.job_meta && state.job_meta.process_fn do
      # Include pagination info in metadata for the processor
      chunk_metadata = if pagination do
        Map.put(metadata, "pagination", pagination)
      else
        metadata
      end

      process_chunk(results, chunk_metadata, state.job_meta.process_fn)
    end

    # Continue collecting all results for final completion and stats
    updated_collection = if collection = state[:results_collection] do
      updated = Map.update(collection, :results, results, fn existing ->
        # Make sure we have a list to append to
        existing_results = if is_list(existing), do: existing, else: []
        existing_results ++ results
      end)

      # Increment chunks received count
      updated = Map.put(updated, :chunks_received, Map.get(collection, :chunks_received, 0) + 1)

      # Increment chunks processed count
      updated = Map.put(updated, :chunks_processed, Map.get(collection, :chunks_processed, 0) + 1)

      # Only update chunks_total if we have that information and it's not already set
      updated = if chunk_info.total && (!Map.has_key?(updated, :chunks_total) || updated.chunks_total == 1) do
        Map.put(updated, :chunks_total, chunk_info.total)
      else
        updated
      end

      # Update pagination info if available
      updated = if pagination do
        Map.put(updated, :pagination, pagination)
      else
        updated
      end

      updated
    else
      # Initialize the collection with safe defaults
      %{
        metadata: metadata,
        results: results,
        start_time: System.system_time(:millisecond),
        chunks_received: 1,
        chunks_processed: 1,
        chunks_total: chunk_info.total || 1,  # Default to 1 if total is not provided
        pagination: pagination  # Include pagination info if available
      }
    end

    current_count = length(updated_collection.results)
    chunks_info = if Map.has_key?(updated_collection, :chunks_total) do
      " (#{updated_collection.chunks_received}/#{updated_collection.chunks_total} chunks)"
    else
      ""
    end

    pagination_info = if updated_collection[:pagination] do
      pages_discovered = updated_collection.pagination["pages_discovered"] || 0
      current_page = updated_collection.pagination["current_page"] || 1
      max_pages = updated_collection.pagination["max_pages"] || 5

      " - Page #{current_page}/#{max_pages} max (#{pages_discovered} pages discovered)"
    else
      ""
    end

    Logger.debug("PROGRESS: Now have #{current_count} total results collected#{chunks_info}#{pagination_info}")

    # Update state with the new collection
    {:noreply, %{state | results_collection: updated_collection}}
  end

  @impl true
  def handle_info({:crawler_message, {:page_complete, data}}, %{job_meta: %{caller: caller, timer_ref: timer_ref, process_fn: process_fn}} = state) when is_function(process_fn) do
    Logger.debug("SERVER RECEIVED: page_complete message with function reference")
    handle_page_complete(data, state, process_fn, caller, timer_ref)
  end

  @impl true
  def handle_info({:crawler_message, {:page_complete, data}}, %{job_meta: %{caller: caller, timer_ref: timer_ref}} = state) do
    Logger.debug("SERVER RECEIVED: page_complete message")

    # Get the processor function if available
    process_fn = case state do
      %{process_fn: fn_} when is_function(fn_) -> fn_
      %{job_meta: %{process_fn: fn_}} when is_function(fn_) -> fn_
      %{job_meta: %{processor: processor}} -> &processor.process/1
      _ -> nil
    end

    handle_page_complete(data, state, process_fn, caller, timer_ref)
  end

  @impl true
  def handle_info({:crawler_message, {:error, error_data}}, %{job_meta: %{caller: caller, timer_ref: timer_ref}} = state) do
    # Handle error message from the crawler
    url = error_data["url"] || "unknown"
    message = error_data["message"] || error_data["error"] || "(no message)"

    Logger.error("Crawler error for URL #{url}: #{message}")

    # Log stack trace if available
    if error_data["stack"] do
      Logger.error("Error stack trace: #{error_data["stack"]}")
    end

    # Cancel the timeout timer
    if timer_ref do
      Logger.debug("TIMER: Cancelling timeout timer")
      Process.cancel_timer(timer_ref)
    end

    # Reply to the original caller with the error
    try do
      caller_pid =
        case caller do
          {pid, _} when is_pid(pid) -> pid
          pid when is_pid(pid) -> pid
          _ -> nil
        end

      if caller_pid && Process.alive?(caller_pid) do
        Logger.info("REPLYING: Sending error reply to caller pid: #{inspect(caller_pid)}")
        GenServer.reply(caller, {:error, error_data})
      else
        Logger.warning("CALLER GONE: Cannot reply to caller - either nil or not alive. Caller: #{inspect(caller)}", [])
      end
    catch
      :error, {:badarg, _} ->
        Logger.warning("REPLY FAILED: Failed to send error reply to caller", [])
    end

    updated_state = %{state | errors: [error_data | state.errors], status: :error}
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:crawler_message, {:complete, data}}, %{job_meta: %{caller: caller, timer_ref: timer_ref}} = state) do
    # Logger.info("SERVER RECEIVED: complete message with data: #{inspect(data)}")

    # Check for pagination summary
    pagination_summary = data["pagination"]

    # Log the pagination summary if present
    if pagination_summary do
      pages_processed = pagination_summary["pages_processed"] || 0
      pages_discovered = pagination_summary["pages_discovered"] || 0
      max_pages = pagination_summary["max_pages"] || 5

      Logger.info("PAGINATION SUMMARY: Processed #{pages_processed} pages, discovered #{pages_discovered} pages (max set to #{max_pages})")
    end

    # Cancel the timeout timer
    if timer_ref do
      Logger.debug("TIMER: Cancelling timeout timer")
      Process.cancel_timer(timer_ref)
    end

    # Skip if we've already marked completion
    if Process.get(:all_chunks_completed) do
      Logger.debug("SKIPPING DUPLICATE COMPLETE: Already processed all chunks")
      {:noreply, %{state | status: :completed}}
    else
      # Check if we still have a results collection that needs to be processed
      # This handles cases where the page_complete callback didn't execute properly
      updated_state = if results_collection = state[:results_collection] do
        result_count = length(results_collection[:results] || [])
        Logger.warning("FOUND UNPROCESSED RESULTS: Have a results collection with #{result_count} items that needs processing during :complete")

        # Get the processor function
        {process_fn, _state} = case state do
          %{process_fn: fn_} when is_function(fn_) -> {fn_, state}
          %{job_meta: %{process_fn: fn_}} when is_function(fn_) -> {fn_, state}
          %{job_meta: %{processor: processor}} -> {&processor.process/1, state}
          _ -> {nil, state}
        end

        # Process the results if we have a processor
        if process_fn && is_function(process_fn) do
          Logger.info("LATE PROCESSING: Running processor function on unprocessed results")

          # Ensure we have a complete collection with end_time
          updated_collection = Map.put_new(results_collection, :end_time, System.system_time(:millisecond))

          # Add completion flag to ensure downstream processes know this is the final data
          updated_collection = Map.put(updated_collection, :is_complete, true)

          # Add pagination info if available
          updated_collection = if pagination_summary do
            Map.put(updated_collection, :pagination_summary, pagination_summary)
          else
            updated_collection
          end

          # Try to process but don't fail if it doesn't work
          try do
            process_result = process_fn.(updated_collection)
            Logger.info("LATE PROCESSING RESULT: #{inspect(process_result)}")
            # Mark as completed to prevent duplicate processing
            Process.put(:all_chunks_completed, true)
            # Clear results_collection after successful processing
            %{state | results_collection: nil}
          rescue
            e ->
              Logger.error("LATE PROCESSING ERROR: #{inspect(e)}")
              Logger.error("#{Exception.format(:error, e, __STACKTRACE__)}")
              # Set the flag to avoid retrying in future messages
              Process.put(:all_chunks_completed, true)
              # Don't clear results_collection but mark state as having an error
              %{state | status: :error, errors: ["Late processing error: #{Exception.message(e)}" | state.errors]}
          end
        else
          Logger.warning("NO PROCESSOR FOUND: Cannot process leftover results, no processor function available", [])
          # Mark as completed to prevent duplicate processing
          Process.put(:all_chunks_completed, true)
          # Clear results_collection anyway since we can't process it
          %{state | results_collection: nil}
        end
      else
        Logger.info("NO UNPROCESSED RESULTS: All results have been processed")
        # Mark as completed to prevent duplicate processing
        Process.put(:all_chunks_completed, true)
        # No results collection to process
        state
      end

      # Always reply to the original caller, even if we hit an error in the late processing
      try do
        caller_pid =
          case caller do
            {pid, _} when is_pid(pid) -> pid
            pid when is_pid(pid) -> pid
            _ -> nil
          end

        if caller_pid && Process.alive?(caller_pid) && !Process.get(:already_replied) do
          Logger.info("REPLYING: Sending completion reply to caller pid: #{inspect(caller_pid)} with status: :ok")
          GenServer.reply(caller, :ok)
          Process.put(:already_replied, true)
          Logger.info("REPLY SENT: Successfully replied with :ok to caller")
        else
          if Process.get(:already_replied) do
            Logger.info("SKIPPING REPLY: Already replied to caller")
          else
            Logger.warning("CALLER GONE: Cannot reply to caller - either nil or not alive. Caller: #{inspect(caller)}", [])
          end
        end
      catch
        :error, {:badarg, _} ->
          Logger.warning("REPLY FAILED: Failed to send completion reply to caller", [])
      end

      # Update and return the state
      Logger.info("STATE UPDATED: Setting status to completed")
      {:noreply, %{updated_state | status: :completed}}
    end
  end

  @impl true
  def handle_info({:crawler_message, {:page_results_header, data}}, state) do
    Logger.info("TRACE: Received PAGE_RESULTS_HEADER message with metadata: #{inspect(data["metadata"])}")
    Logger.info("TRACE: Will expect #{data["total_count"] || "unknown"} total results")

    # Store the header information in state for future chunks
    updated_state = Map.put(state, :chunking_data, %{
      header: data,
      chunks_received: 0,
      chunks_expected: data["total_chunks"] || 0,
      chunks: [],
      start_time: System.system_time(:millisecond)
    })

    Logger.info("TRACE: Initialized chunking mode, waiting for chunks")
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:crawler_message, {:page_results_chunk, data}}, %{chunking_data: chunking_data} = state) do
    chunk_index = data["chunk_index"] || 0
    chunk_results = data["results"] || []
    chunks_received = (chunking_data.chunks_received || 0) + 1
    chunk_count = data["chunk_count"] || 0

    Logger.info("TRACE: Received PAGE_RESULTS_CHUNK #{chunk_index + 1}/#{data["chunk_count"] || "?"} with #{length(chunk_results)} items")

    # Store this chunk
    current_chunks = chunking_data.chunks || []
    new_chunks = [chunk_results | current_chunks]

    # Update chunking data in state
    updated_chunking_data = Map.merge(chunking_data, %{
      chunks: new_chunks,
      chunks_received: chunks_received,
      last_chunk_time: System.system_time(:millisecond)
    })

    Logger.info("TRACE: Stored chunk, now have #{chunks_received} chunks with total of #{Enum.sum(Enum.map(new_chunks, &length/1))} results")

    # If this is the last chunk we're expecting, set a safety timer to auto-complete
    # in case the completion message gets lost
    if chunks_received == chunk_count do
      Logger.info("TRACE: Received what appears to be the last chunk (#{chunk_index + 1}/#{chunk_count}), setting auto-complete timer")
      # Cancel any existing timer
      if Map.has_key?(chunking_data, :completion_timer) && chunking_data.completion_timer do
        Process.cancel_timer(chunking_data.completion_timer)
      end

      # Set a new timer for 5 seconds
      timer_ref = Process.send_after(self(), :chunks_auto_complete, 5000)

      # Add timer to chunking data
      _updated_chunking_data = Map.put(updated_chunking_data, :completion_timer, timer_ref)
      Logger.info("TRACE: Set auto-completion timer for 5 seconds from now")
    end

    {:noreply, %{state | chunking_data: updated_chunking_data}}
  end

  @impl true
  def handle_info({:crawler_message, {:page_results_complete, data}}, %{chunking_data: chunking_data, job_meta: %{process_fn: process_fn}} = state) when is_function(process_fn) do
    Logger.info("TRACE: Received PAGE_RESULTS_COMPLETE with #{data["total_items"] || "unknown"} total items across #{data["total_chunks"] || "unknown"} chunks")

    # Calculate processing time
    start_time = chunking_data.start_time || System.system_time(:millisecond)
    elapsed_ms = System.system_time(:millisecond) - start_time

    # Combine all chunks
    chunks = chunking_data.chunks || []
    all_results = chunks
      |> Enum.reverse()
      |> Enum.flat_map(&(&1))

    Logger.info("TRACE: Reassembled #{length(all_results)} results from #{length(chunks)} chunks in #{elapsed_ms}ms")

    # Recreate full page data with header information
    header = chunking_data.header || %{}
    page_data = %{
      "metadata" => header["metadata"] || %{},
      "page_info" => header["page_info"] || %{},
      "results" => all_results
    }

    # Forward to the page_results handler by sending ourselves a message
    Logger.info("TRACE: Forwarding reassembled data with #{length(all_results)} items to page_results handler")
    send(self(), {:crawler_message, {:page_results, page_data}})
    Logger.info("TRACE: Successfully forwarded reassembled chunk data to page_results handler (with process_fn)")

    # Clear chunking data from state
    {:noreply, Map.drop(state, [:chunking_data])}
  end

  @impl true
  def handle_info({:crawler_message, {:page_results_complete, data}}, %{chunking_data: chunking_data} = state) do
    Logger.info("TRACE: Received PAGE_RESULTS_COMPLETE with #{data["total_items"] || "unknown"} total items across #{data["total_chunks"] || "unknown"} chunks (no process_fn)")

    # Calculate processing time
    start_time = chunking_data.start_time || System.system_time(:millisecond)
    elapsed_ms = System.system_time(:millisecond) - start_time

    # Combine all chunks
    chunks = chunking_data.chunks || []
    all_results = chunks
      |> Enum.reverse()
      |> Enum.flat_map(&(&1))

    Logger.info("TRACE: Reassembled #{length(all_results)} results from #{length(chunks)} chunks in #{elapsed_ms}ms")

    # Recreate full page data with header information
    header = chunking_data.header || %{}
    page_data = %{
      "metadata" => header["metadata"] || %{},
      "page_info" => header["page_info"] || %{},
      "results" => all_results
    }

    # Forward to the page_results handler by sending ourselves a message
    Logger.info("TRACE: Forwarding reassembled data with #{length(all_results)} items to page_results handler")
    send(self(), {:crawler_message, {:page_results, page_data}})
    Logger.info("TRACE: Successfully forwarded reassembled chunk data to page_results handler")

    # Clear chunking data from state
    {:noreply, Map.drop(state, [:chunking_data])}
  end

  @impl true
  def handle_info({:crawler_message, {:page_results_complete, data}}, state) do
    # We received a completion message but we're not in chunking mode
    # Let's check if we can create a reasonable response anyway
    Logger.warning("Received PAGE_RESULTS_COMPLETE but not in chunking mode. Auto-handling completion.", [])
    Logger.info("TRACE: page_results_complete data: #{inspect(data)}")

    # Create an empty result array - we can't reassemble anything
    page_data = %{
      "metadata" => %{
        "auto_generated" => true,
        "error" => "Received chunking completion without chunks"
      },
      "results" => []
    }

    # Forward to the page_results handler by sending ourselves a message
    Logger.info("TRACE: Forwarding empty result set to page_results handler")
    send(self(), {:crawler_message, {:page_results, page_data}})

    {:noreply, state}
  end

  @impl true
  def handle_info({:crawler_message, message_type}, state) do
    Logger.info("SERVER RECEIVED UNHANDLED MESSAGE: #{inspect(message_type)}")
    # Add message type-specific debugging
    case message_type do
      {type, data} when is_atom(type) ->
        Logger.debug("UNHANDLED MESSAGE TYPE: #{type}, data: #{inspect(String.slice(JSON.encode!(data || %{}), 0, 300))}")
      other ->
        Logger.debug("UNKNOWN MESSAGE FORMAT: #{inspect(other)}")
    end
    {:noreply, state}
  end

  @impl true
  def handle_info({:port_exit, reason}, state) do
    Logger.error("Port exited: #{inspect(reason)}")
    {:noreply, %{state | status: :error, port: nil, errors: ["Port exited: #{inspect(reason)}" | state.errors]}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :port, port, reason}, %{port: port} = state) do
    Logger.info("Port monitor received DOWN message: #{inspect(reason)}")
    {:noreply, %{state | status: :completed, port: nil}}
  end

  @impl true
  def handle_info({:EXIT, port, :normal}, %{port: port} = state) when is_port(port) do
    Logger.debug("Port process exited normally: #{inspect(port)}")
    {:noreply, %{state | port: nil}}
  end

  @impl true
  def handle_info({:EXIT, pid, :normal}, %{port: _port} = state) when is_pid(pid) do
    Logger.debug("Linked process exited normally: #{inspect(pid)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, pid, :killed}, state) do
    Logger.info("Process #{inspect(pid)} exited with :killed, cleaning up gracefully")

    # Clean up port if it exists
    cleanup_port(state.port)

    # Cancel any timer if it exists
    if state[:job_meta] && state[:job_meta][:timer_ref] do
      Process.cancel_timer(state.job_meta.timer_ref)
    end

    # Try to reply to caller if needed
    if state[:job_meta] && state[:job_meta][:caller] do
      try do
        caller = state.job_meta.caller
        caller_pid = case caller do
          {pid, _} when is_pid(pid) -> pid
          pid when is_pid(pid) -> pid
          _ -> nil
        end

        if caller_pid && Process.alive?(caller_pid) && !Process.get(:already_replied) do
          Logger.info("Sending completion to caller after process was killed")
          GenServer.reply(caller, :ok)
          Process.put(:already_replied, true)
        end
      catch
        :error, _ ->
          Logger.debug("Failed to reply to caller after process was killed - this is expected if we already replied")
      end
    end

    # Return to idle state but keep the server running
    updated_state = %{state |
      status: :idle,
      port: nil,
      current_urls: [],
      crawled_data: [],
      results_collection: nil,
      processor_pid: nil
    }

    Logger.info("CrawlerServer reset to idle state after process was killed")
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    Logger.info("Process #{inspect(pid)} exited with reason: #{inspect(reason)}")

    # Clean up port if it exists
    cleanup_port(state.port)

    # Cancel any timer if it exists
    if state[:job_meta] && state[:job_meta][:timer_ref] do
      Process.cancel_timer(state.job_meta.timer_ref)
    end

    # Try to reply to caller if needed
    if state[:job_meta] && state[:job_meta][:caller] do
      try do
        caller = state.job_meta.caller
        caller_pid = case caller do
          {pid, _} when is_pid(pid) -> pid
          pid when is_pid(pid) -> pid
          _ -> nil
        end

        if caller_pid && Process.alive?(caller_pid) && !Process.get(:already_replied) do
          Logger.info("Sending error to caller after process crashed")
          GenServer.reply(caller, {:error, {:process_crashed, reason}})
          Process.put(:already_replied, true)
        end
      catch
        :error, _ ->
          Logger.debug("Failed to reply to caller after process crashed - this is expected if we already replied")
      end
    end

    # Return to idle state but keep the server running
    updated_state = %{state |
      status: :error,
      port: nil,
      current_urls: [],
      crawled_data: [],
      results_collection: nil,
      processor_pid: nil,
      errors: ["Process crashed: #{inspect(reason)}" | state.errors]
    }

    Logger.info("CrawlerServer reset to error state after process crash")
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:crawling_timeout, from}, state) do
    Logger.warning("Crawler operation is taking too long, sending friendly timeout response", [])

    # Reply to the caller with a timeout error
    GenServer.reply(from, {:error, :timeout})

    # Update state but don't stop the crawler - let it continue running
    {:noreply, %{state | errors: ["Operation timed out" | state.errors]}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) when is_port(port) do
    # Special handling for timeout messages to reduce error log noise
    if String.contains?(data, "Timeout waiting for Node.js") do
      Logger.info("Node.js timeout detected - this is expected at completion and doesn't affect processing")
      {:noreply, state}
    else
      # Direct filter for known PlaywrightCrawler statistics messages
      if is_binary(data) &&
         (String.contains?(data, "PlaywrightCrawler: All requests from the queue have been processed") ||
          String.contains?(data, "PlaywrightCrawler: Final request statistics:") ||
          String.contains?(data, "PlaywrightCrawler: Finished! Total")) do
        Logger.debug("Crawler stats: #{String.trim(data)}")
        {:noreply, state}
      else
        # Log the first part of the data for debugging (limited to avoid overwhelming logs)
        if byte_size(data) > 100 do
          Logger.debug("Raw port data (first 100 chars): #{inspect(String.slice(data, 0, 100))}")
        else
          Logger.debug("Raw port data: #{inspect(data)}")
        end

        # First check for JSON messages
        if String.contains?(data, "ELIXIR_JSON_MESSAGE") do
          # Extract all JSON messages from the data
          raw_messages = String.split(data, "ELIXIR_JSON_MESSAGE:")

          # Skip the first part (before any message)
          messages = Enum.drop(raw_messages, 1)
          message_count = length(messages)

          if message_count > 0 do
            Logger.debug("Found #{message_count} JSON messages in port data")

            # Process each JSON message found
            Enum.each(messages, fn raw_message ->
              trimmed = String.trim(raw_message)

              # Try to extract the JSON object
              case Regex.run(~r/(\{.*\})/s, trimmed) do
                [_, json_str] ->
                  # Try to sanitize the JSON string by replacing invalid UTF-8 sequences
                  sanitized_json = json_str
                    |> String.codepoints()
                    |> Enum.filter(fn c -> String.valid?(c) end)
                    |> Enum.join("")

                  # Log if we had to sanitize
                  if sanitized_json != json_str do
                    byte_diff = byte_size(json_str) - byte_size(sanitized_json)
                    Logger.info("Sanitized JSON string, removed #{byte_diff} invalid bytes")
                  end

                  # Try to parse the sanitized JSON
                  case JSON.decode(sanitized_json) do
                    {:ok, %{"type" => type, "data" => payload}} ->
                      # Successfully decoded a valid message
                      type_atom = String.to_atom(type)
                      # Logger.info("Processed JSON message of type: #{type}")
                      send(self(), {:crawler_message, {type_atom, payload}})

                    {:ok, other} ->
                      # JSON parsed but not in the expected format
                      Logger.warning("JSON message missing type or data: #{inspect(other)}")

                    {:error, error} ->
                      # Failed to parse the JSON - log details but don't crash
                      Logger.warning("Failed to parse JSON: #{inspect(error)}")
                      Logger.debug("Problem JSON content: #{String.slice(sanitized_json, 0, 100)}...")
                  end

                nil ->
                  # No valid JSON found
                  Logger.warning("Could not extract JSON from message: #{String.slice(trimmed, 0, 50)}...")
              end
            end)

            # Return early after processing all JSON messages
            {:noreply, state}
          end
        end

        # If no JSON messages were found or processed, handle as log
        # Try different log message patterns
        cond do
          # Detect page complete confirmation message
          String.match?(data, ~r/CRITICAL_MESSAGE_SENT: page_complete/) ->
            Logger.debug("Crawler sent page_complete confirmation")
            {:noreply, state}

          # Detect complete confirmation message
          String.match?(data, ~r/CRITICAL_MESSAGE_SENT: complete/) ->
            Logger.debug("Crawler sent complete confirmation")
            {:noreply, state}

          # Handle Node.js timeout messages more gracefully
          String.contains?(data, "Timeout waiting for Node.js") ->
            Logger.debug("Node.js timeout - this is expected when the crawler is completing")
            {:noreply, state}

          # Handle watchdog timeout message more gracefully
          String.contains?(data, "Watchdog timeout") ->
            Logger.debug("Crawler watchdog timeout - this is expected when tasks are complete")
            {:noreply, state}

          # Detect direct debug messages
          String.contains?(data, "DIRECT_DEBUG:") ->
            msg = String.replace(data, "DIRECT_DEBUG:", "") |> String.trim()
            Logger.debug("Crawler debug: #{msg}")
            {:noreply, state}

          # IMPORTANT: Check for PlaywrightCrawler log messages BEFORE the generic LOG: match
          # This ensures PlaywrightCrawler stats/completion messages are caught first
          String.contains?(data, "LOG:") && String.contains?(data, "PlaywrightCrawler:") && (
            String.contains?(data, "Final request statistics") ||
            String.contains?(data, "All requests from the queue have been processed") ||
            String.contains?(data, "Finished! Total") ||
            String.contains?(data, "request statistics") ||
            String.contains?(data, "shut down") ||
            String.contains?(data, "requests") ||
            String.contains?(data, "succeeded") ||
            String.contains?(data, "failed")) ->
              clean_message = String.replace(data, "LOG:", "") |> String.trim()
              Logger.debug("Crawler stats: #{clean_message}")
              {:noreply, state}

          # Detect ANSI colored logs
          String.contains?(data, "\e[") ->
            # Strip ANSI colors and log appropriately
            clean_message = data
              |> String.replace(~r/\e\[\d+m/, "")
              |> String.replace(~r/\e\[\d+;\d+m/, "")
              |> String.trim()

            log_level = cond do
              String.contains?(clean_message, "DEBUG") -> :debug
              String.contains?(clean_message, "INFO") -> :info
              String.contains?(clean_message, "WARNING") -> :warning
              String.contains?(clean_message, "ERROR") -> :error
              true -> :info
            end

            Logger.log(log_level, "Crawler log: #{clean_message}")
            {:noreply, state}

          # Detect standard log messages with format: LOG: [LEVEL] message or LOG: LEVEL message
          String.match?(data, ~r/LOG: (?:\[)?([A-Z]+)(?:\])?\s+(.+)/) ->
            captures = Regex.run(~r/LOG: (?:\[)?([A-Z]+)(?:\])?\s+(.+)/, String.trim(data))
            if captures && length(captures) > 2 do
              level_str = String.downcase(Enum.at(captures, 1))
              message = Enum.at(captures, 2)
              level = String.to_atom(level_str)

              # Filter crawler statistics and completion messages to debug level
              cond do
                # Match PlaywrightCrawler stats in different formats
                String.contains?(message, "PlaywrightCrawler:") && (
                  # Specific statistics messages
                  String.contains?(message, "Final request statistics") ||
                  String.contains?(message, "All requests from the queue have been processed") ||
                  String.contains?(message, "Finished! Total") ||
                  String.contains?(message, "request statistics") ||
                  # Generic patterns for operational messages
                  String.contains?(message, "shut down") ||
                  String.contains?(message, "requests") ||
                  String.contains?(message, "succeeded") ||
                  String.contains?(message, "failed")
                ) ->
                  Logger.debug("Crawler stats: #{message}")
                true ->
                  Logger.log(level, "Crawler: #{message}")
              end
            else
              # Fall back to simple log
              Logger.info("Crawler log: #{String.trim(data)}")
            end
            {:noreply, state}

          # Any other log messages
          String.contains?(data, "LOG:") ->
            clean_message = String.replace(data, "LOG:", "") |> String.trim()

            # Filter statistics and completion messages to debug level
            cond do
              # Match PlaywrightCrawler stats in different formats
              String.contains?(clean_message, "PlaywrightCrawler:") && (
                # Specific statistics messages
                String.contains?(clean_message, "Final request statistics") ||
                String.contains?(clean_message, "All requests from the queue have been processed") ||
                String.contains?(clean_message, "Finished! Total") ||
                String.contains?(clean_message, "request statistics") ||
                # Generic patterns for operational messages
                String.contains?(clean_message, "shut down") ||
                String.contains?(clean_message, "requests") ||
                String.contains?(clean_message, "succeeded") ||
                String.contains?(clean_message, "failed")
              ) ->
                Logger.debug("Crawler stats: #{clean_message}")
              true ->
                Logger.info("Crawler log: #{clean_message}")
            end
            {:noreply, state}

          # Fallback for any other unrecognized data
          true ->
            Logger.debug("Unrecognized port data: #{String.slice(String.trim(data), 0, 100)}")
            {:noreply, state}
        end
      end
    end
  end

  # Direct handler for results that weren't processed in chunks
  @impl true
  def handle_info({:crawler_message, {:page_results_direct, page_data}}, state) do
    Logger.info("Received direct page results with #{length(page_data["results"] || [])} items")
    {:noreply, state}
  end

  # Helper function to handle page_complete messages consistently
  defp handle_page_complete(data, state, process_fn, caller, timer_ref) do
    # Log the data content
    Logger.debug("PAGE_COMPLETE DATA: #{inspect(data)}")

    # Check for pagination info and determine if this is the final page
    pagination = data["pagination"]
    is_final_page = !pagination || data["is_final_page"] || pagination["is_final_page"]

    if pagination && !is_final_page do
      Logger.info("PAGINATION: Completed page #{pagination["current_page"]} of #{pagination["total_pages"] || "unknown"}, more pages expected")
    end

    # Check if we've already handled completion (using process dictionary)
    if Process.get(:all_chunks_completed) && is_final_page do
      # Still cancel timeout timer if it exists
      if timer_ref, do: Process.cancel_timer(timer_ref)

      # Return state without collection to prevent duplicate processing
      {:noreply, Map.delete(state, :results_collection)}
    else
      # Check if we have a results collection
      if results_collection = state[:results_collection] do
        # Log collection details
        result_count = length(results_collection[:results] || [])
        chunks_info = if Map.has_key?(results_collection, :chunks_total) do
          "#{Map.get(results_collection, :chunks_received, 0)}/#{Map.get(results_collection, :chunks_total, 0)} chunks"
        else
          "no chunking metadata"
        end

        # Get total results count from metadata if available
        total_results_info = cond do
          # From page_complete data
          data["total_results"] -> " (from total of #{data["total_results"]} in search)"
          # From metadata in results collection
          results_collection[:metadata] && results_collection[:metadata]["total_results"] -> " (from total of #{results_collection[:metadata]["total_results"]} in search)"
          true -> ""
        end

        # Add pagination info if available
        pagination_info = if pagination do
          pages_discovered = pagination["pages_discovered"] || 0
          current_page = pagination["current_page"] || 1
          max_pages = pagination["max_pages"] || 5

          " - Page #{current_page}/#{max_pages} max (#{pages_discovered} pages discovered)"
        else
          ""
        end

        Logger.debug("PROCESSING COLLECTION: Found #{result_count} results (#{chunks_info})#{total_results_info}#{pagination_info}")

        # Safely get chunk counts with defaults to prevent crashes
        chunks_processed = Map.get(results_collection, :chunks_processed, 0)
        chunks_total = Map.get(results_collection, :chunks_total, 1)

        # Check if all chunks were processed (safely handle the case where chunks_total might be nil)
        if chunks_total != nil && chunks_processed >= chunks_total do
          Logger.debug("FINAL PROCESSING: All chunks were already processed individually (#{chunks_processed}/#{chunks_total})")

          # For non-final pages, we don't want to set the completion flag or reply to the caller yet
          if is_final_page do
            # Set flag in process dictionary to avoid double-processing
            Process.put(:all_chunks_completed, true)

            # Just update the status, no need to reprocess
            if caller do
              Logger.info("REPLYING: Sending completion to caller")
              try do
                GenServer.reply(caller, :ok)
              catch
                :error, {:badarg, _} ->
                  Logger.warning("REPLY FAILED: Failed to send completion reply to caller", [])
              end
            end

            # Cancel timeout timer
            if timer_ref, do: Process.cancel_timer(timer_ref)

            # Clear collection to prevent duplicate processing
            {:noreply, Map.delete(state, :results_collection)}
          else
            # For non-final pages, keep the state but don't set completion flags
            Logger.info("PAGINATION: Not the final page, maintaining collection state")
            {:noreply, state}
          end
        else
          # Check if we're expecting more chunks (safely)
          if Map.has_key?(results_collection, :chunks_total) &&
             Map.has_key?(results_collection, :chunks_received) &&
             results_collection.chunks_received < results_collection.chunks_total do
            Logger.warning("INCOMPLETE CHUNKS: Only received #{results_collection.chunks_received} of #{results_collection.chunks_total} chunks, but processing anyway")
          end

          # Process the results if we have a processor function
          if process_fn && is_function(process_fn) do
            start_time = System.system_time(:millisecond)

            # Add completion data to the collection
            updated_collection = Map.merge(results_collection, %{
              end_time: System.system_time(:millisecond),
              is_complete: is_final_page,  # Only mark as complete if it's the final page
              is_page_complete: true,      # Mark as page complete
              page_complete_data: data
            })

            try do
              result_count = length(updated_collection[:results] || [])
              Logger.info("CALLING PROCESSOR: Invoking process_fn with #{result_count} results#{pagination_info}")
              process_page_results(updated_collection, process_fn)
              elapsed_ms = System.system_time(:millisecond) - start_time
              Logger.info("PROCESSING COMPLETE: Processed #{result_count} results in #{elapsed_ms}ms")

              # Only set completion flag and reply to caller if this is the final page
              if is_final_page do
                # Set flag in process dictionary to avoid double-processing
                Process.put(:all_chunks_completed, true)

                # Reply to caller only on final page
                if caller do
                  Logger.info("REPLYING: Sending completion to caller (final page)")
                  try do
                    GenServer.reply(caller, :ok)
                  catch
                    :error, {:badarg, _} ->
                      Logger.warning("REPLY FAILED: Failed to send completion reply to caller", [])
                  end
                end

                # Cancel timeout timer
                if timer_ref, do: Process.cancel_timer(timer_ref)

                # Clear the collection after successful processing of final page
                {:noreply, Map.delete(state, :results_collection)}
              else
                # For non-final pages, log but don't complete or reply
                Logger.info("PAGINATION: Page processing complete, waiting for next page")
                # Keep state intact for next page
                {:noreply, state}
              end
            rescue
              e ->
                Logger.error("ERROR PROCESSING RESULTS: #{inspect(e)}")
                Logger.error("#{Exception.format(:error, e, __STACKTRACE__)}")
                # Keep the collection in case we want to retry
                {:noreply, state}
            end
          else
            Logger.warning("NO PROCESSOR FOUND: Cannot process results, no processor function available", [])

            # If we have a caller and this is the final page, respond now
            if caller && is_final_page do
              Logger.info("REPLYING EARLY: No processor but we have results, sending completion")
              try do
                GenServer.reply(caller, :ok)
              catch
                :error, {:badarg, _} ->
                  Logger.warning("REPLY FAILED: Failed to send early completion reply to caller", [])
              end

              # Cancel the timeout timer if it exists
              if timer_ref, do: Process.cancel_timer(timer_ref)
            end

            # Set flag in process dictionary to avoid double-processing, but only for final page
            if is_final_page do
              Process.put(:all_chunks_completed, true)
              # Clear collection to prevent duplicate processing
              {:noreply, Map.delete(state, :results_collection)}
            else
              # For non-final pages, keep state
              {:noreply, state}
            end
          end
        end
      else
        Logger.warning("NO RESULTS COLLECTION: Received page_complete but no results were collected", [])

        # Try to get the job metadata for debugging
        job_meta = Map.get(state, :job_meta, nil)
        Logger.debug("JOB META: #{inspect(job_meta)}")

        # Even without results, check if we have a processor that might handle empty results
        if process_fn && is_function(process_fn) do
          Logger.info("ATTEMPTING PROCESSING: Calling processor with empty results")
          try do
            empty_collection = %{
              metadata: data["metadata"] || %{},
              results: [],
              start_time: System.system_time(:millisecond),
              end_time: System.system_time(:millisecond),
              is_complete: is_final_page,  # Only mark as complete if final page
              page_complete_data: data,
              pagination: pagination
            }

            processed_result = process_fn.(empty_collection)
            Logger.info("EMPTY PROCESSING COMPLETE: #{inspect(processed_result)}")
          rescue
            e ->
              Logger.error("ERROR PROCESSING EMPTY RESULTS: #{inspect(e)}")
              Logger.error("#{Exception.format(:error, e, __STACKTRACE__)}")
          end
        end

        # If we have a caller and this is the final page, respond now
        if caller && is_final_page do
          Logger.info("REPLYING EARLY: No results collection, sending empty completion")
          try do
            GenServer.reply(caller, :ok)
          catch
            :error, {:badarg, _} ->
              Logger.warning("REPLY FAILED: Failed to send empty completion reply to caller", [])
          end

          # Cancel the timeout timer if it exists
          if timer_ref, do: Process.cancel_timer(timer_ref)
        end

        # Set flag in process dictionary to avoid double-processing, but only for final page
        if is_final_page do
          Process.put(:all_chunks_completed, true)
        end

        {:noreply, state}
      end
    end
  end



  @impl true
  def terminate(reason, state) do
    Logger.info("CrawlerServer terminating with reason: #{inspect(reason)}")
    cleanup_port(state.port)
    :ok
  end

  # Private Functions

  defp cleanup_port(nil), do: :ok
  defp cleanup_port(port) when is_port(port) do
    Logger.info("Cleaning up crawler port: #{inspect(port)}")
    if Port.info(port) != nil do
      try do
        Port.close(port)
        Logger.info("Port closed successfully")
      rescue
        e in ArgumentError ->
          Logger.warning("Error closing port: #{Exception.message(e)}", [])
      end
    end
  end

  # Process the results collected from the crawler
  defp process_page_results(results_collection, process_fn) when is_function(process_fn) do
    # Prepare the data for processing
    results = results_collection[:results] || []
    result_count = length(results)

    # Add end_time to the collection if not present
    results_collection = Map.put_new(results_collection, :end_time, System.system_time(:millisecond))

    # Log sample of data for debugging
    if result_count > 0 do
      sample = Enum.take(results, min(2, result_count))
      Logger.debug("SAMPLE DATA: First #{length(sample)} items: #{inspect(sample)}")
    end

    # Measure processing time
    _start_time = System.system_time(:millisecond)

    # Call the processing function with our collection
    try do
      Logger.debug("CALLING PROCESSOR: Function #{inspect(process_fn)}")
      process_fn.(results_collection)
    rescue
      e ->
        Logger.error("PROCESSOR ERROR: #{inspect(e)}")
        Logger.error("STACKTRACE: #{Exception.format(:error, e, __STACKTRACE__)}")
        # Re-raise to allow the caller to handle the error
        reraise e, __STACKTRACE__
    end
  end

  # Fallback for when no processor function is provided
  defp process_page_results(_results_collection, nil) do
    Logger.warning("NO PROCESSOR FUNCTION: Cannot process results without a processor")
    {:error, :no_processor}
  end

  @doc """
  Process a message from the crawler port, extracting and routing JSON messages.
  """
  def process_message(message_text) when is_binary(message_text) do
    # Find all ELIXIR_JSON_MESSAGE in the message
    message_count = Regex.scan(~r/ELIXIR_JSON_MESSAGE:/, message_text) |> length()

    # First quick check to see if this looks like a valid message
    if message_count > 0 do
      # Extract the message data
      messages = Regex.scan(~r/ELIXIR_JSON_MESSAGE:\s*(\{.*?\})/s, message_text)

      # Process all found JSON messages
      Enum.reduce_while(messages, {:error, :no_valid_messages}, fn [_, json_str], acc ->
        case Jason.decode(json_str) do
          {:ok, decoded} ->
            # Handle the message based on its type
            case decoded do
              %{"type" => "page_results", "data" => _data} = msg ->
                # Logger.debug("RECEIVED: JSON message of type 'page_results'")
                GenServer.cast(__MODULE__, {:crawler_message, {:page_results, msg["data"]}})
                {:cont, {:ok, :page_results}}

              %{"type" => "page_metadata", "data" => _data} = msg ->
                # Logger.debug("RECEIVED: JSON message of type 'page_metadata'")
                GenServer.cast(__MODULE__, {:crawler_message, {:page_metadata, msg["data"]}})
                {:cont, {:ok, :page_metadata}}

              %{"type" => "page_complete", "data" => _data} = msg ->
                # Logger.debug("RECEIVED: JSON message of type 'page_complete'")
                send(__MODULE__, {:crawler_message, {:page_complete, msg["data"]}})
                {:halt, {:ok, :page_complete}}

              %{"type" => "pagination_links", "data" => _data} = msg ->
                Logger.debug("RECEIVED: JSON message of type 'pagination_links'")
                send(__MODULE__, {:crawler_message, {:pagination_links, msg["data"]}})
                {:cont, {:ok, :pagination_links}}

              %{"type" => "complete", "data" => _data} = msg ->
                # Logger.debug("RECEIVED: JSON message of type 'complete'")
                send(__MODULE__, {:crawler_message, {:complete, msg["data"]}})
                {:halt, {:ok, :complete}}

              %{"type" => "error", "data" => _data} = msg ->
                Logger.error("RECEIVED: JSON message of type 'error': #{inspect(msg["data"])}")
                send(__MODULE__, {:crawler_message, {:error, msg["data"]}})
                {:cont, {:ok, :error}}

              %{"type" => "log", "data" => _data} = msg ->
                # Logger.debug("RECEIVED: JSON message of type 'log'")
                GenServer.cast(__MODULE__, {:crawler_message, {:log, msg["data"]}})
                {:cont, {:ok, :log}}

              _ ->
                Logger.warning("UNKNOWN MESSAGE TYPE: #{inspect(decoded)}", [])
                {:cont, acc}
            end

          {:error, parse_error} ->
            Logger.error("Failed to parse JSON message: #{inspect(parse_error)}")
            Logger.error("Failed JSON: #{json_str}")
            {:cont, acc}
        end
      end)
    else
      # This doesn't look like a structured message we can handle
      check_for_critical_confirmation(message_text)
    end
  end

  # Check for special confirmation messages that don't follow the standard JSON format
  defp check_for_critical_confirmation(message_text) do
    cond do
      # Check for page_complete confirmations
      String.match?(message_text, ~r/CRITICAL_MESSAGE_SENT: page_complete/) ->
        Logger.info("Found page_complete confirmation message")
        send(__MODULE__, {:crawler_message, {:page_complete, %{"status" => "success", "confirmed_at" => System.system_time(:millisecond)}}})
        {:ok, :page_complete_confirmation}

      # Check for complete message confirmations
      String.match?(message_text, ~r/CRITICAL_MESSAGE_SENT: complete/) ->
        Logger.info("Found completion confirmation message")
        send(__MODULE__, {:crawler_message, {:complete, %{"status" => "success", "confirmed_at" => System.system_time(:millisecond)}}})
        {:ok, :complete_confirmation}

      # No recognized confirmation pattern
      true ->
        {:error, :not_a_confirmation_message}
    end
  end

  # Add this function to process individual chunks
  defp process_chunk(results, metadata, process_fn) when is_function(process_fn) do
    # Enqueue the chunk processing task instead of starting it directly
    CivicForum.Crawlers.ChunkTaskQueue.enqueue(results, metadata, process_fn)
    Logger.debug("STARTED PROCESSING: Enqueued chunk with #{length(results)} items for sequential processing")
  end
end

defmodule CivicForum.Crawlers.ChunkTaskQueue do
  @moduledoc """
  A simple task queue for processing crawler chunks sequentially.
  This ensures only one chunk is processed at a time to avoid transaction conflicts.
  """
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def enqueue(chunk, metadata, process_fn) do
    GenServer.cast(__MODULE__, {:enqueue, chunk, metadata, process_fn})
  end

  @impl true
  def init(_) do
    {:ok, %{queue: :queue.new(), processing: false}}
  end

  @impl true
  def handle_cast({:enqueue, chunk, metadata, process_fn}, %{queue: _queue, processing: false} = state) do
    # Start processing immediately if not already processing
    Logger.info("TASK QUEUE: Starting to process chunk with #{length(chunk)} items (no queue)")
    spawn_task(chunk, metadata, process_fn)
    {:noreply, %{state | processing: true}}
  end

  @impl true
  def handle_cast({:enqueue, chunk, metadata, process_fn}, %{queue: queue} = state) do
    # Queue the task for later
    Logger.debug("TASK QUEUE: Queuing chunk with #{length(chunk)} items for later processing")
    new_queue = :queue.in({chunk, metadata, process_fn}, queue)
    {:noreply, %{state | queue: new_queue}}
  end

  @impl true
  def handle_cast(:task_complete, %{queue: queue} = state) do
    # Check if there are queued tasks
    case :queue.out(queue) do
      {{:value, {chunk, metadata, process_fn}}, new_queue} ->
        # Process next task from queue
        Logger.info("TASK QUEUE: Starting next queued chunk with #{length(chunk)} items")
        spawn_task(chunk, metadata, process_fn)
        {:noreply, %{state | queue: new_queue}}

      {:empty, _} ->
        # No more tasks in queue
        Logger.info("TASK QUEUE: All tasks completed, queue empty")
        {:noreply, %{state | processing: false}}
    end
  end

  defp spawn_task(chunk, metadata, process_fn) do
    Task.Supervisor.start_child(CivicForum.TaskSupervisor, fn ->
      try do
        # Create a chunk-specific collection
        chunk_collection = %{
          metadata: metadata,
          results: chunk,
          start_time: System.system_time(:millisecond),
          end_time: System.system_time(:millisecond), # Set both for consistency
          is_chunk: true,  # Flag to indicate this is a partial chunk
          is_complete: false # Not the final collection
        }

        start_time = System.system_time(:millisecond)
        Logger.info("CHUNK PROCESSING: Started processing chunk with #{length(chunk)} items")

        # Call the processing function with just this chunk
        result = process_fn.(chunk_collection)

        elapsed_ms = System.system_time(:millisecond) - start_time
        Logger.debug("CHUNK COMPLETED: Processed #{length(chunk)} items in #{elapsed_ms}ms with result: #{inspect(result)}")
      rescue
        e ->
          Logger.error("CHUNK ERROR: #{Exception.message(e)}")
          Logger.error(Exception.format_stacktrace(__STACKTRACE__))
      after
        # Always notify completion regardless of success/failure
        GenServer.cast(CivicForum.Crawlers.ChunkTaskQueue, :task_complete)
      end
    end)
  end
end
