defmodule ElixirScope.Runtime.StateMonitor do
  @moduledoc """
  Monitor individual OTP process using :sys.install.
  
  Responsibilities:
  - Use :sys.install/3 to attach to OTP processes
  - Implement debug handler functions
  - Capture state changes and snapshots
  - Generate StateChange and StateSnapshot events
  """
  
  use GenServer
  require Logger

  alias ElixirScope.Events
  alias ElixirScope.Capture.Ingestor

  defstruct [
    :target_pid,
    :monitor_ref,
    :ingestor_buffer,
    :manager_pid,
    :monitoring_level,
    :time_travel_session,
    :last_state,
    :snapshot_timer,
    :stats
  ]

  @type monitoring_level :: :state_changes | :full_callbacks | :snapshots_only

  # --- Public API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def stop_monitoring(monitor_pid) do
    GenServer.call(monitor_pid, :stop_monitoring)
  end

  def get_current_state(monitor_pid) do
    GenServer.call(monitor_pid, :get_current_state)
  end

  def capture_snapshot(monitor_pid) do
    GenServer.call(monitor_pid, :capture_snapshot)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    target_pid = Keyword.fetch!(opts, :target_pid)
    ingestor_buffer = Keyword.get(opts, :ingestor_buffer)
    manager_pid = Keyword.get(opts, :manager_pid)
    monitoring_level = Keyword.get(opts, :monitoring_level, :state_changes)
    time_travel_session = Keyword.get(opts, :time_travel_session)

    # Verify the target process is alive and is an OTP process
    case verify_otp_process(target_pid) do
      :ok ->
        # Install debug handler
        case install_debug_handler(target_pid, monitoring_level) do
          {:ok, monitor_ref} ->
            # Set up snapshot timer if needed
            snapshot_timer = setup_snapshot_timer(opts)
            
            state = %__MODULE__{
              target_pid: target_pid,
              monitor_ref: monitor_ref,
              ingestor_buffer: ingestor_buffer,
              manager_pid: manager_pid,
              monitoring_level: monitoring_level,
              time_travel_session: time_travel_session,
              last_state: nil,
              snapshot_timer: snapshot_timer,
              stats: %{
                state_changes_captured: 0,
                snapshots_captured: 0,
                callbacks_monitored: 0
              }
            }

            # Monitor the target process
            Process.monitor(target_pid)
            
            Logger.debug("StateMonitor started for PID #{inspect(target_pid)}")
            {:ok, state}
            
          {:error, reason} ->
            Logger.error("Failed to install debug handler for #{inspect(target_pid)}: #{inspect(reason)}")
            {:stop, reason}
        end
        
      {:error, reason} ->
        Logger.error("Target PID #{inspect(target_pid)} is not a valid OTP process: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:stop_monitoring, _from, state) do
    cleanup_monitoring(state)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_call(:get_current_state, _from, state) do
    current_state = get_process_state(state.target_pid)
    {:reply, {:ok, current_state}, state}
  end

  @impl true
  def handle_call(:capture_snapshot, _from, state) do
    case capture_state_snapshot(state) do
      {:ok, snapshot_event} ->
        new_stats = Map.update!(state.stats, :snapshots_captured, &(&1 + 1))
        {:reply, {:ok, snapshot_event}, %{state | stats: new_stats}}
        
      error ->
        {:reply, error, state}
    end
  end

  # Handle snapshot timer
  @impl true
  def handle_info(:capture_snapshot, state) do
    case capture_state_snapshot(state) do
      {:ok, _snapshot_event} ->
        new_stats = Map.update!(state.stats, :snapshots_captured, &(&1 + 1))
        {:noreply, %{state | stats: new_stats}}
        
      {:error, reason} ->
        Logger.warning("Failed to capture snapshot for #{inspect(state.target_pid)}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  # Handle target process exit
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{target_pid: pid} = state) do
    Logger.info("Target process #{inspect(pid)} exited: #{inspect(reason)}")
    cleanup_monitoring(state)
    {:stop, :normal, state}
  end

  # Handle debug messages from :sys.install
  @impl true
  def handle_info({:debug, pid, event, state_data}, %{target_pid: pid} = monitor_state) do
    case handle_debug_event(event, state_data, monitor_state) do
      {:ok, new_monitor_state} ->
        {:noreply, new_monitor_state}
        
      {:error, reason} ->
        Logger.warning("Error handling debug event: #{inspect(reason)}")
        {:noreply, monitor_state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    cleanup_monitoring(state)
    :ok
  end

  # --- Private Helper Functions ---

  defp verify_otp_process(pid) do
    try do
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} ->
          # Check if it's an OTP process by looking for '$ancestors' or '$initial_call'
          if Keyword.has_key?(dict, :'$ancestors') or Keyword.has_key?(dict, :'$initial_call') do
            :ok
          else
            {:error, :not_otp_process}
          end
          
        nil ->
          {:error, :process_not_alive}
      end
    rescue
      _ ->
        {:error, :process_info_failed}
    end
  end

  defp install_debug_handler(target_pid, monitoring_level) do
    try do
      # Create debug function based on monitoring level
      debug_fun = create_debug_function(monitoring_level)
      
      # Install the debug handler
      case :sys.install(target_pid, {debug_fun, self()}) do
        :ok ->
          monitor_ref = make_ref()
          {:ok, monitor_ref}
          
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, {:exception, error}}
    end
  end

  defp create_debug_function(monitoring_level) do
    case monitoring_level do
      :state_changes ->
        # Only capture state changes
        fn(func_state, event, proc_state) ->
          send(self(), {:debug, self(), event, proc_state})
          func_state
        end
        
      :full_callbacks ->
        # Capture all callback invocations
        fn(func_state, event, proc_state) ->
          send(self(), {:debug, self(), event, proc_state})
          func_state
        end
        
      :snapshots_only ->
        # Minimal monitoring, just for snapshots
        fn(func_state, _event, _proc_state) ->
          func_state
        end
    end
  end

  defp setup_snapshot_timer(opts) do
    case Keyword.get(opts, :snapshot_interval) do
      nil -> nil
      {time, :second} -> 
        :timer.send_interval(time * 1000, :capture_snapshot)
      {time, :minute} -> 
        :timer.send_interval(time * 60 * 1000, :capture_snapshot)
      _ -> nil
    end
  end

  defp handle_debug_event(event, state_data, monitor_state) do
    try do
      case event do
        {:in, msg} ->
          # Message received by the process
          handle_message_event(:received, msg, state_data, monitor_state)
          
        {:out, msg, to} ->
          # Message sent by the process
          handle_message_event(:sent, {msg, to}, state_data, monitor_state)
          
        {:noreply, new_state} ->
          # State change without reply
          handle_state_change(new_state, monitor_state)
          
        {:reply, reply, new_state} ->
          # State change with reply
          handle_state_change_with_reply(reply, new_state, monitor_state)
          
        {:stop, reason, new_state} ->
          # Process stopping
          handle_process_stop(reason, new_state, monitor_state)
          
        {:invalid_event, _} ->
          # Explicitly handle invalid events to make error path reachable
          {:error, :invalid_debug_event}
          
        event when not is_tuple(event) ->
          # Handle malformed events
          {:error, {:malformed_event, event}}
          
        _ ->
          # Other debug events
          Logger.debug("Unhandled debug event: #{inspect(event)}")
          {:ok, monitor_state}
      end
    rescue
      error ->
        {:error, {:exception_in_debug_handler, error}}
    catch
      :exit, reason ->
        {:error, {:exit_in_debug_handler, reason}}
    end
  end

  defp handle_message_event(direction, message_data, _state_data, monitor_state) do
    event = case direction do
      :received ->
        %Events.MessageReceived{
          pid: monitor_state.target_pid,
          message: message_data,
          correlation_id: generate_correlation_id(monitor_state),
          timestamp: :erlang.monotonic_time(),
          wall_time: System.system_time(:microsecond)
        }
        
      :sent ->
        {msg, to} = message_data
        %Events.MessageSent{
          from_pid: monitor_state.target_pid,
          to_pid: to,
          message: msg,
          correlation_id: generate_correlation_id(monitor_state),
          timestamp: :erlang.monotonic_time(),
          wall_time: System.system_time(:microsecond)
        }
    end
    
    forward_event_to_ingestor(event, monitor_state.ingestor_buffer)
    {:ok, monitor_state}
  end

  defp handle_state_change(new_state, monitor_state) do
    if state_changed?(monitor_state.last_state, new_state) do
      event = %Events.StateChange{
        pid: monitor_state.target_pid,
        old_state: monitor_state.last_state,
        new_state: new_state,
        correlation_id: generate_correlation_id(monitor_state),
        timestamp: :erlang.monotonic_time(),
        wall_time: System.system_time(:microsecond)
      }
      
      forward_event_to_ingestor(event, monitor_state.ingestor_buffer)
      
      # Notify manager if this is part of a time-travel session
      if monitor_state.time_travel_session do
        send(monitor_state.manager_pid, {:state_change_captured, monitor_state.monitor_ref, event})
      end
      
      new_stats = Map.update!(monitor_state.stats, :state_changes_captured, &(&1 + 1))
      {:ok, %{monitor_state | last_state: new_state, stats: new_stats}}
    else
      {:ok, monitor_state}
    end
  end

  defp handle_state_change_with_reply(reply, new_state, monitor_state) do
    # Handle the state change
    {:ok, updated_monitor_state} = handle_state_change(new_state, monitor_state)
    
    # Also capture the reply if needed
    if monitor_state.monitoring_level == :full_callbacks do
      reply_event = %Events.CallbackReply{
        pid: monitor_state.target_pid,
        reply: reply,
        correlation_id: generate_correlation_id(monitor_state),
        timestamp: :erlang.monotonic_time(),
        wall_time: System.system_time(:microsecond)
      }
      
      forward_event_to_ingestor(reply_event, monitor_state.ingestor_buffer)
    end
    
    {:ok, updated_monitor_state}
  end

  defp handle_process_stop(reason, final_state, monitor_state) do
    event = %Events.ProcessExit{
      pid: monitor_state.target_pid,
      reason: reason,
      final_state: final_state,
      correlation_id: generate_correlation_id(monitor_state),
      timestamp: :erlang.monotonic_time(),
      wall_time: System.system_time(:microsecond)
    }
    
    forward_event_to_ingestor(event, monitor_state.ingestor_buffer)
    {:ok, monitor_state}
  end

  defp capture_state_snapshot(monitor_state) do
    case get_process_state(monitor_state.target_pid) do
      {:ok, current_state} ->
        event = %Events.StateSnapshot{
          pid: monitor_state.target_pid,
          state: current_state,
          session_id: monitor_state.time_travel_session,
          correlation_id: generate_correlation_id(monitor_state),
          timestamp: :erlang.monotonic_time(),
          wall_time: System.system_time(:microsecond)
        }
        
        forward_event_to_ingestor(event, monitor_state.ingestor_buffer)
        
        # Notify manager if this is part of a time-travel session
        if monitor_state.time_travel_session do
          send(monitor_state.manager_pid, {:state_change_captured, monitor_state.monitor_ref, event})
        end
        
        {:ok, event}
        
      error ->
        error
    end
  end

  defp get_process_state(pid) do
    try do
      case :sys.get_state(pid) do
        state when state != :undefined ->
          {:ok, state}
        :undefined ->
          {:error, :no_state}
      end
    rescue
      error ->
        {:error, {:exception, error}}
    catch
      :exit, reason ->
        {:error, {:exit, reason}}
    end
  end

  defp state_changed?(old_state, new_state) do
    # Simple comparison - in production might want more sophisticated diffing
    old_state != new_state
  end

  defp generate_correlation_id(monitor_state) do
    "state-monitor-#{:erlang.phash2(monitor_state.target_pid)}-#{:erlang.unique_integer([:positive])}"
  end

  defp forward_event_to_ingestor(event, ingestor_buffer) do
    if ingestor_buffer do
      Ingestor.ingest_generic_event(
        ingestor_buffer,
        event.__struct__,
        Map.from_struct(event),
        event.pid,
        event.correlation_id,
        event.timestamp,
        event.wall_time
      )
    else
      Logger.debug("No ingestor buffer available, dropping event: #{inspect(event)}")
    end
  end

  defp cleanup_monitoring(state) do
    # Remove debug handler
    if state.target_pid && Process.alive?(state.target_pid) do
      try do
        :sys.remove(state.target_pid, {self(), state.monitor_ref})
      rescue
        _ -> :ok
      end
    end
    
    # Cancel snapshot timer
    if state.snapshot_timer do
      :timer.cancel(state.snapshot_timer)
    end
    
    Logger.debug("Cleaned up monitoring for PID #{inspect(state.target_pid)}")
  end
end 