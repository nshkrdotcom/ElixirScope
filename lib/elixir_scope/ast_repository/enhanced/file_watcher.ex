defmodule ElixirScope.ASTRepository.Enhanced.FileWatcher do
  @moduledoc """
  Real-time file system watcher for enhanced AST repository.

  Monitors Elixir files for changes and automatically updates the repository:
  - File system event monitoring
  - Debounced change detection
  - Incremental AST analysis
  - Error handling and recovery
  - Performance monitoring
  - Memory management

  Performance targets:
  - Change detection: <10ms latency
  - File processing: <100ms per changed file
  - Memory usage: <50MB for large projects
  - CPU usage: <5% during idle monitoring
  """

  use GenServer
  require Logger
  alias ElixirScope.ASTRepository.EnhancedRepository
  alias ElixirScope.ASTRepository.Enhanced.{ProjectPopulator, Repository, Synchronizer}
  alias ElixirScope.EventStore

  @default_opts [
    watch_patterns: ["**/*.ex", "**/*.exs"],
    ignore_patterns: ["**/deps/**", "**/build/**", "**/_build/**", "**/node_modules/**", "**/.git/**"],
    debounce_ms: 500,
    batch_size: 10,
    max_file_size: 1_000_000,  # 1MB
    enable_incremental: true,
    enable_batching: true,
    enable_debouncing: true,
    auto_start: true
  ]

  defstruct [
    :project_path,
    :watcher_pid,
    :opts,
    :pending_changes,
    :debounce_timer,
    :stats,
    :last_scan_time,
    :subscribers,
    :repository,
    :synchronizer
  ]

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts watching a project directory for changes.
  """
  def watch_project(project_path, opts \\ []) do
    GenServer.call(__MODULE__, {:watch_project, project_path, opts})
  end

  @doc """
  Stops watching the current project.
  """
  def stop_watching() do
    GenServer.call(__MODULE__, :stop_watching)
  end

  @doc """
  Gets current watcher status and statistics.
  """
  def get_status(pid \\ __MODULE__) do
    GenServer.call(pid, :get_status)
  end

  @doc """
  Forces processing of all pending changes.
  """
  def flush_changes() do
    GenServer.call(__MODULE__, :flush_changes)
  end

  @doc """
  Manually triggers a full project rescan.
  """
  def rescan_project() do
    GenServer.call(__MODULE__, :rescan_project)
  end

  @doc """
  Updates watcher configuration.
  """
  def update_config(new_opts) do
    GenServer.call(__MODULE__, {:update_config, new_opts})
  end

  def stop(pid \\ __MODULE__) do
    GenServer.stop(pid)
  end

  def subscribe(pid \\ __MODULE__, subscriber_pid) do
    GenServer.call(pid, {:subscribe, subscriber_pid})
  end

  # GenServer callbacks

  def init(opts) do
    opts = Keyword.merge(@default_opts, opts)

    Logger.debug("FileWatcher: Initializing with opts: #{inspect(opts)}")

    state = %__MODULE__{
      project_path: nil,
      watcher_pid: nil,
      opts: opts,
      pending_changes: %{},
      debounce_timer: nil,
      stats: init_stats(),
      last_scan_time: nil,
      subscribers: [],
      repository: Keyword.get(opts, :repository),
      synchronizer: Keyword.get(opts, :synchronizer)
    }

    Logger.debug("FileWatcher: State initialized - repository: #{inspect(state.repository)}, synchronizer: #{inspect(state.synchronizer)}")

    # If watch_dirs is provided, start watching immediately
    case Keyword.get(opts, :watch_dirs) do
      nil ->
        Logger.info("File Watcher initialized")
        {:ok, state}

      [dir | _] = watch_dirs ->
        Logger.debug("FileWatcher: Starting to watch directories: #{inspect(watch_dirs)}")
        # Validate directories exist
        invalid_dirs = Enum.reject(watch_dirs, fn dir ->
          File.exists?(dir) and File.dir?(dir)
        end)

        if length(invalid_dirs) > 0 do
          Logger.error("FileWatcher: Invalid directories found: #{inspect(invalid_dirs)}")
          {:error, :directory_not_found}
        else
          # Start watching the first directory (for simplicity)
          case start_file_watcher(dir, opts) do
            {:ok, watcher_pid} ->
              Logger.info("File Watcher initialized and watching: #{dir}")
              new_state = %{state |
                project_path: dir,
                watcher_pid: watcher_pid
              }
              Logger.debug("FileWatcher: Successfully started watching with watcher_pid: #{inspect(watcher_pid)}")
              {:ok, new_state}

            {:error, reason} ->
              Logger.error("FileWatcher: Failed to start watching: #{inspect(reason)}")
              {:error, reason}
          end
        end

      [] ->
        Logger.info("File Watcher initialized")
        {:ok, state}
    end
  end

  def handle_call({:watch_project, project_path, opts}, _from, state) do
    # Validate directory exists
    unless File.exists?(project_path) and File.dir?(project_path) do
      {:reply, {:error, :directory_not_found}, state}
    else
      new_opts = Keyword.merge(state.opts, opts)

      # Stop existing watcher if running
      state = stop_current_watcher(state)

      case start_file_watcher(project_path, new_opts) do
        {:ok, watcher_pid} ->
          Logger.info("Started watching project: #{project_path}")

          # Perform initial scan if requested
          if Keyword.get(new_opts, :initial_scan, true) do
            spawn(fn -> perform_initial_scan(project_path, new_opts) end)
          end

          new_state = %{state |
            project_path: project_path,
            watcher_pid: watcher_pid,
            opts: new_opts,
            pending_changes: %{},
            last_scan_time: DateTime.utc_now()
          }

          {:reply, :ok, new_state}

        {:error, reason} ->
          Logger.error("Failed to start file watcher: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  def handle_call(:stop_watching, _from, state) do
    new_state = stop_current_watcher(state)
    Logger.info("Stopped watching project")
    {:reply, :ok, new_state}
  end

  def handle_call(:get_status, _from, state) do
    status = %{
      status: if(state.watcher_pid, do: :watching, else: :stopped),
      project_path: state.project_path,
      pending_changes: map_size(state.pending_changes),
      changes_processed: state.stats.changes_processed,
      file_changes_detected: state.stats.file_changes_detected,
      last_scan_time: state.last_scan_time
    }
    {:reply, {:ok, status}, state}
  end

  def handle_call(:flush_changes, _from, state) do
    if map_size(state.pending_changes) > 0 do
      Logger.debug("Flushing #{map_size(state.pending_changes)} pending changes")
      new_state = process_pending_changes(state)
      {:reply, :ok, new_state}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call(:rescan_project, _from, state) do
    if state.project_path do
      Logger.info("Starting full project rescan")
      spawn(fn -> perform_full_rescan(state.project_path, state.opts) end)

      new_state = %{state | last_scan_time: DateTime.utc_now()}
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_watching}, state}
    end
  end

  def handle_call({:update_config, new_opts}, _from, state) do
    updated_opts = Keyword.merge(state.opts, new_opts)
    new_state = %{state | opts: updated_opts}

    Logger.debug("Updated file watcher configuration")
    {:reply, :ok, new_state}
  end

  def handle_call({:subscribe, subscriber_pid}, _from, state) do
    Logger.debug("FileWatcher adding subscriber: #{inspect(subscriber_pid)}")
    new_subscribers = [subscriber_pid | state.subscribers]
    Logger.debug("FileWatcher now has #{length(new_subscribers)} subscribers: #{inspect(new_subscribers)}")
    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end

  # Handle FileSystem events - the actual format from the FileSystem library
  def handle_info({:file_event, watcher_pid, {path, events}}, %{watcher_pid: watcher_pid} = state) do
    Logger.debug("FileWatcher: Received file event - path: #{path}, events: #{inspect(events)}")
    if should_process_file?(path, events, state.opts) do
      Logger.debug("FileWatcher: Processing file event for: #{path}")
      new_state = handle_file_change(path, events, state)
      # Notify subscribers
      event_type = List.first(events)
      file_extension = Path.extname(path)
      notification = {:file_event, %{type: event_type, path: path, extension: file_extension}}
      Logger.debug("FileWatcher: Notifying #{length(state.subscribers)} subscribers with: #{inspect(notification)}")
      notify_subscribers(state.subscribers, notification)
      {:noreply, new_state}
    else
      Logger.debug("FileWatcher: Ignoring file event for: #{path} (filtered out)")
      {:noreply, state}
    end
  end

  # Handle FileSystem events in alternative format
  def handle_info({:file_event, watcher_pid, path, events}, %{watcher_pid: watcher_pid} = state) do
    Logger.debug("FileWatcher: Received file event (alt format) - path: #{path}, events: #{inspect(events)}")
    if should_process_file?(path, events, state.opts) do
      Logger.debug("FileWatcher: Processing file event (alt format) for: #{path}")
      new_state = handle_file_change(path, events, state)
      # Notify subscribers
      notify_subscribers(state.subscribers, {:file_event, %{type: List.first(events), path: path, extension: Path.extname(path)}})
      {:noreply, new_state}
    else
      Logger.debug("FileWatcher: Ignoring file event (alt format) for: #{path} (filtered out)")
      {:noreply, state}
    end
  end

  def handle_info({:file_event, _other_watcher_pid, _event}, state) do
    # Ignore events from old watchers
    {:noreply, state}
  end

  def handle_info({:file_event, _other_watcher_pid, _path, _events}, state) do
    # Ignore events from old watchers
    {:noreply, state}
  end

  def handle_info(:process_debounced_changes, state) do
    new_state = %{state | debounce_timer: nil}
    |> process_pending_changes()

    {:noreply, new_state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{watcher_pid: pid} = state) do
    Logger.warning("File watcher process died: #{inspect(reason)}")

    # Attempt to restart watcher
    if state.project_path do
      case start_file_watcher(state.project_path, state.opts) do
        {:ok, new_watcher_pid} ->
          Logger.info("Restarted file watcher")
          new_state = %{state | watcher_pid: new_watcher_pid}
          {:noreply, new_state}

        {:error, restart_reason} ->
          Logger.error("Failed to restart file watcher: #{inspect(restart_reason)}")
          new_state = %{state | watcher_pid: nil}
          {:noreply, new_state}
      end
    else
      new_state = %{state | watcher_pid: nil}
      {:noreply, new_state}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private implementation functions

  defp start_file_watcher(project_path, _opts) do
    try do
      # Use FileSystem library for cross-platform file watching
      case FileSystem.start_link(dirs: [project_path]) do
        {:ok, pid} ->
          # Subscribe to file events
          FileSystem.subscribe(pid)

          # Monitor the watcher process
          Process.monitor(pid)

          {:ok, pid}

        error ->
          error
      end
    rescue
      e ->
        IO.puts("DEBUG: FileWatcher exception during start: #{Exception.message(e)}")
        {:error, {:watcher_start_failed, Exception.message(e)}}
    end
  end

  defp stop_current_watcher(state) do
    if state.watcher_pid do
      try do
        FileSystem.stop(state.watcher_pid)
      catch
        :exit, _ -> :ok
      end
    end

    # Cancel debounce timer
    if state.debounce_timer do
      Process.cancel_timer(state.debounce_timer)
    end

    %{state |
      watcher_pid: nil,
      debounce_timer: nil,
      pending_changes: %{}
    }
  end

  defp should_process_file?(path, events, opts) do
    # Check file extension
    elixir_file? = String.ends_with?(path, [".ex", ".exs"])

    # Check ignore patterns
    ignored? = Enum.any?(Keyword.get(opts, :ignore_patterns, []), fn pattern ->
      String.contains?(path, pattern)
    end)

    # Check custom file filter if provided
    custom_filter_ok? = case Keyword.get(opts, :file_filter) do
      nil -> true  # No custom filter, allow all
      filter_fn when is_function(filter_fn, 1) -> filter_fn.(path)
      _ -> true  # Invalid filter, allow all
    end

    # Check file size (skip for deletion events since file may not exist)
    size_ok? = if :deleted in events do
      true  # Skip size check for deleted files
    else
      case File.stat(path) do
        {:ok, %{size: size}} -> size <= Keyword.get(opts, :max_file_size, 1_000_000)
        _ -> false
      end
    end

    # Check event types - include :deleted events
    relevant_event? = Enum.any?(events, fn event ->
      event in [:created, :modified, :renamed, :deleted]
    end)

    elixir_file? and not ignored? and size_ok? and relevant_event? and custom_filter_ok?
  end

  defp handle_file_change(path, events, state) do
    Logger.debug("File change detected: #{path} - #{inspect(events)}")

    # Update stats
    new_stats = update_stats(state.stats, :file_change_detected)

    # Add to pending changes
    change_info = %{
      path: path,
      events: events,
      timestamp: DateTime.utc_now(),
      attempts: 0
    }

    new_pending = Map.put(state.pending_changes, path, change_info)

    new_state = %{state |
      pending_changes: new_pending,
      stats: new_stats
    }

    # Handle debouncing
    if Keyword.get(state.opts, :enable_debouncing, true) do
      schedule_debounced_processing(new_state)
    else
      process_pending_changes(new_state)
    end
  end

  defp schedule_debounced_processing(state) do
    # Cancel existing timer
    if state.debounce_timer do
      Process.cancel_timer(state.debounce_timer)
    end

    # Schedule new timer
    debounce_ms = Keyword.get(state.opts, :debounce_ms, 500)
    timer_ref = Process.send_after(self(), :process_debounced_changes, debounce_ms)

    %{state | debounce_timer: timer_ref}
  end

  defp process_pending_changes(state) do
    if map_size(state.pending_changes) == 0 do
      state
    else
      Logger.debug("Processing #{map_size(state.pending_changes)} pending changes")

      start_time = System.monotonic_time(:microsecond)

      # Group changes by type for efficient processing
      {successful, failed} = if Keyword.get(state.opts, :enable_batching, true) do
        process_changes_in_batches(state.pending_changes, state)
      else
        process_changes_individually(state.pending_changes, state)
      end

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      # Update stats
      new_stats = state.stats
      |> update_stats(:changes_processed, length(successful))
      |> update_stats(:changes_failed, length(failed))
      |> update_stats(:processing_time, duration)

      # Log results
      if length(failed) > 0 do
        Logger.warning("Failed to process #{length(failed)} file changes")
        Enum.each(failed, fn {path, reason} ->
          Logger.debug("Failed to process #{path}: #{inspect(reason)}")
        end)
      end

      # Store processing event
      EventStore.store_event(:file_watcher, :changes_processed, %{
        successful_count: length(successful),
        failed_count: length(failed),
        duration_microseconds: duration,
        timestamp: DateTime.utc_now()
      })

      # Keep failed changes for retry (with attempt limit)
      retry_changes = failed
      |> Enum.filter(fn {_path, _reason} -> true end)  # Could add retry logic here
      |> Enum.into(%{}, fn {path, _reason} ->
        change_info = state.pending_changes[path]
        updated_info = %{change_info | attempts: change_info.attempts + 1}
        {path, updated_info}
      end)

      %{state |
        pending_changes: retry_changes,
        stats: new_stats
      }
    end
  end

  defp process_changes_in_batches(pending_changes, state) do
    batch_size = Keyword.get(state.opts, :batch_size, 10)

    pending_changes
    |> Map.to_list()
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce({[], []}, fn batch, {successful_acc, failed_acc} ->
      {batch_successful, batch_failed} = process_change_batch(batch, state)
      {successful_acc ++ batch_successful, failed_acc ++ batch_failed}
    end)
  end

  defp process_changes_individually(pending_changes, state) do
    pending_changes
    |> Map.to_list()
    |> Enum.reduce({[], []}, fn {path, change_info}, {successful, failed} ->
      case process_single_file_change(path, change_info, state) do
        :ok -> {[path | successful], failed}
        {:error, reason} -> {successful, [{path, reason} | failed]}
      end
    end)
  end

  defp process_change_batch(batch, state) do
    # Process a batch of file changes
    batch
    |> Enum.reduce({[], []}, fn {path, change_info}, {successful, failed} ->
      case process_single_file_change(path, change_info, state) do
        :ok -> {[path | successful], failed}
        {:error, reason} -> {successful, [{path, reason} | failed]}
      end
    end)
  end

  defp process_single_file_change(path, change_info, state) do
    try do
      cond do
        :deleted in change_info.events ->
          # Handle file deletion
          handle_file_deletion(path, state)

        :created in change_info.events or :modified in change_info.events ->
          # Handle file creation or modification
          handle_file_modification(path, state)

        :renamed in change_info.events ->
          # Handle file rename (treat as delete + create)
          handle_file_modification(path, state)

        true ->
          {:error, :unknown_event_type}
      end
    rescue
      e ->
        {:error, {:processing_crashed, Exception.message(e)}}
    end
  end

  defp handle_file_deletion(path, state) do
    # Use synchronizer if available, otherwise fall back to direct repository access
    if state.synchronizer do
      Logger.debug("FileWatcher: Using synchronizer to handle file deletion: #{path}")
      case Synchronizer.sync_file_deletion(state.synchronizer, path) do
        :ok ->
          Logger.debug("FileWatcher: Successfully synchronized file deletion via synchronizer: #{path}")
          :ok

        {:error, reason} ->
          Logger.error("FileWatcher: Synchronizer failed for file deletion #{path}: #{inspect(reason)}")
          {:error, {:synchronizer_failed, reason}}
      end
    else
      # Fallback to direct repository access (original implementation)
      Logger.debug("FileWatcher: No synchronizer configured, using direct repository access")
      handle_file_deletion_direct(path, state)
    end
  end

  defp handle_file_deletion_direct(path, state) do
    # Extract module name from file path
    case extract_module_name_from_path(path) do
      {:ok, module_name} ->
        # Remove from repository if available
        if state.repository do
          case Repository.get_module(state.repository, module_name) do
            {:ok, _module_data} ->
              case Repository.delete_module(state.repository, module_name) do
                :ok ->
                  Logger.debug("Deleted module #{module_name} from repository")
                  :ok

                {:error, reason} ->
                  {:error, {:deletion_failed, reason}}
              end

            {:error, :not_found} ->
              # Module not in repository, nothing to do
              :ok
          end
        else
          Logger.debug("No repository configured, skipping deletion")
          :ok
        end

      {:error, _reason} ->
        # Could not determine module name, skip
        :ok
    end
  end

  defp handle_file_modification(path, state) do
    # Use synchronizer if available, otherwise fall back to direct repository access
    if state.synchronizer do
      Logger.debug("FileWatcher: Using synchronizer to handle file modification: #{path}")
      case Synchronizer.sync_file(state.synchronizer, path) do
        :ok ->
          Logger.debug("FileWatcher: Successfully synchronized file via synchronizer: #{path}")
          :ok

        {:error, reason} ->
          Logger.error("FileWatcher: Synchronizer failed for file #{path}: #{inspect(reason)}")
          {:error, {:synchronizer_failed, reason}}
      end
    else
      Logger.debug("FileWatcher: No synchronizer configured, using direct repository access")
      # Fallback to direct repository access (original implementation)
      Logger.debug("FileWatcher: No synchronizer configured, using direct repository access")
      handle_file_modification_direct(path, state)
    end
  end

  defp handle_file_modification_direct(path, state) do
    # Parse and analyze the modified file
    case File.read(path) do
      {:ok, content} ->
        case Code.string_to_quoted(content, file: path) do
          {:ok, ast} ->
            case extract_module_name_from_ast(ast) do
              {:ok, module_name} ->
                # Use ProjectPopulator to create enhanced module data
                case ProjectPopulator.parse_and_analyze_file(path) do
                  {:ok, module_data} ->
                    # Store in repository if available
                    if state.repository do
                      case Repository.store_module(state.repository, module_data) do
                        :ok ->
                          # Store functions
                          Enum.each(module_data.functions, fn {_key, function_data} ->
                            Repository.store_function(state.repository, function_data)
                          end)
                          Logger.debug("Updated module #{module_name} in repository")
                          :ok

                        {:error, reason} ->
                          {:error, {:storage_failed, reason}}
                      end
                    else
                      Logger.debug("No repository configured, skipping storage")
                      :ok
                    end

                  {:error, reason} ->
                    {:error, {:analysis_failed, reason}}
                end

              {:error, reason} ->
                {:error, {:module_extraction_failed, reason}}
            end

          {:error, reason} ->
            {:error, {:ast_parsing_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:file_read_failed, reason}}
    end
  end

  defp perform_initial_scan(project_path, opts) do
    Logger.info("Performing initial project scan")

    case ProjectPopulator.populate_project(project_path, opts) do
      {:ok, results} ->
        Logger.info("Initial scan completed: #{results.files_discovered} files, #{map_size(results.modules)} modules")

        EventStore.store_event(:file_watcher, :initial_scan_completed, %{
          project_path: project_path,
          files_discovered: results.files_discovered,
          modules_analyzed: map_size(results.modules),
          duration_microseconds: results.duration_microseconds,
          timestamp: DateTime.utc_now()
        })

      {:error, reason} ->
        Logger.error("Initial scan failed: #{inspect(reason)}")

        EventStore.store_event(:file_watcher, :initial_scan_failed, %{
          project_path: project_path,
          reason: reason,
          timestamp: DateTime.utc_now()
        })
    end
  end

  defp perform_full_rescan(project_path, opts) do
    Logger.info("Performing full project rescan")

    # Clear repository first
    EnhancedRepository.clear_repository()

    # Perform fresh population
    perform_initial_scan(project_path, opts)
  end

  # Utility functions

  defp extract_module_name_from_path(path) do
    # Extract module name from file path
    # This is a simplified implementation
    case Path.basename(path, ".ex") do
      basename when basename != "" ->
        module_name = basename
        |> String.split("_")
        |> Enum.map(&String.capitalize/1)
        |> Enum.join("")
        |> String.to_atom()

        {:ok, module_name}

      _ ->
        {:error, :invalid_path}
    end
  end

  defp extract_module_name_from_ast(ast) do
    case ast do
      {:defmodule, _, [module_alias, _body]} ->
        case module_alias do
          {:__aliases__, _, parts} -> {:ok, Module.concat(parts)}
          atom when is_atom(atom) -> {:ok, atom}
          _ -> {:error, :invalid_module_alias}
        end
      _ -> {:error, :no_module_found}
    end
  end

  defp init_stats() do
    %{
      file_changes_detected: 0,
      changes_processed: 0,
      changes_failed: 0,
      total_processing_time: 0,
      average_processing_time: 0.0,
      start_time: DateTime.utc_now()
    }
  end

  defp update_stats(stats, :file_change_detected) do
    %{stats | file_changes_detected: stats.file_changes_detected + 1}
  end

  defp update_stats(stats, :changes_processed, count) do
    %{stats | changes_processed: stats.changes_processed + count}
  end

  defp update_stats(stats, :changes_failed, count) do
    %{stats | changes_failed: stats.changes_failed + count}
  end

  defp update_stats(stats, :processing_time, duration) do
    new_total = stats.total_processing_time + duration
    new_count = stats.changes_processed + 1
    new_average = if new_count > 0, do: new_total / new_count, else: 0.0

    %{stats |
      total_processing_time: new_total,
      average_processing_time: new_average
    }
  end

  defp calculate_uptime() do
    # Calculate uptime in seconds
    System.monotonic_time(:second)
  end

  defp get_memory_usage() do
    # Get current process memory usage in MB
    case :erlang.process_info(self(), :memory) do
      {:memory, memory_bytes} when is_integer(memory_bytes) ->
        Float.round(memory_bytes / (1024 * 1024), 2)
      _ ->
        0.0
    end
  end

  defp calculate_memory_usage(_state) do
    # Calculate memory usage based on current state
    # This is a placeholder implementation. You might want to implement a more accurate memory usage calculation
    get_memory_usage()
  end

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn subscriber_pid ->
      if Process.alive?(subscriber_pid) do
        send(subscriber_pid, message)
      end
    end)
  end
end
