defmodule ElixirScope.Runtime.Controller do
  @moduledoc """
  Central GenServer managing all runtime tracing activities.
  
  Coordinates TracerManager and StateMonitorManager, applies runtime plans
  from AI.Orchestrator, and handles API calls from ElixirScope.Runtime.
  """
  
  use GenServer
  require Logger

  # Suppress warnings for future phase dependencies
  @compile {:no_warn_undefined, {ElixirScope.AI.Orchestrator, :get_runtime_tracing_plan, 0}}

  alias ElixirScope.Runtime.{TracerManager, StateMonitorManager}
  alias ElixirScope.AI.Orchestrator
  alias ElixirScope.Utils

  defstruct [
    :global_tracing_enabled,
    :active_traces,
    :runtime_plan,
    :tracer_manager_pid,
    :state_monitor_manager_pid,
    :global_limits,
    :anomaly_monitors,
    :time_travel_sessions
  ]

  @type trace_ref :: reference()
  @type trace_target :: module() | {module(), atom()} | {module(), atom(), arity()} | pid()

  # --- Public API (called by ElixirScope.Runtime) ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_trace(target, opts) do
    GenServer.call(__MODULE__, {:start_trace, target, opts})
  end

  def stop_trace(trace_ref) do
    GenServer.call(__MODULE__, {:stop_trace, trace_ref})
  end

  def list_active_traces() do
    GenServer.call(__MODULE__, :list_active_traces)
  end

  def adjust_trace_parameters(trace_ref, adjustments) do
    GenServer.call(__MODULE__, {:adjust_trace, trace_ref, adjustments})
  end

  def start_anomaly_monitoring(type, opts) do
    GenServer.call(__MODULE__, {:start_anomaly_monitoring, type, opts})
  end

  def start_pattern_trace(pattern, opts) do
    GenServer.call(__MODULE__, {:start_pattern_trace, pattern, opts})
  end

  def enable_time_travel_capture(target, opts) do
    GenServer.call(__MODULE__, {:enable_time_travel, target, opts})
  end

  def set_global_limits(limits) do
    GenServer.call(__MODULE__, {:set_global_limits, limits})
  end

  def emergency_stop_all_tracing() do
    GenServer.call(__MODULE__, :emergency_stop)
  end

  def globally_enabled?() do
    GenServer.call(__MODULE__, :globally_enabled?)
  end

  def set_global_tracing_status(enabled) do
    GenServer.cast(__MODULE__, {:set_global_status, enabled})
  end

  def activate_tracing(initial_plan, startup_opts) do
    GenServer.call(__MODULE__, {:activate_tracing, initial_plan, startup_opts})
  end

  def deactivate_tracing() do
    GenServer.call(__MODULE__, :deactivate_tracing)
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    # Start child managers for tracers and state monitors
    {:ok, tracer_manager_pid} = TracerManager.start_link()
    {:ok, state_monitor_manager_pid} = StateMonitorManager.start_link()

    # Load initial runtime plan from Orchestrator/Config
    initial_plan = case safe_get_runtime_tracing_plan() do
      {:ok, plan} -> plan
      _ -> generate_default_runtime_plan()
    end

    # Set up default global limits
    default_limits = %{
      max_events_per_second: 100_000,
      max_memory_mb: 500,
      max_trace_duration_minutes: 60,
      auto_stop_thresholds: [
        {:cpu_usage, 80},
        {:memory_usage, 90}
      ]
    }

    state = %__MODULE__{
      global_tracing_enabled: Keyword.get(opts, :enabled, true),
      active_traces: %{}, # trace_ref => %{target: ..., options: ..., status: ...}
      runtime_plan: initial_plan,
      tracer_manager_pid: tracer_manager_pid,
      state_monitor_manager_pid: state_monitor_manager_pid,
      global_limits: default_limits,
      anomaly_monitors: %{},
      time_travel_sessions: %{}
    }

    # If global tracing is enabled by default, apply the plan
    if state.global_tracing_enabled do
      apply_runtime_plan(state.runtime_plan, state.tracer_manager_pid)
    end

    Logger.info("ElixirScope Runtime Controller started successfully")
    {:ok, state}
  end

  @impl true
  def handle_call({:start_trace, target, opts}, _from, state) do
    if state.global_tracing_enabled do
      trace_ref = make_ref()
      
      case TracerManager.add_trace(state.tracer_manager_pid, trace_ref, target, opts) do
        :ok ->
          trace_info = %{
            target: target,
            options: opts,
            status: :active,
            started_at: DateTime.utc_now(),
            events_captured: 0
          }
          new_active_traces = Map.put(state.active_traces, trace_ref, trace_info)
          
          Logger.debug("Started trace #{inspect(trace_ref)} for #{inspect(target)}")
          {:reply, {:ok, trace_ref}, %{state | active_traces: new_active_traces}}
          
        {:error, reason} = error ->
          Logger.warning("Failed to start trace for #{inspect(target)}: #{inspect(reason)}")
          {:reply, error, state}
      end
    else
      {:reply, {:error, :tracing_globally_disabled}, state}
    end
  end

  @impl true
  def handle_call({:stop_trace, trace_ref}, _from, state) do
    case Map.get(state.active_traces, trace_ref) do
      nil ->
        {:reply, {:error, :trace_not_found}, state}
        
      _trace_info ->
        case TracerManager.remove_trace(state.tracer_manager_pid, trace_ref) do
          :ok ->
            new_active_traces = Map.delete(state.active_traces, trace_ref)
            Logger.debug("Stopped trace #{inspect(trace_ref)}")
            {:reply, :ok, %{state | active_traces: new_active_traces}}
            
          {:error, reason} = error ->
            Logger.warning("Failed to stop trace #{inspect(trace_ref)}: #{inspect(reason)}")
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call(:list_active_traces, _from, state) do
    trace_list = Enum.map(state.active_traces, fn {ref, info} ->
      Map.put(info, :ref, ref)
    end)
    {:reply, trace_list, state}
  end

  @impl true
  def handle_call({:adjust_trace, trace_ref, adjustments}, _from, state) do
    case Map.get(state.active_traces, trace_ref) do
      nil ->
        {:reply, {:error, :trace_not_found}, state}
        
      trace_info ->
        case TracerManager.adjust_trace(state.tracer_manager_pid, trace_ref, adjustments) do
          :ok ->
            updated_info = Map.update!(trace_info, :options, &Keyword.merge(&1, adjustments))
            new_active_traces = Map.put(state.active_traces, trace_ref, updated_info)
            {:reply, :ok, %{state | active_traces: new_active_traces}}
            
          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:start_anomaly_monitoring, type, opts}, _from, state) do
    monitor_ref = make_ref()
    # Implementation would start anomaly detection process
    # For now, just track the monitor
    new_monitors = Map.put(state.anomaly_monitors, monitor_ref, %{type: type, opts: opts})
    Logger.info("Started anomaly monitoring for #{type}")
    {:reply, {:ok, monitor_ref}, %{state | anomaly_monitors: new_monitors}}
  end

  @impl true
  def handle_call({:start_pattern_trace, pattern, opts}, _from, state) do
    # Pattern tracing would be implemented as a special type of trace
    trace_ref = make_ref()
    enhanced_opts = Keyword.put(opts, :pattern, pattern)
    
    case TracerManager.add_pattern_trace(state.tracer_manager_pid, trace_ref, pattern, enhanced_opts) do
      :ok ->
        trace_info = %{
          target: {:pattern, pattern},
          options: enhanced_opts,
          status: :active,
          started_at: DateTime.utc_now(),
          events_captured: 0
        }
        new_active_traces = Map.put(state.active_traces, trace_ref, trace_info)
        {:reply, {:ok, trace_ref}, %{state | active_traces: new_active_traces}}
        
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:enable_time_travel, target, opts}, _from, state) do
    session_id = Utils.generate_id()
    
    case StateMonitorManager.start_time_travel_session(
      state.state_monitor_manager_pid, 
      session_id, 
      target, 
      opts
    ) do
      :ok ->
        session_info = %{
          target: target,
          options: opts,
          started_at: DateTime.utc_now(),
          snapshots_count: 0
        }
        new_sessions = Map.put(state.time_travel_sessions, session_id, session_info)
        {:reply, {:ok, session_id}, %{state | time_travel_sessions: new_sessions}}
        
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:set_global_limits, limits}, _from, state) do
    new_limits = Map.merge(state.global_limits, Map.new(limits))
    Logger.info("Updated global tracing limits: #{inspect(new_limits)}")
    {:reply, :ok, %{state | global_limits: new_limits}}
  end

  @impl true
  def handle_call(:emergency_stop, _from, state) do
    Logger.warning("Emergency stop initiated - stopping all tracing")
    
    # Stop all tracers
    stopped_traces = map_size(state.active_traces)
    TracerManager.stop_all_traces(state.tracer_manager_pid)
    
    # Stop all state monitors
    StateMonitorManager.stop_all_monitors(state.state_monitor_manager_pid)
    
    # Clear all active traces and sessions
    new_state = %{state | 
      active_traces: %{},
      anomaly_monitors: %{},
      time_travel_sessions: %{},
      global_tracing_enabled: false
    }
    
    {:reply, {:ok, stopped_traces}, new_state}
  end

  @impl true
  def handle_call(:globally_enabled?, _from, state) do
    {:reply, state.global_tracing_enabled, state}
  end

  @impl true
  def handle_call({:activate_tracing, initial_plan, startup_opts}, _from, state) do
    # Apply startup_opts to initial_plan if necessary
    new_plan = merge_opts_into_plan(initial_plan, startup_opts)
    apply_runtime_plan(new_plan, state.tracer_manager_pid)
    apply_state_monitoring_plan(new_plan, state.state_monitor_manager_pid)

    Logger.info("Runtime tracing activated with plan")
    {:reply, :ok, %{state | runtime_plan: new_plan, global_tracing_enabled: true}}
  end

  @impl true
  def handle_call(:deactivate_tracing, _from, state) do
    TracerManager.stop_all_traces(state.tracer_manager_pid)
    StateMonitorManager.stop_all_monitors(state.state_monitor_manager_pid)
    
    Logger.info("Runtime tracing deactivated")
    {:reply, :ok, %{state | global_tracing_enabled: false, active_traces: %{}}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:set_global_status, enabled}, state) do
    new_state = cond do
      enabled && !state.global_tracing_enabled ->
        apply_runtime_plan(state.runtime_plan, state.tracer_manager_pid)
        apply_state_monitoring_plan(state.runtime_plan, state.state_monitor_manager_pid)
        Logger.info("Global tracing enabled")
        %{state | global_tracing_enabled: enabled}
        
      !enabled && state.global_tracing_enabled ->
        TracerManager.stop_all_traces(state.tracer_manager_pid)
        StateMonitorManager.stop_all_monitors(state.state_monitor_manager_pid)
        Logger.info("Global tracing disabled")
        %{state | global_tracing_enabled: enabled}
        
      true ->
        %{state | global_tracing_enabled: enabled}
    end
    
    {:noreply, new_state}
  end

  # Handle plan updates from PubSub if Orchestrator broadcasts them
  @impl true
  def handle_info({:runtime_plan_update, new_plan}, state) do
    Logger.info("Received runtime plan update")
    apply_runtime_plan(new_plan, state.tracer_manager_pid)
    apply_state_monitoring_plan(new_plan, state.state_monitor_manager_pid)
    {:noreply, %{state | runtime_plan: new_plan}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Private Helper Functions ---

  defp safe_get_runtime_tracing_plan() do
    try do
      case Code.ensure_loaded(Orchestrator) do
        {:module, Orchestrator} ->
          if function_exported?(Orchestrator, :get_runtime_tracing_plan, 0) do
            Orchestrator.get_runtime_tracing_plan()
          else
            {:error, :function_not_exported}
          end
        {:error, :nofile} ->
          {:error, :module_not_available}
      end
    rescue
      error ->
        Logger.warning("Failed to get runtime tracing plan from Orchestrator: #{inspect(error)}")
        {:error, :orchestrator_unavailable}
    end
  end

  defp apply_runtime_plan(plan, tracer_manager_pid) do
    # Apply the runtime plan to the tracer manager
    TracerManager.apply_plan(tracer_manager_pid, plan)
  end

  defp apply_state_monitoring_plan(plan, state_monitor_manager_pid) do
    # Apply state monitoring aspects of the plan
    StateMonitorManager.apply_plan(state_monitor_manager_pid, plan)
  end

  defp merge_opts_into_plan(plan, opts) do
    # Logic to merge startup options into the plan
    strategy_opt = Keyword.get(opts, :strategy)
    sampling_opt = Keyword.get(opts, :sampling_rate)

    new_plan = plan
    new_plan = if strategy_opt, do: Map.put(new_plan, :strategy, strategy_opt), else: new_plan
    new_plan = if sampling_opt, do: Map.put(new_plan, :sampling_rate, sampling_opt), else: new_plan
    new_plan
  end

  defp generate_default_runtime_plan() do
    # Generate a minimal, safe default runtime plan
    %{
      global_trace_flags: [:timestamp],
      module_traces: %{},
      pid_traces: %{},
      sampling_rate: 0.1,
      enabled_by_default: false
    }
  end
end 