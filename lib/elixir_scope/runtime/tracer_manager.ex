defmodule ElixirScope.Runtime.TracerManager do
  @moduledoc """
  Manages multiple Tracer instances for distributed runtime tracing.
  
  Responsibilities:
  - Start/stop individual tracers based on plans
  - Distribute tracing load across tracer processes
  - Handle tracer failures and restarts
  - Apply runtime plans to active tracers
  """
  
  use GenServer
  require Logger

  alias ElixirScope.Runtime.Tracer
  alias ElixirScope.Capture.Ingestor

  defstruct [
    :active_tracers,
    :tracer_pool_size,
    :next_tracer_index,
    :trace_assignments,
    :ingestor_buffer
  ]

  @default_pool_size 4

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def add_trace(manager_pid, trace_ref, target, opts) do
    GenServer.call(manager_pid, {:add_trace, trace_ref, target, opts})
  end

  def remove_trace(manager_pid, trace_ref) do
    GenServer.call(manager_pid, {:remove_trace, trace_ref})
  end

  def adjust_trace(manager_pid, trace_ref, adjustments) do
    GenServer.call(manager_pid, {:adjust_trace, trace_ref, adjustments})
  end

  def add_pattern_trace(manager_pid, trace_ref, pattern, opts) do
    GenServer.call(manager_pid, {:add_pattern_trace, trace_ref, pattern, opts})
  end

  def apply_plan(manager_pid, runtime_plan) do
    GenServer.cast(manager_pid, {:apply_plan, runtime_plan})
  end

  def stop_all_traces(manager_pid) do
    GenServer.call(manager_pid, :stop_all_traces)
  end

  def get_tracer_stats(manager_pid) do
    GenServer.call(manager_pid, :get_tracer_stats)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)
    
    # Get the ingestor buffer for forwarding events
    ingestor_buffer = case Ingestor.get_buffer() do
      {:ok, buffer} -> buffer
      _ -> 
        Logger.warning("Could not get Ingestor buffer, events may not be captured")
        nil
    end

    # Start initial pool of tracer processes
    active_tracers = start_tracer_pool(pool_size, ingestor_buffer)

    state = %__MODULE__{
      active_tracers: active_tracers,
      tracer_pool_size: pool_size,
      next_tracer_index: 0,
      trace_assignments: %{}, # trace_ref => tracer_pid
      ingestor_buffer: ingestor_buffer
    }

    Logger.info("TracerManager started with #{pool_size} tracer processes")
    {:ok, state}
  end

  @impl true
  def handle_call({:add_trace, trace_ref, target, opts}, _from, state) do
    # Select a tracer using round-robin
    tracer_pid = select_tracer(state)
    
    case Tracer.start_trace(tracer_pid, trace_ref, target, opts) do
      :ok ->
        new_assignments = Map.put(state.trace_assignments, trace_ref, tracer_pid)
        Logger.debug("Assigned trace #{inspect(trace_ref)} to tracer #{inspect(tracer_pid)}")
        {:reply, :ok, %{state | trace_assignments: new_assignments}}
        
      {:error, reason} = error ->
        Logger.warning("Failed to start trace #{inspect(trace_ref)}: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:remove_trace, trace_ref}, _from, state) do
    case Map.get(state.trace_assignments, trace_ref) do
      nil ->
        {:reply, {:error, :trace_not_found}, state}
        
      tracer_pid ->
        case Tracer.stop_trace(tracer_pid, trace_ref) do
          :ok ->
            new_assignments = Map.delete(state.trace_assignments, trace_ref)
            Logger.debug("Removed trace #{inspect(trace_ref)} from tracer #{inspect(tracer_pid)}")
            {:reply, :ok, %{state | trace_assignments: new_assignments}}
            
          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:adjust_trace, trace_ref, adjustments}, _from, state) do
    case Map.get(state.trace_assignments, trace_ref) do
      nil ->
        {:reply, {:error, :trace_not_found}, state}
        
      tracer_pid ->
        result = Tracer.adjust_trace_parameters(tracer_pid, trace_ref, adjustments)
        {:reply, result, state}
    end
  end

  @impl true
  def handle_call({:add_pattern_trace, trace_ref, pattern, opts}, _from, state) do
    # Pattern traces might need special handling or a dedicated tracer
    tracer_pid = select_tracer(state)
    
    case Tracer.start_pattern_trace(tracer_pid, trace_ref, pattern, opts) do
      :ok ->
        new_assignments = Map.put(state.trace_assignments, trace_ref, tracer_pid)
        Logger.debug("Assigned pattern trace #{inspect(trace_ref)} to tracer #{inspect(tracer_pid)}")
        {:reply, :ok, %{state | trace_assignments: new_assignments}}
        
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:stop_all_traces, _from, state) do
    # Stop all traces on all tracers
    Enum.each(state.active_tracers, fn tracer_pid ->
      Tracer.stop_all_traces(tracer_pid)
    end)
    
    Logger.info("Stopped all traces across #{length(state.active_tracers)} tracers")
    {:reply, :ok, %{state | trace_assignments: %{}}}
  end

  @impl true
  def handle_call(:get_tracer_stats, _from, state) do
    stats = Enum.map(state.active_tracers, fn tracer_pid ->
      case Tracer.get_stats(tracer_pid) do
        {:ok, tracer_stats} -> 
          Map.put(tracer_stats, :pid, tracer_pid)
        _ -> 
          %{pid: tracer_pid, status: :error}
      end
    end)
    
    overall_stats = %{
      total_tracers: length(state.active_tracers),
      active_traces: map_size(state.trace_assignments),
      tracer_stats: stats
    }
    
    {:reply, overall_stats, state}
  end

  @impl true
  def handle_cast({:apply_plan, runtime_plan}, state) do
    # Apply the runtime plan to all active tracers
    Enum.each(state.active_tracers, fn tracer_pid ->
      Tracer.apply_runtime_plan(tracer_pid, runtime_plan)
    end)
    
    Logger.info("Applied runtime plan to #{length(state.active_tracers)} tracers")
    {:noreply, state}
  end

  # Handle tracer process exits
  @impl true
  def handle_info({:DOWN, _ref, :process, tracer_pid, reason}, state) do
    Logger.warning("Tracer process #{inspect(tracer_pid)} exited: #{inspect(reason)}")
    
    # Remove the dead tracer from active list
    new_active_tracers = List.delete(state.active_tracers, tracer_pid)
    
    # Find traces that were assigned to this tracer and reassign them
    dead_tracer_traces = state.trace_assignments
    |> Enum.filter(fn {_trace_ref, pid} -> pid == tracer_pid end)
    |> Enum.map(fn {trace_ref, _pid} -> trace_ref end)
    
    # Start a replacement tracer
    {:ok, new_tracer_pid} = start_tracer(state.ingestor_buffer)
    replacement_tracers = [new_tracer_pid | new_active_tracers]
    
    # Reassign the traces to other tracers (simplified - in production might want to restart them)
    new_assignments = Enum.reduce(dead_tracer_traces, state.trace_assignments, fn trace_ref, acc ->
      Map.delete(acc, trace_ref)
    end)
    
    Logger.info("Replaced dead tracer with #{inspect(new_tracer_pid)}, lost #{length(dead_tracer_traces)} traces")
    
    new_state = %{state | 
      active_tracers: replacement_tracers,
      trace_assignments: new_assignments
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Private Helper Functions ---

  defp start_tracer_pool(pool_size, ingestor_buffer) do
    Enum.map(1..pool_size, fn _i ->
      {:ok, tracer_pid} = start_tracer(ingestor_buffer)
      tracer_pid
    end)
  end

  defp start_tracer(ingestor_buffer) do
    tracer_opts = [ingestor_buffer: ingestor_buffer]
    case Tracer.start_link(tracer_opts) do
      {:ok, pid} = success ->
        # Monitor the tracer process so we can restart it if it dies
        Process.monitor(pid)
        success
        
      error ->
        Logger.error("Failed to start tracer: #{inspect(error)}")
        error
    end
  end

  defp select_tracer(state) do
    # Simple round-robin selection
    tracer_index = rem(state.next_tracer_index, length(state.active_tracers))
    tracer_pid = Enum.at(state.active_tracers, tracer_index)
    
    # Update the index for next selection (this would be done in the calling handle_call)
    # For now, just return the selected tracer
    tracer_pid
  end


end 