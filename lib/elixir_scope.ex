defmodule ElixirScope do
  @moduledoc """
  ElixirScope - AI-Powered Execution Cinema Debugger

  ElixirScope provides deep observability and "execution cinema" capabilities 
  for Elixir applications. It enables time-travel debugging, comprehensive
  event capture, and AI-powered analysis of concurrent systems.

  ## Features

  - **Total Recall**: Capture complete execution history with minimal overhead
  - **AI-Driven Instrumentation**: Intelligent, automatic code instrumentation
  - **Execution Cinema**: Visual time-travel debugging interface
  - **Multi-Dimensional Analysis**: Correlate events across time, processes, state, and causality
  - **Performance Aware**: <1% overhead in production with smart sampling

  ## Quick Start

      # Start ElixirScope with default configuration
      ElixirScope.start()

      # Configure for development with full tracing
      ElixirScope.start(strategy: :full_trace)

      # Query captured events
      events = ElixirScope.get_events(pid: self(), limit: 100)

      # Stop tracing
      ElixirScope.stop()

  ## Configuration

  ElixirScope can be configured via `config.exs`:

      config :elixir_scope,
        ai: [
          planning: [
            default_strategy: :balanced,
            performance_target: 0.01,
            sampling_rate: 1.0
          ]
        ],
        capture: [
          ring_buffer: [
            size: 1_048_576,
            max_events: 100_000
          ]
        ]

  See `ElixirScope.Config` for all available configuration options.
  """

  require Logger

  @type start_option :: 
    {:strategy, :minimal | :balanced | :full_trace} |
    {:sampling_rate, float()} |
    {:modules, [module()]} |
    {:exclude_modules, [module()]}

  @type event_query :: [
    pid: pid() | :all,
    event_type: atom() | :all,
    since: integer() | DateTime.t(),
    until: integer() | DateTime.t(),
    limit: pos_integer()
  ]

  #############################################################################
  # Public API
  #############################################################################

  @doc """
  Starts ElixirScope with the given options.

  ## Options

  - `:strategy` - Instrumentation strategy (`:minimal`, `:balanced`, `:full_trace`)
  - `:sampling_rate` - Event sampling rate (0.0 to 1.0)
  - `:modules` - Specific modules to instrument (overrides AI planning)
  - `:exclude_modules` - Modules to exclude from instrumentation

  ## Examples

      # Start with default configuration
      ElixirScope.start()

      # Start with full tracing for debugging
      ElixirScope.start(strategy: :full_trace, sampling_rate: 1.0)

      # Start with minimal overhead for production
      ElixirScope.start(strategy: :minimal, sampling_rate: 0.1)

      # Instrument only specific modules
      ElixirScope.start(modules: [MyApp.Worker, MyApp.Server])
  """
  @spec start([start_option()]) :: :ok | {:error, term()}
  def start(opts \\ []) do
    case Application.ensure_all_started(:elixir_scope) do
      {:ok, _} ->
        configure_runtime_options(opts)
        Logger.info("ElixirScope started successfully")
        :ok

      {:error, reason} ->
        Logger.error("Failed to start ElixirScope: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stops ElixirScope and all tracing.

  ## Examples

      ElixirScope.stop()
  """
  @spec stop() :: :ok
  def stop do
    case Application.stop(:elixir_scope) do
      :ok ->
        Logger.info("ElixirScope stopped")
        :ok

      {:error, reason} ->
        Logger.warning("Error stopping ElixirScope: #{inspect(reason)}")
        :ok  # Don't fail, just log the warning
    end
  end

  @doc """
  Gets the current status of ElixirScope.

  Returns a map with information about:
  - Whether ElixirScope is running
  - Current configuration
  - Performance statistics
  - Storage usage

  ## Examples

      status = ElixirScope.status()
      # %{
      #   running: true,
      #   config: %{...},
      #   stats: %{events_captured: 12345, ...},
      #   storage: %{hot_events: 5000, memory_usage: "2.1 MB"}
      # }
  """
  @spec status() :: map()
  def status do
    is_running = running?()
    base_status = %{
      running: is_running,
      timestamp: ElixirScope.Utils.wall_timestamp()
    }

    if is_running do
      base_status
      |> Map.put(:config, get_current_config())
      |> Map.put(:stats, get_performance_stats())
      |> Map.put(:storage, get_storage_stats())
    else
      base_status
    end
  end

  @doc """
  Queries captured events based on the given criteria.

  ## Query Options

  - `:pid` - Filter by process ID (`:all` for all processes)
  - `:event_type` - Filter by event type (`:all` for all types)
  - `:since` - Events since timestamp or DateTime
  - `:until` - Events until timestamp or DateTime  
  - `:limit` - Maximum number of events to return

  ## Examples

      # Get last 100 events for current process
      events = ElixirScope.get_events(pid: self(), limit: 100)

      # Get all function entry events
      events = ElixirScope.get_events(event_type: :function_entry)

      # Get events from the last minute
      since = DateTime.utc_now() |> DateTime.add(-60, :second)
      events = ElixirScope.get_events(since: since)
  """
  @spec get_events(event_query()) :: [ElixirScope.Events.t()] | {:error, term()}
  def get_events(_query \\ []) do
    if running?() do
      # TODO: Implement in Layer 6 when QueryCoordinator is available
      # ElixirScope.Storage.QueryCoordinator.query_events(query)
      {:error, :not_implemented_yet}
    else
      {:error, :not_running}
    end
  end

  @doc """
  Gets the state history for a GenServer process.

  Returns a chronological list of state changes for the given process.

  ## Examples

      # Get state history for a GenServer
      history = ElixirScope.get_state_history(pid)

      # Get state at a specific time
      state = ElixirScope.get_state_at(pid, timestamp)
  """
  @spec get_state_history(pid()) :: [ElixirScope.Events.StateChange.t()] | {:error, term()}
  def get_state_history(pid) when is_pid(pid) do
    if running?() do
      # TODO: Implement in Layer 6 when QueryCoordinator is available
      # ElixirScope.Storage.QueryCoordinator.get_state_history(pid)
      {:error, :not_implemented_yet}
    else
      {:error, :not_running}
    end
  end

  @doc """
  Reconstructs the state of a GenServer at a specific timestamp.

  ## Examples

      timestamp = ElixirScope.Utils.monotonic_timestamp()
      state = ElixirScope.get_state_at(pid, timestamp)
  """
  @spec get_state_at(pid(), integer()) :: term() | {:error, term()}
  def get_state_at(pid, timestamp) when is_pid(pid) and is_integer(timestamp) do
    if running?() do
      # TODO: Implement in Layer 6 when state reconstruction is available
      # ElixirScope.Storage.QueryCoordinator.reconstruct_state_at(pid, timestamp)
      {:error, :not_implemented_yet}
    else
      {:error, :not_running}
    end
  end

  @doc """
  Gets message flow between two processes.

  Returns all messages sent between the specified processes within
  the given time range.

  ## Examples

      # Get all messages between two processes
      messages = ElixirScope.get_message_flow(sender_pid, receiver_pid)

      # Get messages in a time range
      messages = ElixirScope.get_message_flow(
        sender_pid, 
        receiver_pid, 
        since: start_time, 
        until: end_time
      )
  """
  @spec get_message_flow(pid(), pid(), keyword()) :: [ElixirScope.Events.MessageSend.t()] | {:error, term()}
  def get_message_flow(sender_pid, receiver_pid, _opts \\ []) 
      when is_pid(sender_pid) and is_pid(receiver_pid) do
    if running?() do
      # TODO: Implement in Layer 6 when message correlation is available
      # ElixirScope.Storage.QueryCoordinator.get_message_flow(sender_pid, receiver_pid, opts)
      {:error, :not_implemented_yet}
    else
      {:error, :not_running}
    end
  end

  @doc """
  Manually triggers AI analysis of the current codebase.

  This can be useful to refresh instrumentation plans after code changes
  or to analyze new modules.

  ## Examples

      # Analyze entire codebase
      ElixirScope.analyze_codebase()

      # Analyze specific modules
      ElixirScope.analyze_codebase(modules: [MyApp.NewModule])
  """
  @spec analyze_codebase(keyword()) :: :ok | {:error, term()}
  def analyze_codebase(_opts \\ []) do
    if running?() do
      # TODO: Implement in Layer 4 when AI.Orchestrator is available
      # ElixirScope.AI.Orchestrator.analyze_codebase(opts)
      {:error, :not_implemented_yet}
    else
      {:error, :not_running}
    end
  end

  @doc """
  Updates the instrumentation plan at runtime.

  This allows changing which modules and functions are being traced
  without restarting the application.

  ## Examples

      # Change sampling rate
      ElixirScope.update_instrumentation(sampling_rate: 0.5)

      # Add modules to trace
      ElixirScope.update_instrumentation(add_modules: [MyApp.NewModule])

      # Change strategy  
      ElixirScope.update_instrumentation(strategy: :full_trace)
  """
  @spec update_instrumentation(keyword()) :: :ok | {:error, term()}
  def update_instrumentation(_updates) do
    if running?() do
      # TODO: Implement in Layer 4 when AI.Orchestrator is available
      # ElixirScope.AI.Orchestrator.update_instrumentation(updates)
      {:error, :not_implemented_yet}
    else
      {:error, :not_running}
    end
  end

  #############################################################################
  # Convenience Functions
  #############################################################################

  @doc """
  Checks if ElixirScope is currently running.

  ## Examples

      if ElixirScope.running?() do
        # ElixirScope is active
      end
  """
  @spec running?() :: boolean()
  def running? do
    # Check if the application is started by checking both the Application and the supervisor
    case Application.get_application(__MODULE__) do
      nil -> false
      :elixir_scope ->
        # Also check if the main supervisor is running
        case Process.whereis(ElixirScope.Supervisor) do
          nil -> false
          _pid -> true
        end
    end
  end

  @doc """
  Gets the current configuration.

  ## Examples

      config = ElixirScope.get_config()
      sampling_rate = config.ai.planning.sampling_rate
  """
  @spec get_config() :: ElixirScope.Config.t() | {:error, term()}
  def get_config do
    if running?() do
      ElixirScope.Config.get()
    else
      {:error, :not_running}
    end
  end

  @doc """
  Updates configuration at runtime.

  Only certain configuration paths can be updated at runtime for safety.

  ## Examples

      # Update sampling rate
      ElixirScope.update_config([:ai, :planning, :sampling_rate], 0.8)

      # Update query timeout
      ElixirScope.update_config([:interface, :query_timeout], 10_000)
  """
  @spec update_config([atom()], term()) :: :ok | {:error, term()}
  def update_config(path, value) do
    if running?() do
      ElixirScope.Config.update(path, value)
    else
      {:error, :not_running}
    end
  end

  #############################################################################
  # Private Functions
  #############################################################################

  defp configure_runtime_options(opts) do
    # Apply runtime configuration options
    Enum.each(opts, fn {key, value} ->
      case key do
        :strategy ->
          update_config([:ai, :planning, :default_strategy], value)

        :sampling_rate ->
          update_config([:ai, :planning, :sampling_rate], value)

        :modules ->
          # TODO: Set specific modules to instrument
          Logger.info("Module-specific instrumentation will be available in Layer 4")

        :exclude_modules ->
          # TODO: Add to exclusion list
          Logger.info("Module exclusion configuration will be available in Layer 4")

        _ ->
          Logger.warning("Unknown start option: #{key}")
      end
    end)
  end

  defp get_current_config do
    case get_config() do
      {:error, _} -> %{}
      config -> 
        # Return a simplified view of the configuration
        %{
          strategy: config.ai.planning.default_strategy,
          sampling_rate: config.ai.planning.sampling_rate,
          performance_target: config.ai.planning.performance_target,
          ring_buffer_size: config.capture.ring_buffer.size,
          hot_storage_limit: config.storage.hot.max_events
        }
    end
  end

  defp get_performance_stats do
    # TODO: Implement in Layer 1 when capture pipeline is available
    %{
      events_captured: 0,
      events_per_second: 0,
      memory_usage: 0,
      ring_buffer_utilization: 0.0,
      last_updated: ElixirScope.Utils.wall_timestamp()
    }
  end

  defp get_storage_stats do
    # TODO: Implement in Layer 2 when storage is available
    %{
      hot_events: 0,
      warm_events: 0,
      cold_events: 0,
      memory_usage: ElixirScope.Utils.format_bytes(0),
      disk_usage: ElixirScope.Utils.format_bytes(0),
      oldest_event: nil,
      newest_event: nil
    }
  end
end 