defmodule ElixirScope.Runtime.StateMonitorManager do
  @moduledoc """
  Manages OTP process state monitoring using :sys.install.
  
  Responsibilities:
  - Start/stop state monitors for OTP processes
  - Apply state monitoring plans from runtime plans
  - Handle monitor failures and restarts
  - Coordinate time-travel state capture sessions
  """
  
  use GenServer
  require Logger

  alias ElixirScope.Runtime.StateMonitor
  alias ElixirScope.Capture.Ingestor

  defstruct [
    :active_monitors,
    :time_travel_sessions,
    :ingestor_buffer,
    :monitor_pool,
    :stats
  ]

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def start_monitor(manager_pid, target_pid, opts) do
    GenServer.call(manager_pid, {:start_monitor, target_pid, opts})
  end

  def stop_monitor(manager_pid, monitor_ref) do
    GenServer.call(manager_pid, {:stop_monitor, monitor_ref})
  end

  def start_time_travel_session(manager_pid, session_id, target, opts) do
    GenServer.call(manager_pid, {:start_time_travel_session, session_id, target, opts})
  end

  def stop_time_travel_session(manager_pid, session_id) do
    GenServer.call(manager_pid, {:stop_time_travel_session, session_id})
  end

  def apply_plan(manager_pid, runtime_plan) do
    GenServer.cast(manager_pid, {:apply_plan, runtime_plan})
  end

  def stop_all_monitors(manager_pid) do
    GenServer.call(manager_pid, :stop_all_monitors)
  end

  def get_monitor_stats(manager_pid) do
    GenServer.call(manager_pid, :get_monitor_stats)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(_opts) do
    # Get the ingestor buffer for forwarding events
    ingestor_buffer = case Ingestor.get_buffer() do
      {:ok, buffer} -> buffer
      _ -> 
        Logger.warning("Could not get Ingestor buffer for StateMonitorManager")
        nil
    end

    state = %__MODULE__{
      active_monitors: %{}, # monitor_ref => %{pid: ..., monitor_pid: ..., opts: ...}
      time_travel_sessions: %{}, # session_id => %{target: ..., monitors: [...], opts: ...}
      ingestor_buffer: ingestor_buffer,
      monitor_pool: [], # Pool of available StateMonitor processes
      stats: %{
        monitors_started: 0,
        monitors_stopped: 0,
        time_travel_sessions: 0,
        state_changes_captured: 0
      }
    }

    Logger.info("StateMonitorManager started")
    {:ok, state}
  end

  @impl true
  def handle_call({:start_monitor, target_pid, opts}, _from, state) do
    case start_state_monitor(target_pid, opts, state) do
      {:ok, monitor_ref, monitor_pid} ->
        monitor_info = %{
          target_pid: target_pid,
          monitor_pid: monitor_pid,
          opts: opts,
          started_at: DateTime.utc_now()
        }
        
        new_active_monitors = Map.put(state.active_monitors, monitor_ref, monitor_info)
        new_stats = Map.update!(state.stats, :monitors_started, &(&1 + 1))
        
        Logger.debug("Started state monitor #{inspect(monitor_ref)} for PID #{inspect(target_pid)}")
        {:reply, {:ok, monitor_ref}, %{state | active_monitors: new_active_monitors, stats: new_stats}}
        
      {:error, reason} = error ->
        Logger.warning("Failed to start state monitor for #{inspect(target_pid)}: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:stop_monitor, monitor_ref}, _from, state) do
    case Map.get(state.active_monitors, monitor_ref) do
      nil ->
        {:reply, {:error, :monitor_not_found}, state}
        
      monitor_info ->
        case StateMonitor.stop_monitoring(monitor_info.monitor_pid) do
          :ok ->
            new_active_monitors = Map.delete(state.active_monitors, monitor_ref)
            new_stats = Map.update!(state.stats, :monitors_stopped, &(&1 + 1))
            
            Logger.debug("Stopped state monitor #{inspect(monitor_ref)}")
            {:reply, :ok, %{state | active_monitors: new_active_monitors, stats: new_stats}}
            
          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:start_time_travel_session, session_id, target, opts}, _from, state) do
    case setup_time_travel_monitoring(session_id, target, opts, state) do
      {:ok, monitor_refs} ->
        session_info = %{
          target: target,
          monitor_refs: monitor_refs,
          opts: opts,
          started_at: DateTime.utc_now(),
          snapshots_captured: 0
        }
        
        new_sessions = Map.put(state.time_travel_sessions, session_id, session_info)
        new_stats = Map.update!(state.stats, :time_travel_sessions, &(&1 + 1))
        
        Logger.info("Started time-travel session #{session_id} for #{inspect(target)}")
        {:reply, :ok, %{state | time_travel_sessions: new_sessions, stats: new_stats}}
        
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:stop_time_travel_session, session_id}, _from, state) do
    case Map.get(state.time_travel_sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}
        
      session_info ->
        # Stop all monitors associated with this session
        Enum.each(session_info.monitor_refs, fn monitor_ref ->
          case Map.get(state.active_monitors, monitor_ref) do
            nil -> :ok
            monitor_info -> StateMonitor.stop_monitoring(monitor_info.monitor_pid)
          end
        end)
        
        # Remove monitors from active list
        new_active_monitors = Enum.reduce(session_info.monitor_refs, state.active_monitors, fn ref, acc ->
          Map.delete(acc, ref)
        end)
        
        new_sessions = Map.delete(state.time_travel_sessions, session_id)
        
        Logger.info("Stopped time-travel session #{session_id}")
        {:reply, :ok, %{state | 
          active_monitors: new_active_monitors,
          time_travel_sessions: new_sessions
        }}
    end
  end

  @impl true
  def handle_call(:stop_all_monitors, _from, state) do
    # Stop all active monitors
    Enum.each(state.active_monitors, fn {_ref, monitor_info} ->
      StateMonitor.stop_monitoring(monitor_info.monitor_pid)
    end)
    
    stopped_count = map_size(state.active_monitors)
    new_stats = Map.update!(state.stats, :monitors_stopped, &(&1 + stopped_count))
    
    Logger.info("Stopped all #{stopped_count} state monitors")
    {:reply, :ok, %{state | 
      active_monitors: %{},
      time_travel_sessions: %{},
      stats: new_stats
    }}
  end

  @impl true
  def handle_call(:get_monitor_stats, _from, state) do
    enhanced_stats = Map.merge(state.stats, %{
      active_monitors_count: map_size(state.active_monitors),
      active_time_travel_sessions: map_size(state.time_travel_sessions)
    })
    {:reply, enhanced_stats, state}
  end

  @impl true
  def handle_cast({:apply_plan, runtime_plan}, state) do
    # Apply state monitoring aspects of the runtime plan
    case apply_state_monitoring_plan(runtime_plan, state) do
      {:ok, new_state} ->
        Logger.info("Applied state monitoring plan")
        {:noreply, new_state}
        
      {:error, reason} ->
        Logger.warning("Failed to apply state monitoring plan: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(unexpected_cast, state) do
    Logger.warning("StateMonitorManager received unexpected cast: #{inspect(unexpected_cast)}")
    {:noreply, state}
  end

  # Handle state change events from StateMonitor processes
  @impl true
  def handle_info({:state_change_captured, monitor_ref, event}, state) do
    # Update stats and potentially forward to time-travel sessions
    new_stats = Map.update!(state.stats, :state_changes_captured, &(&1 + 1))
    
    # Check if this monitor is part of any time-travel sessions
    updated_sessions = update_time_travel_sessions_with_event(state.time_travel_sessions, monitor_ref, event)
    
    {:noreply, %{state | stats: new_stats, time_travel_sessions: updated_sessions}}
  end

  # Handle monitor process exits
  @impl true
  def handle_info({:DOWN, _ref, :process, monitor_pid, reason}, state) do
    Logger.warning("StateMonitor process #{inspect(monitor_pid)} exited: #{inspect(reason)}")
    
    # Find and remove the dead monitor
    {dead_monitor_ref, new_active_monitors} = 
      Enum.reduce(state.active_monitors, {nil, %{}}, fn {ref, info}, {found_ref, acc} ->
        if info.monitor_pid == monitor_pid do
          {ref, acc}
        else
          {found_ref, Map.put(acc, ref, info)}
        end
      end)
    
    if dead_monitor_ref do
      Logger.info("Removed dead state monitor #{inspect(dead_monitor_ref)}")
    end
    
    {:noreply, %{state | active_monitors: new_active_monitors}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Private Helper Functions ---

  defp start_state_monitor(target_pid, opts, state) do
    monitor_opts = [
      target_pid: target_pid,
      ingestor_buffer: state.ingestor_buffer,
      manager_pid: self()
    ] ++ opts
    
    case StateMonitor.start_link(monitor_opts) do
      {:ok, monitor_pid} ->
        # Monitor the StateMonitor process
        Process.monitor(monitor_pid)
        
        monitor_ref = make_ref()
        {:ok, monitor_ref, monitor_pid}
        
      error ->
        error
    end
  end

  defp setup_time_travel_monitoring(session_id, target, opts, state) do
    case target do
      pid when is_pid(pid) ->
        # Monitor a single process
        case start_state_monitor(pid, enhance_opts_for_time_travel(opts, session_id), state) do
          {:ok, monitor_ref, _monitor_pid} -> {:ok, [monitor_ref]}
          error -> error
        end
        
      module when is_atom(module) ->
        # Find all processes running this module and monitor them
        pids = find_processes_by_module(module)
        monitor_refs = Enum.map(pids, fn pid ->
          case start_state_monitor(pid, enhance_opts_for_time_travel(opts, session_id), state) do
            {:ok, monitor_ref, _monitor_pid} -> monitor_ref
            _ -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
        
        {:ok, monitor_refs}
        
      _ ->
        {:error, :invalid_target}
    end
  end

  defp enhance_opts_for_time_travel(opts, session_id) do
    Keyword.merge(opts, [
      time_travel_session: session_id,
      capture_snapshots: true,
      snapshot_interval: Keyword.get(opts, :snapshot_interval, {1, :second})
    ])
  end

  defp find_processes_by_module(module) do
    # Find all processes that are running code from the specified module
    # This is a simplified implementation
    Process.list()
    |> Enum.filter(fn pid ->
      try do
        case Process.info(pid, :current_function) do
          {:current_function, {^module, _function, _arity}} -> true
          _ -> false
        end
      rescue
        _ -> false
      end
    end)
  end

  defp apply_state_monitoring_plan(runtime_plan, state) do
    # Handle nil or invalid runtime plans gracefully
    case runtime_plan do
      nil ->
        Logger.warning("Received nil runtime plan, using empty configuration")
        {:ok, state}
      
      plan when is_map(plan) ->
        # Extract state monitoring configuration from the runtime plan
        module_traces = Map.get(plan, :module_traces, %{})
        apply_valid_plan(module_traces, state)
        
      invalid_plan ->
        Logger.warning("Received invalid runtime plan: #{inspect(invalid_plan)}")
        {:error, :invalid_plan}
    end
  end
  
  defp apply_valid_plan(module_traces, state) when is_map(module_traces) do
    # Start monitors for modules that require OTP monitoring
    new_monitors = Enum.reduce(module_traces, state.active_monitors, fn {module, config}, acc ->
      # Safely get otp_monitoring config
      otp_monitoring = case config do
        config when is_map(config) -> Map.get(config, :otp_monitoring)
        _ -> nil
      end
      
      case otp_monitoring do
        :state_changes ->
          # Start monitoring for this module's processes
          pids = find_processes_by_module(module)
          Enum.reduce(pids, acc, fn pid, inner_acc ->
            case start_state_monitor(pid, [monitoring_level: :state_changes], state) do
              {:ok, monitor_ref, monitor_pid} ->
                monitor_info = %{
                  target_pid: pid,
                  monitor_pid: monitor_pid,
                  opts: [monitoring_level: :state_changes],
                  started_at: DateTime.utc_now()
                }
                Map.put(inner_acc, monitor_ref, monitor_info)
              _ ->
                inner_acc
            end
          end)
          
        _ ->
          acc
      end
    end)
    
    {:ok, %{state | active_monitors: new_monitors}}
  end
  
  defp apply_valid_plan(_invalid_module_traces, state) do
    Logger.warning("Invalid module_traces format, skipping state monitoring setup")
    {:ok, state}
  end

  defp update_time_travel_sessions_with_event(sessions, monitor_ref, _event) do
    # Update time-travel sessions that include this monitor
    Enum.reduce(sessions, sessions, fn {session_id, session_info}, acc ->
      if monitor_ref in session_info.monitor_refs do
        updated_info = Map.update!(session_info, :snapshots_captured, &(&1 + 1))
        Map.put(acc, session_id, updated_info)
      else
        acc
      end
    end)
  end
end 