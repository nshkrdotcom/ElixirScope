defmodule ElixirScope.ASTRepository.FileWatcher do
  @moduledoc """
  Monitors project directories for file changes (.ex, .exs files) and
  triggers updates to the AST Repository via a callback or by notifying
  the Synchronizer.

  Uses a file system watching library (like `FileSystem` or `fs`)
  and debounces events to handle rapid changes efficiently.
  """
  use GenServer

  require Logger

  alias ElixirScope.ASTRepository.Synchronizer # To notify about changes

  # Default configuration
  @default_debounce_ms 500
  @default_ignore_patterns ElixirScope.ASTRepository.ProjectPopulator.default_ignore_patterns() # Reuse defaults
  @default_file_patterns ElixirScope.ASTRepository.ProjectPopulator.default_file_patterns() # Reuse defaults

  # --- Client API ---

  @doc """
  Starts the FileWatcher GenServer.
  """
  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    # opts can include:
    # :project_path (required) - Root path of the project to watch
    # :name - GenServer name (default: __MODULE__)
    # :debounce_ms - Debounce interval (default: @default_debounce_ms)
    # :ignore_patterns - List of glob patterns to ignore
    # :file_patterns - List of glob patterns for Elixir files to watch
    # :callback - MFA or fun/1 to call with a list of `FileChangeEvent` structs
    #             (default: notify Synchronizer)
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "Adds a directory to the watch list (if not already covered by project_path)."
  def watch_directory(server \\ __MODULE__, directory_path) do
    GenServer.call(server, {:watch_directory, directory_path})
  end

  @doc "Removes a directory from the watch list."
  def unwatch_directory(server \\ __MODULE__, directory_path) do
    GenServer.call(server, {:unwatch_directory, directory_path})
  end

  @doc "Temporarily pauses file watching."
  def pause(server \\ __MODULE__) do
    GenServer.cast(server, :pause)
  end

  @doc "Resumes file watching after a pause."
  def resume(server \\ __MODULE__) do
    GenServer.cast(server, :resume)
  end

  @doc "Gets the current status of the watcher."
  def status(server \\ __MODULE__) do
    GenServer.call(server, :status)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    project_path = Keyword.fetch!(opts, :project_path)
    debounce_ms = Keyword.get(opts, :debounce_ms, @default_debounce_ms)
    ignore_patterns = Keyword.get(opts, :ignore_patterns, @default_ignore_patterns)
    file_patterns = Keyword.get(opts, :file_patterns, @default_file_patterns) # For precise targeting if needed beyond .ex/.exs
    callback = Keyword.get(opts, :callback, {Synchronizer, :sync_changes_batch, []}) # Default to Synchronizer

    # Initialize file system watcher library
    # Using :fs as an example, as FileSystem from hex can be problematic with OTP upgrades sometimes
    # Or stick with FileSystem if preferred.
    # For :fs: {:ok, watcher_pid} = :fs.start_link(:my_watcher_supervisor_child_id, project_path)
    # For FileSystem: {:ok, watcher_pid} = FileSystem.start_link(dirs: [project_path])
    # FileSystem.subscribe(watcher_pid)

    # For this example, let's conceptualize using `:fs` which is OTP standard.
    # A real implementation would need a supervisor for :fs process.
    # We'll simulate its events for now.
    # Actual :fs setup is more involved.

    Logger.info("FileWatcher starting for project: #{project_path}")

    state = %{
      project_path: Path.expand(project_path),
      watcher_pid: nil, # Placeholder for actual watcher PID
      debounce_ms: debounce_ms,
      ignore_patterns: ignore_patterns,
      file_patterns: file_patterns,
      callback: callback,
      paused: false,
      # For debouncing: {file_path, event_type} => last_seen_timestamp
      pending_changes: %{},
      debounce_timer_ref: nil
    }
    # Start the actual file system watcher here if using a library like FileSystem or fs_watch.
    # For :fs, you'd use :fs.subscribe(path) and handle :fs_event messages.
    # For FileSystem, you'd subscribe to the started FileSystem process.
    # Let's assume a library that sends {:file_event, pid, {path, events}}
    # Example using FileSystem:
    case FileSystem.start_link(dirs: [state.project_path], name: :"#{__MODULE__}.FS") do
      {:ok, fs_pid} ->
        FileSystem.subscribe(fs_pid)
        {:ok, %{state | watcher_pid: fs_pid}}
      {:error, reason} ->
        Logger.error("Failed to start FileSystem watcher: #{inspect(reason)}")
        {:stop, {:failed_to_start_fs_watcher, reason}}
    end
  end

  @impl true
  def handle_call({:watch_directory, directory_path}, _from, state) do
    # Logic to add a new directory to the underlying watcher if supported,
    # or manage multiple watcher PIDs.
    # For FileSystem, it watches subdirectories by default.
    Logger.info("Received request to watch additional directory (not yet fully supported): #{directory_path}")
    {:reply, :ok, state} # Simplified
  end

  @impl true
  def handle_call({:unwatch_directory, directory_path}, _from, state) do
    Logger.info("Received request to unwatch directory (not yet fully supported): #{directory_path}")
    {:reply, :ok, state} # Simplified
  end

  @impl true
  def handle_call(:status, _from, state) do
    status_info = %{
      project_path: state.project_path,
      paused: state.paused,
      pending_changes_count: map_size(state.pending_changes),
      debouncing: not is_nil(state.debounce_timer_ref)
    }
    {:reply, {:ok, status_info}, state}
  end

  @impl true
  def handle_cast(:pause, state) do
    Logger.info("FileWatcher paused.")
    # If using FileSystem, could unsubscribe temporarily, or just ignore events.
    {:noreply, %{state | paused: true}}
  end

  @impl true
  def handle_cast(:resume, state) do
    Logger.info("FileWatcher resumed.")
    # If unsubscribed, resubscribe.
    {:noreply, %{state | paused: false, debounce_timer_ref: maybe_schedule_debounce_flush(state.pending_changes, state)}}
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    if state.paused do
      {:noreply, state}
    else
      normalized_path = Path.expand(path)
      if should_process_path?(normalized_path, state) do
        Logger.debug("FileWatcher event: #{inspect({normalized_path, events})}")
        # Determine event type: :created, :modified, :deleted, :renamed
        # FileSystem events are like [:closed, :modified, :created, :deleted, :moved_to, :moved_from]
        # We need to map these to our FileChangeEvent types
        process_raw_events(normalized_path, events, state)
      else
        {:noreply, state} # Ignored path
      end
    end
  end

  @impl true
  def handle_info(:flush_debounced_changes, state) do
    changes_to_process = state.pending_changes
    new_state = %{state | pending_changes: %{}, debounce_timer_ref: nil}

    unless map_size(changes_to_process) == 0 do
      Logger.debug("Flushing #{map_size(changes_to_process)} debounced file changes.")
      # Convert pending_changes map to a list of FileChangeEvent structs
      file_change_events = Enum.map(changes_to_process, fn {{path, type}, _ts} ->
        %ElixirScope.ASTRepository.FileChangeEvent{ # Assuming this struct exists
          file_path: path,
          event_type: type, # :created, :modified, :deleted
          timestamp: DateTime.utc_now(),
          # file_hash might be calculated by Synchronizer or here if :modified
        }
      end)

      # Invoke callback
      case state.callback do
        {module, fun, prepended_args} ->
          apply(module, fun, prepended_args ++ [file_change_events])
        fun when is_function(fun, 1) ->
          fun.(file_change_events)
        _ ->
          Logger.error("Invalid FileWatcher callback: #{inspect(state.callback)}")
      end
    end
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do # Catch-all for other messages
    Logger.warn("FileWatcher received unknown message: #{inspect(_msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("FileWatcher terminating. Reason: #{inspect(reason)}")
    if fs_pid = state.watcher_pid, do: FileSystem.stop(fs_pid) # Clean up FileSystem process
    :ok
  end

  # --- Internal Helpers ---

  defp should_process_path?(absolute_path, state) do
    # 1. Must be within the project_path (redundant if watcher is scoped, but good check)
    # 2. Must match one of the file_patterns (e.g., *.ex, *.exs)
    # 3. Must NOT match any of the ignore_patterns

    is_elixir_file = Enum.any?(state.file_patterns, fn pattern ->
      # Simplified: check extension. A real glob match on basename might be better for `file_patterns`.
      String.ends_with?(absolute_path, ".ex") or String.ends_with?(absolute_path, ".exs")
    end)

    is_ignored = Enum.any?(state.ignore_patterns, fn pattern ->
      # Use the project populator's helper or a similar robust glob matcher
      ElixirScope.ASTRepository.ProjectPopulator.matches_ignore_pattern?(absolute_path, Path.join(state.project_path, pattern))
    end)

    # Path.expand might be needed for ignore_patterns if they are relative
    # String.starts_with?(absolute_path, state.project_path) && is_elixir_file && not is_ignored
    is_elixir_file && not is_ignored # Assuming watcher is already scoped to project_path
  end

  defp process_raw_events(path, raw_events, state) do
    # Determine the most significant event type for our system.
    # E.g., if [:created, :modified, :closed] occurs, it's effectively a :modified or :created.
    # FileSystem event order can be tricky.
    # :moved_to implies created at new path. :moved_from implies deleted at old path.
    # :deleted means deleted.
    # :modified or :closed after :created often means new file written.
    # :modified or :closed on existing file means modified.

    event_type = determine_final_event_type(raw_events)

    if event_type in [:created, :modified, :deleted] do # Add :renamed later
      updated_pending = Map.put(state.pending_changes, {path, event_type}, System.monotonic_time())
      new_timer_ref = maybe_schedule_debounce_flush(updated_pending, state)
      {:noreply, %{state | pending_changes: updated_pending, debounce_timer_ref: new_timer_ref}}
    else
      {:noreply, state} # No significant event type determined
    end
  end

  defp determine_final_event_type(raw_events) do
    # This logic needs to be robust based on the chosen FS library's event semantics.
    # Example simplification:
    cond do
      :deleted in raw_events -> :deleted
      :moved_to in raw_events -> :created # Treat new location as created
      :moved_from in raw_events -> :deleted # Treat old location as deleted (separate event for this path)
      :created in raw_events -> :created
      :modified in raw_events -> :modified
      # :closed might also indicate modification complete
      Enum.any?(raw_events, &(&1 in [:modified, :closed, :attrib])) -> :modified # if not created/deleted
      true -> nil # No relevant event
    end
  end

  defp maybe_schedule_debounce_flush(pending_changes, state) do
    if state.debounce_timer_ref do # Timer already active
      state.debounce_timer_ref
    else
      if map_size(pending_changes) > 0 do
        Process.send_after(self(), :flush_debounced_changes, state.debounce_ms)
      else
        nil # No pending changes, no timer needed
      end
    end
  end

end

# Define FileChangeEvent struct if not already globally available
# defmodule ElixirScope.ASTRepository.FileChangeEvent do
#   defstruct [:file_path, :event_type, :old_path, :timestamp, :file_hash, :modules_affected, :functions_changed, :status, :error, :metadata]
#   @type t :: %__MODULE__{
#     file_path: String.t(),
#     event_type: :created | :modified | :deleted | :renamed,
#     old_path: String.t() | nil,
#     timestamp: DateTime.t(),
#     file_hash: String.t() | nil,
#     # ... (other fields if populated by FileWatcher itself)
#   }
# end
