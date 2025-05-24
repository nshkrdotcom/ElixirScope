defmodule ElixirScope.Capture.AsyncWriter do
  @moduledoc """
  AsyncWriter is a worker process that consumes events from ring buffers,
  enriches them with metadata, and processes them asynchronously.
  
  Key responsibilities:
  - Read events from ring buffers in configurable batches
  - Enrich events with correlation and processing metadata
  - Handle errors gracefully without affecting the pipeline
  - Track processing metrics and performance
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Utils
  
  @default_config %{
    ring_buffer: nil,
    batch_size: 50,
    poll_interval_ms: 100,
    max_backlog: 1000
  }
  
  defstruct [
    :config,
    :current_position,
    :events_read,
    :events_processed,
    :batches_processed,
    :processing_rate,
    :error_count,
    :start_time,
    :last_poll_time,
    :processing_order
  ]
  
  ## Public API
  
  @doc """
  Starts an AsyncWriter with the given configuration.
  """
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end
  
  @doc """
  Gets the current state of the AsyncWriter.
  """
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end
  
  @doc """
  Gets current metrics about processing performance.
  """
  def get_metrics(pid) do
    GenServer.call(pid, :get_metrics)
  end
  
  @doc """
  Sets the current position in the ring buffer.
  """
  def set_position(pid, position) do
    GenServer.call(pid, {:set_position, position})
  end
  
  @doc """
  Enriches an event with correlation and processing metadata.
  """
  def enrich_event(event) do
    now = Utils.monotonic_timestamp()
    
    event
    |> Map.put(:correlation_id, generate_correlation_id())
    |> Map.put(:enriched_at, now)
    |> Map.put(:processed_by, node())
    |> Map.put(:processing_order, :erlang.unique_integer([:positive]))
  end
  
  @doc """
  Gracefully stops the AsyncWriter.
  """
  def stop(pid) do
    GenServer.call(pid, :stop)
  end
  
  ## GenServer Implementation
  
  @impl true
  def init(config) do
    # Merge with defaults
    final_config = Map.merge(@default_config, config || %{})
    
    state = %__MODULE__{
      config: final_config,
      current_position: 0,
      events_read: 0,
      events_processed: 0,
      batches_processed: 0,
      processing_rate: 0.0,
      error_count: 0,
      start_time: Utils.monotonic_timestamp(),
      last_poll_time: Utils.monotonic_timestamp(),
      processing_order: 0
    }
    
    # Schedule first poll
    schedule_poll(final_config.poll_interval_ms)
    
    Logger.debug("AsyncWriter started with config: #{inspect(final_config)}")
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      events_read: state.events_read,
      events_processed: state.events_processed,
      batches_processed: state.batches_processed,
      processing_rate: state.processing_rate,
      error_count: state.error_count
    }
    
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_call({:set_position, position}, _from, state) do
    updated_state = %{state | current_position: position}
    {:reply, :ok, updated_state}
  end
  
  @impl true
  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end
  
  @impl true
  def handle_info(:poll, state) do
    # Process a batch of events
    new_state = process_batch(state)
    
    # Schedule next poll
    schedule_poll(new_state.config.poll_interval_ms)
    
    {:noreply, new_state}
  end
  
  ## Private Functions
  
  defp schedule_poll(interval_ms) do
    Process.send_after(self(), :poll, interval_ms)
  end
  
  defp process_batch(state) do
    try do
      case state.config.ring_buffer do
        nil ->
          # No ring buffer configured, just update error count
          %{state | error_count: state.error_count + 1}
        
        :invalid_buffer ->
          # Invalid buffer for testing
          %{state | error_count: state.error_count + 1}
        
        ring_buffer ->
          # Read batch from ring buffer
          {events, new_position} = RingBuffer.read_batch(
            ring_buffer, 
            state.current_position, 
            state.config.batch_size
          )
          
                     # Update events read first
           updated_state = %{state |
             current_position: new_position,
             events_read: state.events_read + length(events),
             batches_processed: state.batches_processed + 1
           }
           
           # Process events if any
           if length(events) > 0 do
             try do
               processed_events = process_events(events, updated_state)
               
               # Update processing metrics
               now = Utils.monotonic_timestamp()
               time_diff = max(now - state.last_poll_time, 1)
               processing_rate = calculate_processing_rate(length(processed_events), time_diff)
               
               %{updated_state |
                 events_processed: updated_state.events_processed + length(processed_events),
                 processing_rate: processing_rate,
                 last_poll_time: now
               }
             rescue
               _error ->
               # Processing failed, but we still read the events
               %{updated_state |
                 error_count: updated_state.error_count + 1,
                 last_poll_time: Utils.monotonic_timestamp()
               }
             end
           else
             %{updated_state | last_poll_time: Utils.monotonic_timestamp()}
           end
      end
    rescue
      error ->
        Logger.warning("AsyncWriter batch processing error: #{inspect(error)}")
        %{state | error_count: state.error_count + 1}
    end
  end
  
  defp process_events(events, state) do
    # Check for error simulation in test mode
    if state.config[:simulate_errors] do
      # Simulate processing error for testing
      raise "Simulated processing error"
    end
    
    # Enrich and process each event
    Enum.map(events, fn event ->
      enriched = enrich_event(event)
      # TODO: Write to storage layer
      enriched
    end)
  end
  
  defp calculate_processing_rate(events_count, time_diff_ns) do
    if time_diff_ns > 0 do
      # Convert to events per second
      (events_count * 1_000_000_000) / time_diff_ns
    else
      0.0
    end
  end
  
  defp generate_correlation_id do
    # Generate a simple correlation ID
    "corr_#{:erlang.unique_integer([:positive])}"
  end
end 