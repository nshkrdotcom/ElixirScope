defmodule ElixirScope.Capture.Ingestor do
  @moduledoc """
  Ultra-fast event ingestor for ElixirScope.
  
  This is the critical hot path for event capture. Every microsecond counts here.
  Target: <1µs per event processing time.
  
  Key optimizations:
  - Direct ring buffer writes with minimal function call overhead
  - Pre-allocated event structs where possible
  - Inline timestamp generation
  - Minimal validation in hot path
  - Batch processing for better throughput
  """

  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Events
  alias ElixirScope.Utils

  @type ingest_result :: :ok | {:error, term()}

  # Pre-compile common event patterns for speed
  @compile {:inline, [
    ingest_function_call: 6,
    ingest_function_return: 4,
    ingest_process_spawn: 3,
    ingest_message_send: 4,
    ingest_state_change: 4
  ]}

  @doc """
  Ingests a function call event.
  
  This is the most common event type and is heavily optimized.
  """
  @spec ingest_function_call(
    RingBuffer.t(),
    module(),
    atom(),
    list(),
    pid(),
    term()
  ) :: ingest_result()
  def ingest_function_call(buffer, module, function, args, caller_pid, correlation_id) do
    event = %Events.FunctionExecution{
      id: Utils.generate_id(),
      timestamp: Utils.monotonic_timestamp(),
      wall_time: Utils.wall_timestamp(),
      module: module,
      function: function,
      arity: length(args),
      args: Utils.truncate_data(args),
      caller_pid: caller_pid,
      correlation_id: correlation_id,
      event_type: :call
    }
    
    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a function return event.
  """
  @spec ingest_function_return(
    RingBuffer.t(),
    term(),
    non_neg_integer(),
    term()
  ) :: ingest_result()
  def ingest_function_return(buffer, return_value, duration_ns, correlation_id) do
    event = %Events.FunctionExecution{
      id: Utils.generate_id(),
      timestamp: Utils.monotonic_timestamp(),
      wall_time: Utils.wall_timestamp(),
      return_value: Utils.truncate_data(return_value),
      duration_ns: duration_ns,
      correlation_id: correlation_id,
      event_type: :return
    }
    
    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a process spawn event.
  """
  @spec ingest_process_spawn(RingBuffer.t(), pid(), pid()) :: ingest_result()
  def ingest_process_spawn(buffer, parent_pid, child_pid) do
    event = %Events.ProcessEvent{
      id: Utils.generate_id(),
      timestamp: Utils.monotonic_timestamp(),
      wall_time: Utils.wall_timestamp(),
      pid: child_pid,
      parent_pid: parent_pid,
      event_type: :spawn
    }
    
    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a message send event.
  """
  @spec ingest_message_send(RingBuffer.t(), pid(), pid(), term()) :: ingest_result()
  def ingest_message_send(buffer, from_pid, to_pid, message) do
    event = %Events.MessageEvent{
      id: Utils.generate_id(),
      timestamp: Utils.monotonic_timestamp(),
      wall_time: Utils.wall_timestamp(),
      from_pid: from_pid,
      to_pid: to_pid,
      message: Utils.truncate_data(message),
      event_type: :send
    }
    
    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a state change event.
  """
  @spec ingest_state_change(RingBuffer.t(), pid(), term(), term()) :: ingest_result()
  def ingest_state_change(buffer, server_pid, old_state, new_state) do
    # Use the base event wrapper approach for StateChange
    data = %Events.StateChange{
      server_pid: server_pid,
      callback: :unknown,  # This would be passed as parameter in real usage
      old_state: Utils.truncate_data(old_state),
      new_state: Utils.truncate_data(new_state),
      state_diff: compute_state_diff(old_state, new_state),
      trigger_message: nil,
      trigger_call_id: nil
    }
    
    event = Events.new_event(:state_change, data)
    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a performance metric event.
  """
  @spec ingest_performance_metric(RingBuffer.t(), atom(), number(), map()) :: ingest_result()
  def ingest_performance_metric(buffer, metric_name, value, metadata \\ %{}) do
    event = %Events.PerformanceMetric{
      id: Utils.generate_id(),
      timestamp: Utils.monotonic_timestamp(),
      wall_time: Utils.wall_timestamp(),
      metric_name: metric_name,
      value: value,
      metadata: metadata
    }
    
    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests an error event.
  """
  @spec ingest_error(RingBuffer.t(), term(), term(), list()) :: ingest_result()
  def ingest_error(buffer, error_type, error_message, stacktrace) do
    data = %Events.ErrorEvent{
      error_type: error_type,
      error_class: :unknown,  # Could be extracted from error in real usage
      error_message: Utils.truncate_data(error_message),
      stacktrace: Utils.truncate_data(stacktrace),
      context: nil,
      recovery_action: nil
    }
    
    event = Events.new_event(:error, data)
    RingBuffer.write(buffer, event)
  end

  @doc """
  Batch ingestion for better throughput when processing multiple events.
  
  This is more efficient than individual calls when you have multiple events
  to process at once.
  """
  @spec ingest_batch(RingBuffer.t(), [Events.event()]) :: {:ok, non_neg_integer()} | {:error, term()}
  def ingest_batch(buffer, events) when is_list(events) do
    results = Enum.map(events, &RingBuffer.write(buffer, &1))
    
    success_count = Enum.count(results, &(&1 == :ok))
    
    if success_count == length(events) do
      {:ok, success_count}
    else
      # Return partial success info
      errors = Enum.filter(results, &(elem(&1, 0) == :error))
      {:error, {:partial_success, success_count, errors}}
    end
  end

  @doc """
  Creates a pre-configured ingestor for a specific buffer.
  
  Returns a function that can be called with minimal overhead for repeated ingestion.
  This is useful for hot paths where the buffer doesn't change.
  """
  @spec create_fast_ingestor(RingBuffer.t()) :: (Events.event() -> ingest_result())
  def create_fast_ingestor(buffer) do
    # Return a closure that captures the buffer
    fn event -> RingBuffer.write(buffer, event) end
  end

  @doc """
  Measures the ingestion performance for benchmarking.
  
  Returns timing statistics for the ingestion operation.
  """
  @spec benchmark_ingestion(RingBuffer.t(), Events.event(), pos_integer()) :: %{
    avg_time_ns: float(),
    min_time_ns: non_neg_integer(),
    max_time_ns: non_neg_integer(),
    total_time_ns: non_neg_integer(),
    operations: pos_integer()
  }
  def benchmark_ingestion(buffer, sample_event, iterations \\ 1000) do
    times = for _ <- 1..iterations do
      start_time = System.monotonic_time(:nanosecond)
      RingBuffer.write(buffer, sample_event)
      System.monotonic_time(:nanosecond) - start_time
    end
    
    total_time = Enum.sum(times)
    
    %{
      avg_time_ns: total_time / iterations,
      min_time_ns: Enum.min(times),
      max_time_ns: Enum.max(times),
      total_time_ns: total_time,
      operations: iterations
    }
  end

  @doc """
  Validates that ingestion performance meets targets.
  
  Returns `:ok` if performance is acceptable, `{:error, reason}` otherwise.
  """
  @spec validate_performance(RingBuffer.t()) :: :ok | {:error, term()}
  def validate_performance(buffer) do
    # Create a sample event for testing
    sample_event = %Events.FunctionExecution{
      id: Utils.generate_id(),
      timestamp: Utils.monotonic_timestamp(),
      wall_time: Utils.wall_timestamp(),
      module: TestModule,
      function: :test_function,
      arity: 0,
      event_type: :call
    }
    
    # Run benchmark
    stats = benchmark_ingestion(buffer, sample_event, 1000)
    
    # Check if average time is under 1µs (1000ns)
    target_ns = 1000
    
    if stats.avg_time_ns <= target_ns do
      :ok
    else
      {:error, {:performance_target_missed, stats.avg_time_ns, target_ns}}
    end
  end

  # Private helper functions

  # Compute a simple diff between old and new state
  defp compute_state_diff(old_state, new_state) do
    if old_state == new_state do
      :no_change
    else
      {:changed, inspect_diff(old_state, new_state)}
    end
  end

  defp inspect_diff(old, new) do
    %{
      old: inspect(old, limit: 20),
      new: inspect(new, limit: 20),
      size_change: term_size_estimate(new) - term_size_estimate(old)
    }
  end

  defp term_size_estimate(term) do
    term |> :erlang.term_to_binary() |> byte_size()
  end
end 