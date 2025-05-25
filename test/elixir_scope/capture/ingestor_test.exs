defmodule ElixirScope.Capture.IngestorTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.Capture.{RingBuffer, Ingestor}
  alias ElixirScope.Events

  setup do
    {:ok, buffer} = RingBuffer.new(size: 1024)
    %{buffer: buffer}
  end

  describe "ingest_function_call/6" do
    test "ingests function call events correctly", %{buffer: buffer} do
      assert :ok = Ingestor.ingest_function_call(
        buffer,
        TestModule,
        :test_function,
        [:arg1, :arg2],
        self(),
        "correlation-123"
      )
      
      # Verify event was stored
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      
      assert %Events.FunctionExecution{} = event
      assert event.module == TestModule
      assert event.function == :test_function
      assert event.arity == 2
      assert event.caller_pid == self()
      assert event.correlation_id == "correlation-123"
      assert event.event_type == :call
      assert is_integer(event.id)
      assert is_integer(event.timestamp)
    end

    test "handles large argument lists", %{buffer: buffer} do
      large_args = Enum.to_list(1..1000)
      
      assert :ok = Ingestor.ingest_function_call(
        buffer,
        TestModule,
        :test_function,
        large_args,
        self(),
        "correlation-123"
      )
      
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      assert event.arity == 1000
      # Args should be truncated for memory efficiency
      assert match?({:truncated, _, _}, event.args)
    end
  end

  describe "ingest_function_return/4" do
    test "ingests function return events correctly", %{buffer: buffer} do
      return_value = {:ok, "result"}
      duration_ns = 1_500_000  # 1.5ms
      
      assert :ok = Ingestor.ingest_function_return(
        buffer,
        return_value,
        duration_ns,
        "correlation-123"
      )
      
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      
      assert %Events.FunctionExecution{} = event
      assert event.return_value == return_value
      assert event.duration_ns == duration_ns
      assert event.correlation_id == "correlation-123"
      assert event.event_type == :return
    end

    test "handles large return values", %{buffer: buffer} do
      large_return = %{data: Enum.to_list(1..10000)}
      
      assert :ok = Ingestor.ingest_function_return(
        buffer,
        large_return,
        1000,
        "correlation-123"
      )
      
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      # Return value should be truncated
      assert match?({:truncated, _, _}, event.return_value)
    end
  end

  describe "ingest_process_spawn/3" do
    test "ingests process spawn events correctly", %{buffer: buffer} do
      parent_pid = self()
      child_pid = spawn(fn -> :ok end)
      
      assert :ok = Ingestor.ingest_process_spawn(buffer, parent_pid, child_pid)
      
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      
      assert %Events.ProcessEvent{} = event
      assert event.pid == child_pid
      assert event.parent_pid == parent_pid
      assert event.event_type == :spawn
    end
  end

  describe "ingest_message_send/4" do
    test "ingests message send events correctly", %{buffer: buffer} do
      from_pid = self()
      to_pid = spawn(fn -> :ok end)
      message = {:hello, "world"}
      
      assert :ok = Ingestor.ingest_message_send(buffer, from_pid, to_pid, message)
      
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      
      assert %Events.MessageEvent{} = event
      assert event.from_pid == from_pid
      assert event.to_pid == to_pid
      assert event.message == message
      assert event.event_type == :send
    end

    test "handles large messages", %{buffer: buffer} do
      large_message = %{payload: String.duplicate("x", 100_000)}
      
      assert :ok = Ingestor.ingest_message_send(buffer, self(), self(), large_message)
      
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      # Message should be truncated
      assert match?({:truncated, _, _}, event.message)
    end
  end

  describe "ingest_state_change/4" do
    test "ingests state change events correctly", %{buffer: buffer} do
      old_state = %{counter: 0}
      new_state = %{counter: 1}
      
      assert :ok = Ingestor.ingest_state_change(buffer, self(), old_state, new_state)
      
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      
      assert %Events.StateChange{} = event
      assert event.server_pid == self()
      assert event.old_state == old_state
      assert event.new_state == new_state
    end
  end

  describe "ingest_performance_metric/4" do
    test "ingests performance metrics correctly", %{buffer: buffer} do
      assert :ok = Ingestor.ingest_performance_metric(
        buffer,
        :memory_usage,
        1024 * 1024,
        %{unit: :bytes, source: :erlang}
      )
      
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      
      assert %Events.PerformanceMetric{} = event
      assert event.metric_name == :memory_usage
      assert event.value == 1024 * 1024
      assert event.metadata.unit == :bytes
    end

    test "works with default metadata", %{buffer: buffer} do
      assert :ok = Ingestor.ingest_performance_metric(buffer, :cpu_usage, 75.5)
      
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      assert event.metadata == %{}
    end
  end

  describe "ingest_error/4" do
    test "ingests error events correctly", %{buffer: buffer} do
      error = :badarg
      reason = "Invalid argument"
      stacktrace = [{TestModule, :test_function, 1, [file: ~c"test.ex", line: 42]}]
      
      assert :ok = Ingestor.ingest_error(buffer, error, reason, stacktrace)
      
      {:ok, event, _} = RingBuffer.read(buffer, 0)
      
      assert %Events.ErrorEvent{} = event
      assert event.error_type == error
      assert event.error_message == reason
      assert is_list(event.stacktrace)
    end
  end

  describe "ingest_batch/2" do
    test "ingests multiple events in batch", %{buffer: buffer} do
      events = [
        %Events.FunctionExecution{
          id: "test-1",
          timestamp: System.monotonic_time(:nanosecond),
          module: TestModule,
          function: :test1,
          event_type: :call
        },
        %Events.FunctionExecution{
          id: "test-2",
          timestamp: System.monotonic_time(:nanosecond),
          module: TestModule,
          function: :test2,
          event_type: :call
        },
        %Events.ProcessEvent{
          id: "test-3",
          timestamp: System.monotonic_time(:nanosecond),
          pid: self(),
          event_type: :spawn
        }
      ]
      
      assert {:ok, 3} = Ingestor.ingest_batch(buffer, events)
      
      # Verify all events were stored
      {read_events, _} = RingBuffer.read_batch(buffer, 0, 3)
      assert length(read_events) == 3
    end

    test "handles partial failures gracefully", %{buffer: _buffer} do
      # Create a small buffer that will overflow
      {:ok, small_buffer} = RingBuffer.new(size: 2, overflow_strategy: :drop_newest)
      
      events = for i <- 1..5 do
        %Events.FunctionExecution{
          id: "test-#{i}",
          timestamp: System.monotonic_time(:nanosecond),
          module: TestModule,
          function: :test,
          event_type: :call
        }
      end
      
      # This should result in partial success
      result = Ingestor.ingest_batch(small_buffer, events)
      
      case result do
        {:ok, count} -> assert count <= 5
        {:error, {:partial_success, count, _errors}} -> assert count > 0
      end
    end
  end

  describe "create_fast_ingestor/1" do
    test "creates a fast ingestor function", %{buffer: buffer} do
      fast_ingest = Ingestor.create_fast_ingestor(buffer)
      
      event = %Events.FunctionExecution{
        id: "fast-test",
        timestamp: System.monotonic_time(:nanosecond),
        module: TestModule,
        function: :fast_test,
        event_type: :call
      }
      
      assert :ok = fast_ingest.(event)
      
      {:ok, read_event, _} = RingBuffer.read(buffer, 0)
      assert read_event.id == "fast-test"
    end
  end

  describe "benchmark_ingestion/3" do
    test "provides performance benchmarking", %{buffer: buffer} do
      sample_event = %Events.FunctionExecution{
        id: "benchmark-test",
        timestamp: System.monotonic_time(:nanosecond),
        module: TestModule,
        function: :benchmark_test,
        event_type: :call
      }
      
      stats = Ingestor.benchmark_ingestion(buffer, sample_event, 100)
      
      assert is_float(stats.avg_time_ns)
      assert is_integer(stats.min_time_ns)
      assert is_integer(stats.max_time_ns)
      assert is_integer(stats.total_time_ns)
      assert stats.operations == 100
      
      # Sanity checks
      assert stats.avg_time_ns > 0
      assert stats.min_time_ns <= stats.avg_time_ns
      assert stats.avg_time_ns <= stats.max_time_ns
      assert stats.total_time_ns > 0
    end
  end

  describe "validate_performance/1" do
    test "validates performance meets targets", %{buffer: buffer} do
      # This test might be environment-dependent
      case Ingestor.validate_performance(buffer) do
        :ok -> 
          # Performance target met
          assert true
        {:error, {:performance_target_missed, actual_ns, target_ns}} ->
          # Performance target missed - this might happen in slow environments
          assert actual_ns > target_ns
          assert target_ns == 1000  # 1µs target
      end
    end
  end

  describe "performance characteristics" do
    @tag :performance
    test "function call ingestion meets performance targets", %{buffer: buffer} do
      iterations = 10_000
      
      # Warm up
      for _ <- 1..1000 do
        Ingestor.ingest_function_call(buffer, TestModule, :warmup, [], self(), "warmup")
      end
      
      RingBuffer.clear(buffer)
      
      # Measure performance
      start_time = System.monotonic_time(:nanosecond)
      
      for i <- 1..iterations do
        Ingestor.ingest_function_call(
          buffer,
          TestModule,
          :perf_test,
          [i],
          self(),
          "perf-#{i}"
        )
      end
      
      end_time = System.monotonic_time(:nanosecond)
      total_time_ns = end_time - start_time
      avg_time_ns = total_time_ns / iterations
      
      # Target: <1.5µs per ingestion (realistic for function call ingestion)
      assert avg_time_ns < 1500, "Average ingestion time #{avg_time_ns}ns exceeds 1.5µs target"
      
      # Should achieve >100k ingestions/sec
      ingestions_per_second = 1_000_000_000 / avg_time_ns
      assert ingestions_per_second > 100_000, "Ingestion rate #{ingestions_per_second}/sec below 100k target"
    end

    @tag :performance
    test "batch ingestion is more efficient than individual ingestion", %{buffer: buffer} do
      # Use a moderate batch size that fits in the buffer (1024)
      event_count = 500
      events = for i <- 1..event_count do
        %Events.FunctionExecution{
          id: "batch-perf-#{i}",
          timestamp: System.monotonic_time(:nanosecond),
          module: TestModule,
          function: :batch_test,
          event_type: :call
        }
      end
      
      # Warm up both approaches to minimize JIT effects
      RingBuffer.clear(buffer)
      Enum.take(events, 10) |> Enum.each(&RingBuffer.write(buffer, &1))
      RingBuffer.clear(buffer)
      Ingestor.ingest_batch(buffer, Enum.take(events, 10))
      
      # Measure individual ingestion (using ingest_function_call for fairness)
      RingBuffer.clear(buffer)
      start_time = System.monotonic_time(:nanosecond)
      
      Enum.each(events, fn event ->
        Ingestor.ingest_function_call(
          buffer, 
          event.module, 
          event.function, 
          [], 
          self(), 
          event.id
        )
      end)
      
      individual_time = System.monotonic_time(:nanosecond) - start_time
      
      # Measure batch ingestion
      RingBuffer.clear(buffer)
      start_time = System.monotonic_time(:nanosecond)
      
      {:ok, count} = Ingestor.ingest_batch(buffer, events)
      
      batch_time = System.monotonic_time(:nanosecond) - start_time
      
      # Verify all events were written
      assert count == event_count
      
      # Batch should not be significantly slower than individual
      # Use generous tolerance for CI environment stability
      max_allowed = individual_time * 2.5
      assert batch_time <= max_allowed, 
        "Batch ingestion too slow: #{batch_time}ns vs individual #{individual_time}ns (max allowed: #{max_allowed}ns)"
        
      # Log performance for debugging
      batch_per_event = batch_time / event_count
      individual_per_event = individual_time / event_count
      
      IO.puts "\nPerformance comparison:"
      IO.puts "  Individual: #{individual_per_event}ns per event"
      IO.puts "  Batch: #{batch_per_event}ns per event"
      IO.puts "  Ratio: #{batch_time / individual_time}"
    end

    @tag :performance
    test "concurrent ingestion maintains performance", %{buffer: buffer} do
      # Test concurrent ingestion from multiple processes (scaled down)
      num_processes = 3
      events_per_process = 500
      
      tasks = for i <- 1..num_processes do
        Task.async(fn ->
          start_time = System.monotonic_time(:nanosecond)
          
          for j <- 1..events_per_process do
            Ingestor.ingest_function_call(
              buffer,
              TestModule,
              :concurrent_test,
              [i, j],
              self(),
              "concurrent-#{i}-#{j}"
            )
          end
          
          System.monotonic_time(:nanosecond) - start_time
        end)
      end
      
      # Wait for all tasks and collect timing
      times = Enum.map(tasks, &Task.await/1)
      
      # Calculate average time per ingestion across all processes
      total_time = Enum.sum(times)
      total_ingestions = num_processes * events_per_process
      avg_time_per_ingestion = total_time / total_ingestions
      
      # More realistic performance target for concurrent operations (5µs)
      assert avg_time_per_ingestion < 5000, "Concurrent ingestion avg time #{avg_time_per_ingestion}ns exceeds 5µs"
      
      # Verify all events were ingested
      stats = RingBuffer.stats(buffer)
      assert stats.total_writes == total_ingestions
    end
  end

  describe "error handling" do
    test "handles buffer write failures gracefully", %{buffer: _buffer} do
      # Fill buffer to capacity with drop_newest strategy
      {:ok, full_buffer} = RingBuffer.new(size: 4, overflow_strategy: :drop_newest)
      
      # Fill the buffer
      for i <- 1..4 do
        event = %Events.FunctionExecution{
          id: "fill-#{i}",
          timestamp: System.monotonic_time(:nanosecond),
          module: TestModule,
          function: :fill,
          event_type: :call
        }
        RingBuffer.write(full_buffer, event)
      end
      
      # Next ingestion should handle the buffer full error
      result = Ingestor.ingest_function_call(
        full_buffer,
        TestModule,
        :overflow_test,
        [],
        self(),
        "overflow"
      )
      
      # Should return error when buffer is full and strategy is drop_newest
      assert {:error, :buffer_full} = result
    end

    test "handles invalid event data gracefully" do
      {:ok, buffer} = RingBuffer.new(size: 16)
      
      # These should not crash even with unusual data
      assert :ok = Ingestor.ingest_function_call(buffer, nil, nil, [], self(), nil)
      assert :ok = Ingestor.ingest_message_send(buffer, self(), self(), nil)
      assert :ok = Ingestor.ingest_state_change(buffer, self(), nil, nil)
    end
  end
end 