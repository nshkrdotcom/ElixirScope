defmodule ElixirScope.Capture.AsyncWriterPool do
  @moduledoc """
  AsyncWriterPool manages a pool of AsyncWriter processes that consume
  events from ring buffers and process them asynchronously.
  
  Key responsibilities:
  - Manage a configurable pool of AsyncWriter workers
  - Distribute work segments across workers to avoid duplication
  - Monitor and restart failed workers automatically
  - Provide scaling, metrics aggregation, and health monitoring
  - Coordinate workers to process events efficiently
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.Capture.AsyncWriter
  alias ElixirScope.Utils
  
  @default_config %{
    pool_size: 4,
    ring_buffer: nil,
    batch_size: 50,
    poll_interval_ms: 100,
    max_backlog: 1000
  }
  
  defstruct [
    :config,
    :workers,
    :worker_assignments,
    :start_time,
    :worker_monitors
  ]
  
  ## Public API
  
  def start_mock do
    # Legacy function for backward compatibility
    Process.sleep(:infinity)
  end
  
  @doc """
  Starts the AsyncWriterPool with the given configuration.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  @doc """
  Gets the current state of the pool.
  """
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end
  
  @doc """
  Scales the pool to the specified size.
  """
  def scale_pool(pid, new_size) do
    GenServer.call(pid, {:scale_pool, new_size})
  end
  
  @doc """
  Gets aggregated metrics from all workers.
  """
  def get_metrics(pid) do
    GenServer.call(pid, :get_metrics)
  end
  
  @doc """
  Gets worker assignment information.
  """
  def get_worker_assignments(pid) do
    GenServer.call(pid, :get_worker_assignments)
  end
  
  @doc """
  Performs a health check on all workers.
  """
  def health_check(pid) do
    GenServer.call(pid, :health_check)
  end
  
  @doc """
  Gracefully stops the pool and all workers.
  """
  def stop(pid) do
    GenServer.call(pid, :stop)
  end
  
  ## GenServer Implementation
  
  @impl true
  def init(opts) do
    # Trap exits to handle worker failures gracefully
    Process.flag(:trap_exit, true)
    
    # Merge with defaults
    config = case opts do
      [] -> @default_config
      %{} = config_map -> Map.merge(@default_config, config_map)
      _other -> @default_config
    end
    
    # Start workers
    {workers, monitors} = start_workers(config)
    
    # Assign work segments to workers
    assignments = assign_work_segments(workers, config)
    
    state = %__MODULE__{
      config: config,
      workers: workers,
      worker_assignments: assignments,
      start_time: Utils.monotonic_timestamp(),
      worker_monitors: monitors
    }
    
    Logger.info("AsyncWriterPool started with #{length(workers)} workers")
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
  
  @impl true
  def handle_call({:scale_pool, new_size}, _from, state) do
    current_size = length(state.workers)
    
    cond do
      new_size > current_size ->
        # Scale up - add workers
        additional_workers_needed = new_size - current_size
        {new_workers, new_monitors} = start_additional_workers(additional_workers_needed, state.config)
        
        all_workers = state.workers ++ new_workers
        all_monitors = Map.merge(state.worker_monitors, new_monitors)
        new_assignments = assign_work_segments(all_workers, state.config)
        
        updated_state = %{state |
          workers: all_workers,
          worker_assignments: new_assignments,
          worker_monitors: all_monitors
        }
        
        {:reply, :ok, updated_state}
      
      new_size < current_size ->
        # Scale down - stop excess workers
        workers_to_keep = Enum.take(state.workers, new_size)
        workers_to_stop = Enum.drop(state.workers, new_size)
        
        # Stop excess workers and demonitor them
        Enum.each(workers_to_stop, fn worker_pid ->
          # Demonitor first
          if Map.has_key?(state.worker_monitors, worker_pid) do
            Process.demonitor(state.worker_monitors[worker_pid], [:flush])
          end
          
          # Then stop the worker
          if Process.alive?(worker_pid) do
            AsyncWriter.stop(worker_pid)
          end
        end)
        
        # Update monitors - remove the stopped workers
        updated_monitors = Map.drop(state.worker_monitors, workers_to_stop)
        new_assignments = assign_work_segments(workers_to_keep, state.config)
        
        updated_state = %{state |
          workers: workers_to_keep,
          worker_assignments: new_assignments,
          worker_monitors: updated_monitors
        }
        
        {:reply, :ok, updated_state}
      
      true ->
        # No change needed
        {:reply, :ok, state}
    end
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    # Aggregate metrics from all workers
    worker_metrics = Enum.map(state.workers, fn worker_pid ->
      if Process.alive?(worker_pid) do
        try do
          AsyncWriter.get_metrics(worker_pid)
        rescue
          _ -> %{events_read: 0, events_processed: 0, batches_processed: 0, processing_rate: 0.0, error_count: 0}
        end
      else
        %{events_read: 0, events_processed: 0, batches_processed: 0, processing_rate: 0.0, error_count: 0}
      end
    end)
    
    aggregated_metrics = %{
      total_events_read: Enum.sum(Enum.map(worker_metrics, & &1.events_read)),
      total_events_processed: Enum.sum(Enum.map(worker_metrics, & &1.events_processed)),
      total_batches_processed: Enum.sum(Enum.map(worker_metrics, & &1.batches_processed)),
      average_processing_rate: average_processing_rate(worker_metrics),
      total_errors: Enum.sum(Enum.map(worker_metrics, & &1.error_count)),
      worker_count: length(state.workers)
    }
    
    {:reply, aggregated_metrics, state}
  end
  
  @impl true
  def handle_call(:get_worker_assignments, _from, state) do
    {:reply, state.worker_assignments, state}
  end
  
  @impl true
  def handle_call(:health_check, _from, state) do
    alive_workers = Enum.count(state.workers, &Process.alive?/1)
    failed_workers = length(state.workers) - alive_workers
    
    status = if failed_workers == 0, do: :healthy, else: :degraded
    
    health = %{
      status: status,
      worker_count: length(state.workers),
      healthy_workers: alive_workers,
      failed_workers: failed_workers,
      uptime_ms: Utils.monotonic_timestamp() - state.start_time
    }
    
    {:reply, health, state}
  end
  
  @impl true
  def handle_call(:stop, _from, state) do
    Logger.info("AsyncWriterPool shutting down gracefully")
    
    # Stop all workers
    Enum.each(state.workers, fn worker_pid ->
      if Process.alive?(worker_pid) do
        AsyncWriter.stop(worker_pid)
      end
    end)
    
    {:stop, :normal, :ok, state}
  end
  
  @impl true
  def handle_info({:EXIT, worker_pid, reason}, state) do
    # Handle EXIT messages when workers are killed
    handle_worker_death(worker_pid, reason, state)
  end
  
  @impl true
  def handle_info({:DOWN, _monitor_ref, :process, worker_pid, reason}, state) do
    # Handle DOWN messages from monitors
    handle_worker_death(worker_pid, reason, state)
  end
  
  defp handle_worker_death(worker_pid, reason, state) do
    # Only restart if this worker is still in our current worker list
    if worker_pid in state.workers do
      Logger.warning("AsyncWriter worker #{inspect(worker_pid)} died (#{inspect(reason)}), restarting...")
      
      # Remove the dead worker from our state
      remaining_workers = List.delete(state.workers, worker_pid)
      
      # Remove the monitor
      updated_monitors = Map.delete(state.worker_monitors, worker_pid)
      
      # Start a new worker to replace it
      try do
        {new_workers, new_monitors} = start_additional_workers(1, state.config)
        [new_worker_pid] = new_workers
        
        all_workers = remaining_workers ++ new_workers
        all_monitors = Map.merge(updated_monitors, new_monitors)
        
        # Reassign work segments
        new_assignments = assign_work_segments(all_workers, state.config)
        
        updated_state = %{state |
          workers: all_workers,
          worker_assignments: new_assignments,
          worker_monitors: all_monitors
        }
        
        Logger.info("AsyncWriter worker restarted as #{inspect(new_worker_pid)}")
        
        {:noreply, updated_state}
      rescue
        error ->
          Logger.error("Failed to restart worker: #{inspect(error)}")
          # Continue with reduced worker count
          new_assignments = assign_work_segments(remaining_workers, state.config)
          
          updated_state = %{state |
            workers: remaining_workers,
            worker_assignments: new_assignments,
            worker_monitors: updated_monitors
          }
          
          {:noreply, updated_state}
      end
    else
      # Worker was already removed (e.g., during scaling down), ignore
      {:noreply, state}
    end
  end
  
  ## Private Functions
  
  defp start_workers(config) do
    start_additional_workers(config.pool_size, config)
  end
  
  defp start_additional_workers(count, config) do
    workers_and_monitors = for _i <- 1..count do
      worker_config = Map.take(config, [:ring_buffer, :batch_size, :poll_interval_ms, :max_backlog])
      {:ok, worker_pid} = AsyncWriter.start_link(worker_config)
      
      # Unlink from the worker to prevent propagating exits
      Process.unlink(worker_pid)
      
      # Monitor the worker instead
      monitor_ref = Process.monitor(worker_pid)
      
      {worker_pid, {worker_pid, monitor_ref}}
    end
    
    workers = Enum.map(workers_and_monitors, fn {worker_pid, _} -> worker_pid end)
    monitors = Map.new(Enum.map(workers_and_monitors, fn {_, monitor_info} -> monitor_info end))
    
    {workers, monitors}
  end
  
  defp assign_work_segments(workers, _config) do
    # Simple strategy: assign each worker a unique segment ID
    # This can be used by workers to determine which part of the ring buffer to read from
    workers
    |> Enum.with_index()
    |> Map.new(fn {worker_pid, index} -> {worker_pid, index} end)
  end
  
  defp average_processing_rate(worker_metrics) do
    if length(worker_metrics) > 0 do
      total_rate = Enum.sum(Enum.map(worker_metrics, & &1.processing_rate))
      total_rate / length(worker_metrics)
    else
      0.0
    end
  end
end 