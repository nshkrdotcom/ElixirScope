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

  # Delegate to specialized ingestors
  defdelegate ingest_phoenix_request_start(buffer, correlation_id, method, path, params, remote_ip),
    to: ElixirScope.Capture.Ingestor.Phoenix

  defdelegate ingest_phoenix_request_complete(buffer, correlation_id, status_code, content_type, duration_ms),
    to: ElixirScope.Capture.Ingestor.Phoenix

  defdelegate ingest_phoenix_controller_entry(buffer, correlation_id, controller, action, metadata),
    to: ElixirScope.Capture.Ingestor.Phoenix

  defdelegate ingest_phoenix_controller_exit(buffer, correlation_id, controller, action, result),
    to: ElixirScope.Capture.Ingestor.Phoenix

  defdelegate ingest_phoenix_action_params(buffer, action_name, conn, params),
    to: ElixirScope.Capture.Ingestor.Phoenix

  defdelegate ingest_phoenix_action_start(buffer, action_name, conn),
    to: ElixirScope.Capture.Ingestor.Phoenix

  defdelegate ingest_phoenix_action_success(buffer, action_name, conn, result),
    to: ElixirScope.Capture.Ingestor.Phoenix

  defdelegate ingest_phoenix_action_error(buffer, action_name, conn, kind, reason),
    to: ElixirScope.Capture.Ingestor.Phoenix

  defdelegate ingest_phoenix_action_complete(buffer, action_name, conn),
    to: ElixirScope.Capture.Ingestor.Phoenix

  defdelegate ingest_liveview_mount_start(buffer, correlation_id, module, params, session),
    to: ElixirScope.Capture.Ingestor.LiveView

  defdelegate ingest_liveview_mount_complete(buffer, correlation_id, module, socket_assigns),
    to: ElixirScope.Capture.Ingestor.LiveView

  defdelegate ingest_liveview_handle_event_start(buffer, correlation_id, event, params, socket_assigns),
    to: ElixirScope.Capture.Ingestor.LiveView

  defdelegate ingest_liveview_handle_event_complete(buffer, correlation_id, event, params, before_assigns, result),
    to: ElixirScope.Capture.Ingestor.LiveView

  defdelegate ingest_liveview_assigns(buffer, callback_name, socket),
    to: ElixirScope.Capture.Ingestor.LiveView

  defdelegate ingest_liveview_event(buffer, event, params, socket),
    to: ElixirScope.Capture.Ingestor.LiveView

  defdelegate ingest_liveview_callback(buffer, callback_name, socket),
    to: ElixirScope.Capture.Ingestor.LiveView

  defdelegate ingest_liveview_callback_success(buffer, callback_name, socket, result),
    to: ElixirScope.Capture.Ingestor.LiveView

  defdelegate ingest_liveview_callback_error(buffer, callback_name, socket, kind, reason),
    to: ElixirScope.Capture.Ingestor.LiveView

  defdelegate ingest_phoenix_channel_join_start(buffer, correlation_id, topic, payload, socket),
    to: ElixirScope.Capture.Ingestor.Channel

  defdelegate ingest_phoenix_channel_join_complete(buffer, correlation_id, topic, payload, result),
    to: ElixirScope.Capture.Ingestor.Channel

  defdelegate ingest_phoenix_channel_message_start(buffer, correlation_id, event, payload, socket),
    to: ElixirScope.Capture.Ingestor.Channel

  defdelegate ingest_phoenix_channel_message_complete(buffer, correlation_id, event, payload, result),
    to: ElixirScope.Capture.Ingestor.Channel

  defdelegate ingest_ecto_query_start(buffer, correlation_id, query, params, metadata, repo),
    to: ElixirScope.Capture.Ingestor.Ecto

  defdelegate ingest_ecto_query_complete(buffer, correlation_id, query, params, result, duration_us),
    to: ElixirScope.Capture.Ingestor.Ecto

  defdelegate ingest_genserver_callback_start(buffer, callback_name, pid, capture_state),
    to: ElixirScope.Capture.Ingestor.GenServer

  defdelegate ingest_genserver_callback_success(buffer, callback_name, pid, result),
    to: ElixirScope.Capture.Ingestor.GenServer

  defdelegate ingest_genserver_callback_error(buffer, callback_name, pid, kind, reason),
    to: ElixirScope.Capture.Ingestor.GenServer

  defdelegate ingest_genserver_callback_complete(buffer, callback_name, pid, capture_state),
    to: ElixirScope.Capture.Ingestor.GenServer

  defdelegate ingest_node_event(buffer, event_type, node_name, metadata),
    to: ElixirScope.Capture.Ingestor.Distributed

  defdelegate ingest_partition_detected(buffer, partitioned_nodes, metadata),
    to: ElixirScope.Capture.Ingestor.Distributed

  @type ingest_result :: :ok | {:error, term()}

  # Store the current buffer for runtime components to access
  @buffer_agent_name __MODULE__.BufferAgent

  # Pre-compile common event patterns for speed
  @compile {:inline, [
    ingest_function_call: 6,
    ingest_function_return: 4,
    ingest_process_spawn: 3,
    ingest_message_send: 4,
    ingest_state_change: 4,
    ingest_generic_event: 7
  ]}

  @doc """
  Gets the current buffer for runtime components.

  This allows runtime tracing components to access the shared event buffer.
  """
  @spec get_buffer() :: {:ok, RingBuffer.t()} | {:error, :not_initialized}
  def get_buffer do
    case Agent.get(@buffer_agent_name, & &1) do
      nil -> {:error, :not_initialized}
      buffer -> {:ok, buffer}
    end
  catch
    :exit, _ -> {:error, :not_initialized}
  end

  @doc """
  Sets the current buffer for runtime components.

  This should be called during ElixirScope initialization.
  """
  @spec set_buffer(RingBuffer.t()) :: :ok
  def set_buffer(buffer) do
    case Agent.start_link(fn -> buffer end, name: @buffer_agent_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} ->
        Agent.update(@buffer_agent_name, fn _ -> buffer end)
        :ok
    end
  end

  @doc """
  Ingests a generic event from runtime tracing components.

  This function converts runtime trace data into appropriate ElixirScope.Events
  and forwards them to the existing ingestion pipeline.
  """
  @spec ingest_generic_event(
    RingBuffer.t(),
    atom(),
    map(),
    pid(),
    term(),
    non_neg_integer(),
    non_neg_integer()
  ) :: ingest_result()
  def ingest_generic_event(buffer, event_type, event_data, pid, correlation_id, timestamp, wall_time) do
    event = case event_type do
      :function_entry ->
        %Events.FunctionEntry{
          timestamp: timestamp,
          wall_time: wall_time,
          module: Map.get(event_data, :module),
          function: Map.get(event_data, :function),
          arity: Map.get(event_data, :arity, 0),
          args: Utils.truncate_data(Map.get(event_data, :args, [])),
          call_id: Utils.generate_id(),
          pid: pid,
          correlation_id: correlation_id
        }

      :function_exit ->
        %Events.FunctionExit{
          timestamp: timestamp,
          wall_time: wall_time,
          module: Map.get(event_data, :module),
          function: Map.get(event_data, :function),
          arity: Map.get(event_data, :arity, 0),
          result: Utils.truncate_data(Map.get(event_data, :return_value)),
          duration_ns: Map.get(event_data, :duration_ns, 0),
          call_id: Map.get(event_data, :call_id, Utils.generate_id()),
          exit_reason: Map.get(event_data, :exit_reason, :normal),
          pid: pid,
          correlation_id: correlation_id
        }

      :state_change ->
        %Events.StateChange{
          server_pid: pid,
          callback: Map.get(event_data, :callback, :unknown),
          old_state: Utils.truncate_data(Map.get(event_data, :old_state)),
          new_state: Utils.truncate_data(Map.get(event_data, :new_state)),
          state_diff: Map.get(event_data, :state_diff),
          trigger_message: Map.get(event_data, :trigger_message),
          trigger_call_id: Map.get(event_data, :trigger_call_id),
          pid: pid,
          correlation_id: correlation_id,
          timestamp: timestamp,
          wall_time: wall_time
        }

      :state_snapshot ->
        %Events.StateSnapshot{
          server_pid: pid,
          state: Utils.truncate_data(Map.get(event_data, :state)),
          session_id: Map.get(event_data, :session_id),
          checkpoint_type: Map.get(event_data, :checkpoint_type, :manual),
          sequence_number: Map.get(event_data, :sequence_number, 0),
          pid: pid,
          correlation_id: correlation_id,
          timestamp: timestamp,
          wall_time: wall_time
        }

      :process_exit ->
        %Events.ProcessExit{
          exited_pid: pid,
          exit_reason: Map.get(event_data, :reason),
          lifetime_ns: Map.get(event_data, :lifetime_ns, 0),
          message_count: Map.get(event_data, :message_count),
          final_state: Map.get(event_data, :final_state),
          pid: pid,
          reason: Map.get(event_data, :reason),
          correlation_id: correlation_id,
          timestamp: timestamp,
          wall_time: wall_time
        }

      :message_received ->
        %Events.MessageReceived{
          pid: pid,
          message: Utils.truncate_data(Map.get(event_data, :message)),
          correlation_id: correlation_id,
          timestamp: timestamp,
          wall_time: wall_time
        }

      :message_sent ->
        %Events.MessageSent{
          from_pid: pid,
          to_pid: Map.get(event_data, :to_pid),
          message: Utils.truncate_data(Map.get(event_data, :message)),
          correlation_id: correlation_id,
          timestamp: timestamp,
          wall_time: wall_time
        }

      _ ->
        # Fallback for unknown event types
        %Events.FunctionEntry{
          timestamp: timestamp,
          wall_time: wall_time,
          module: :unknown,
          function: event_type,
          arity: 0,
          args: [event_data],
          call_id: Utils.generate_id(),
          pid: pid,
          correlation_id: correlation_id
        }
    end

    RingBuffer.write(buffer, event)
  end

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
    event = %Events.StateChange{
      server_pid: server_pid,
      callback: :unknown,  # This would be passed as parameter in real usage
      old_state: Utils.truncate_data(old_state),
      new_state: Utils.truncate_data(new_state),
      state_diff: compute_state_diff(old_state, new_state),
      trigger_message: nil,
      trigger_call_id: nil
    }

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
    event = %Events.ErrorEvent{
      error_type: error_type,
      error_class: :unknown,  # Could be extracted from error in real usage
      error_message: Utils.truncate_data(error_message),
      stacktrace: Utils.truncate_data(stacktrace),
      context: nil,
      recovery_action: nil
    }

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests multiple events in batch for improved performance.

  This is more efficient than individual ingestion for large numbers of events
  to process at once.
  """
  @spec ingest_batch(RingBuffer.t(), [Events.event()]) :: {:ok, non_neg_integer()} | {:error, term()}
  def ingest_batch(buffer, events) when is_list(events) do
    # Optimized batch implementation - use try/catch for fast path
    try do
      # Fast path: write all events and count successes in one pass
      count = fast_batch_write(buffer, events, 0)
      {:ok, count}
    catch
      {:batch_error, success_count, error} ->
        {:error, {:partial_success, success_count, [error]}}
    end
  end

  # Private batch write helper - optimized for the common success case
  defp fast_batch_write(_buffer, [], count), do: count
  defp fast_batch_write(buffer, [event | rest], count) do
    case RingBuffer.write(buffer, event) do
      :ok -> fast_batch_write(buffer, rest, count + 1)
      {:error, reason} -> throw({:batch_error, count, {:error, reason}})
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
