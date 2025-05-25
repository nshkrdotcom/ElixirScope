defmodule ElixirScope.Capture.AsyncWriterTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.Capture.AsyncWriter
  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Events
  alias ElixirScope.Utils
  
  describe "worker lifecycle" do
    test "starts successfully with configuration" do
      config = %{
        ring_buffer: nil,  # Will be set in setup
        batch_size: 10,
        poll_interval_ms: 50,
        max_backlog: 100
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      assert Process.alive?(pid)
      assert is_pid(pid)
      
      GenServer.stop(pid)
    end
    
    test "stores configuration in state" do
      config = %{
        ring_buffer: nil,
        batch_size: 25,
        poll_interval_ms: 100,
        max_backlog: 200
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      state = AsyncWriter.get_state(pid)
      assert state.config.batch_size == 25
      assert state.config.poll_interval_ms == 100
      assert state.config.max_backlog == 200
      
      GenServer.stop(pid)
    end
  end
  
  describe "event consumption from ring buffer" do
    setup do
      # Create a ring buffer with some test events
      {:ok, ring_buffer} = RingBuffer.new(size: 1024)
      
             # Add test events
       events = for i <- 1..5 do
         %Events.FunctionExecution{
           id: "test-event-#{i}",
           timestamp: Utils.monotonic_timestamp() + i,
           module: TestModule,
           function: :test_function,
           event_type: :call,
           args: [i],
           return_value: nil,
           duration_ns: nil,
           caller_pid: self(),
           correlation_id: nil
         }
       end
      
      Enum.each(events, fn event ->
        RingBuffer.write(ring_buffer, event)
      end)
      
      %{ring_buffer: ring_buffer, events: events}
    end
    
    test "reads events from ring buffer in batches", %{ring_buffer: ring_buffer} do
      config = %{
        ring_buffer: ring_buffer,
        batch_size: 3,
        poll_interval_ms: 10,
        max_backlog: 100
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      # Give it time to read some events
      Process.sleep(50)
      
      state = AsyncWriter.get_state(pid)
      assert state.events_read > 0
      assert state.events_processed >= 0
      
      GenServer.stop(pid)
    end
    
    test "processes events and updates position", %{ring_buffer: ring_buffer} do
      config = %{
        ring_buffer: ring_buffer,
        batch_size: 2,
        poll_interval_ms: 10,
        max_backlog: 100
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      # Give it time to process
      Process.sleep(100)
      
      state = AsyncWriter.get_state(pid)
      assert state.current_position > 0
      assert state.events_read > 0
      
      GenServer.stop(pid)
    end
  end
  
  describe "event enrichment" do
    test "enriches events with correlation metadata" do
      event = %Events.FunctionExecution{
        id: "test-event",
        timestamp: Utils.monotonic_timestamp(),
        module: TestModule,
        function: :test_function,
        event_type: :call,
        args: [],
        return_value: nil,
        duration_ns: nil,
        caller_pid: self(),
        correlation_id: nil
      }
      
      enriched = AsyncWriter.enrich_event(event)
      
      # Should add correlation metadata
      assert Map.has_key?(enriched, :correlation_id)
      assert Map.has_key?(enriched, :enriched_at)
      assert enriched.id == event.id
      assert enriched.module == event.module
    end
    
    test "enriches events with processing metadata" do
      event = %Events.FunctionExecution{
        id: "test-event",
        timestamp: Utils.monotonic_timestamp(),
        module: TestModule,
        function: :test_function,
        event_type: :call,
        args: [],
        return_value: nil,
        duration_ns: nil,
        caller_pid: self(),
        correlation_id: nil
      }
      
      enriched = AsyncWriter.enrich_event(event)
      
      assert Map.has_key?(enriched, :processed_by)
      assert Map.has_key?(enriched, :processing_order)
      assert enriched.processed_by == node()
    end
  end
  
  describe "batch processing" do
    setup do
      {:ok, ring_buffer} = RingBuffer.new(size: 1024)
      
      # Create a batch of events
             events = for i <- 1..10 do
         %Events.FunctionExecution{
           id: "batch-event-#{i}",
           timestamp: Utils.monotonic_timestamp() + i,
           module: TestModule,
           function: :batch_test,
           event_type: if(rem(i, 2) == 0, do: :call, else: :return),
           args: [i],
           return_value: nil,
           duration_ns: nil,
           caller_pid: self(),
           correlation_id: nil
         }
       end
      
      Enum.each(events, fn event ->
        RingBuffer.write(ring_buffer, event)
      end)
      
      %{ring_buffer: ring_buffer, events: events}
    end
    
    test "processes events in configurable batch sizes", %{ring_buffer: ring_buffer} do
      config = %{
        ring_buffer: ring_buffer,
        batch_size: 4,
        poll_interval_ms: 10,
        max_backlog: 100
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      # Wait for processing
      Process.sleep(100)
      
      state = AsyncWriter.get_state(pid)
      
      # Should have processed events in batches
      assert state.batches_processed > 0
      assert state.events_processed > 0
      
      GenServer.stop(pid)
    end
    
    test "handles empty batches gracefully", %{ring_buffer: ring_buffer} do
      # Consume all events first
      {events, _} = RingBuffer.read_batch(ring_buffer, 0, 100)
      assert length(events) > 0
      
      config = %{
        ring_buffer: ring_buffer,
        batch_size: 5,
        poll_interval_ms: 20,
        max_backlog: 100
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      # Start from end position, should get empty batches
      :ok = AsyncWriter.set_position(pid, length(events))
      
      Process.sleep(50)
      
      _state = AsyncWriter.get_state(pid)
      # Should handle empty batches without crashing
      assert Process.alive?(pid)
      
      GenServer.stop(pid)
    end
  end
  
  describe "error handling and resilience" do
    test "handles ring buffer read errors gracefully" do
      # Create config with invalid ring buffer
      config = %{
        ring_buffer: :invalid_buffer,
        batch_size: 5,
        poll_interval_ms: 10,
        max_backlog: 100
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      # Should not crash despite invalid buffer
      Process.sleep(50)
      assert Process.alive?(pid)
      
      state = AsyncWriter.get_state(pid)
      assert state.error_count > 0
      
      GenServer.stop(pid)
    end
    
    test "recovers from processing errors" do
      {:ok, ring_buffer} = RingBuffer.new(size: 1024)
      
      # Add a normal event
      event = %Events.FunctionExecution{
        id: "normal-event",
        timestamp: Utils.monotonic_timestamp(),
        module: TestModule,
        function: :test_function,
        event_type: :call,
        args: [],
        return_value: nil,
        duration_ns: nil,
        caller_pid: self(),
        correlation_id: nil
      }
      
      RingBuffer.write(ring_buffer, event)
      
      config = %{
        ring_buffer: ring_buffer,
        batch_size: 1,
        poll_interval_ms: 10,
        max_backlog: 100,
        simulate_errors: true  # Test mode flag
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      Process.sleep(100)
      
      # Should continue processing despite errors
      assert Process.alive?(pid)
      
      state = AsyncWriter.get_state(pid)
      assert state.events_read > 0
      
      GenServer.stop(pid)
    end
  end
  
  describe "performance and metrics" do
    test "tracks processing metrics" do
      {:ok, ring_buffer} = RingBuffer.new(size: 1024)
      
      config = %{
        ring_buffer: ring_buffer,
        batch_size: 5,
        poll_interval_ms: 10,
        max_backlog: 100
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      metrics = AsyncWriter.get_metrics(pid)
      
      assert is_map(metrics)
      assert Map.has_key?(metrics, :events_read)
      assert Map.has_key?(metrics, :events_processed)
      assert Map.has_key?(metrics, :batches_processed)
      assert Map.has_key?(metrics, :processing_rate)
      assert Map.has_key?(metrics, :error_count)
      
      GenServer.stop(pid)
    end
    
    test "calculates processing rate over time" do
      {:ok, ring_buffer} = RingBuffer.new(size: 1024)
      
      # Add many events
             for i <- 1..20 do
         event = %Events.FunctionExecution{
           id: "rate-test-#{i}",
           timestamp: Utils.monotonic_timestamp() + i,
           module: TestModule,
           function: :rate_test,
           event_type: :call,
           args: [],
           return_value: nil,
           duration_ns: nil,
           caller_pid: self(),
           correlation_id: nil
         }
         RingBuffer.write(ring_buffer, event)
       end
      
      config = %{
        ring_buffer: ring_buffer,
        batch_size: 5,
        poll_interval_ms: 5,
        max_backlog: 100
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      # Get initial metrics
      initial_metrics = AsyncWriter.get_metrics(pid)
      
      # Wait for processing
      Process.sleep(100)
      
      # Get final metrics
      final_metrics = AsyncWriter.get_metrics(pid)
      
      # Should show processing activity
      assert final_metrics.events_processed >= initial_metrics.events_processed
      assert final_metrics.processing_rate >= 0
      
      GenServer.stop(pid)
    end
  end
  
  describe "graceful shutdown" do
    test "stops processing and cleans up gracefully" do
      {:ok, ring_buffer} = RingBuffer.new(size: 1024)
      
      config = %{
        ring_buffer: ring_buffer,
        batch_size: 5,
        poll_interval_ms: 10,
        max_backlog: 100
      }
      
      {:ok, pid} = AsyncWriter.start_link(config)
      
      # Verify it's running
      assert Process.alive?(pid)
      
      # Stop gracefully
      :ok = AsyncWriter.stop(pid)
      
      # Should be stopped
      Process.sleep(50)
      refute Process.alive?(pid)
    end
  end
end 