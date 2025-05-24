defmodule ElixirScope.Capture.EventCorrelatorTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.Capture.EventCorrelator
  alias ElixirScope.Events
  alias ElixirScope.Utils
  
  describe "correlator lifecycle" do
    test "starts successfully with default configuration" do
      {:ok, pid} = EventCorrelator.start_link([])
      
      assert Process.alive?(pid)
      assert is_pid(pid)
      
      GenServer.stop(pid)
    end
    
    test "starts with custom configuration" do
      config = %{
        cleanup_interval_ms: 30000,
        correlation_ttl_ms: 300000,
        max_correlations: 10000
      }
      
      {:ok, pid} = EventCorrelator.start_link(config)
      
      assert Process.alive?(pid)
      
      # Verify configuration was applied
      state = EventCorrelator.get_state(pid)
      assert state.config.cleanup_interval_ms == 30000
      assert state.config.correlation_ttl_ms == 300000
      assert state.config.max_correlations == 10000
      
      GenServer.stop(pid)
    end
    
    test "initializes ETS tables for correlation state" do
      {:ok, pid} = EventCorrelator.start_link([])
      
      state = EventCorrelator.get_state(pid)
      
      # Verify ETS tables exist
      assert :ets.info(state.call_stacks_table) != :undefined
      assert :ets.info(state.message_registry_table) != :undefined
      assert :ets.info(state.correlation_metadata_table) != :undefined
      assert :ets.info(state.correlation_links_table) != :undefined
      
      GenServer.stop(pid)
    end
  end
  
  describe "function call correlation" do
    setup do
      {:ok, correlator} = EventCorrelator.start_link([])
      %{correlator: correlator}
    end
    
    test "correlates function entry events", %{correlator: correlator} do
      function_entry = %Events.FunctionExecution{
        id: "call-123",
        timestamp: Utils.monotonic_timestamp(),
        module: TestModule,
        function: :test_function,
        arity: 2,
        args: [:arg1, :arg2],
        event_type: :call,
        caller_pid: self(),
        correlation_id: nil
      }
      
      correlated = EventCorrelator.correlate_event(correlator, function_entry)
      
      assert %EventCorrelator.CorrelatedEvent{} = correlated
      assert correlated.event == function_entry
      assert correlated.correlation_type == :function_call
      assert correlated.correlation_id != nil
      assert correlated.parent_id == nil  # First call, no parent
      assert is_number(correlated.correlated_at)
      assert correlated.correlation_confidence == 1.0
    end
    
    test "correlates function exit events with matching entry", %{correlator: correlator} do
      # First, create an entry event
      function_entry = %Events.FunctionExecution{
        id: "call-123",
        timestamp: Utils.monotonic_timestamp(),
        module: TestModule,
        function: :test_function,
        arity: 2,
        args: [:arg1, :arg2],
        event_type: :call,
        caller_pid: self(),
        correlation_id: nil
      }
      
      entry_correlated = EventCorrelator.correlate_event(correlator, function_entry)
      
      # Now create matching exit event
      function_exit = %Events.FunctionExecution{
        id: "return-123",
        timestamp: Utils.monotonic_timestamp() + 1000,
        module: TestModule,
        function: :test_function,
        arity: 2,
        return_value: :ok,
        duration_ns: 1000,
        event_type: :return,
        caller_pid: self(),
        correlation_id: entry_correlated.correlation_id
      }
      
      exit_correlated = EventCorrelator.correlate_event(correlator, function_exit)
      
      assert exit_correlated.correlation_type == :function_return
      assert exit_correlated.correlation_id == entry_correlated.correlation_id
      assert {:completes, entry_correlated.correlation_id} in exit_correlated.links
    end
    
    test "maintains call stack for nested function calls", %{correlator: correlator} do
      pid = self()
      
      # Outer function call
      outer_call = %Events.FunctionExecution{
        id: "outer-call",
        timestamp: Utils.monotonic_timestamp(),
        module: OuterModule,
        function: :outer_function,
        event_type: :call,
        caller_pid: pid,
        correlation_id: nil
      }
      
      outer_correlated = EventCorrelator.correlate_event(correlator, outer_call)
      
      # Inner function call (nested)
      inner_call = %Events.FunctionExecution{
        id: "inner-call",
        timestamp: Utils.monotonic_timestamp() + 100,
        module: InnerModule,
        function: :inner_function,
        event_type: :call,
        caller_pid: pid,
        correlation_id: nil
      }
      
      inner_correlated = EventCorrelator.correlate_event(correlator, inner_call)
      
      # Inner call should have outer call as parent
      assert inner_correlated.parent_id == outer_correlated.correlation_id
      assert {:called_from, outer_correlated.correlation_id} in inner_correlated.links
    end
    
    test "handles function call stack per process separately", %{correlator: correlator} do
      pid1 = self()
      pid2 = spawn(fn -> Process.sleep(1000) end)
      
      # Function call in process 1
      call1 = %Events.FunctionExecution{
        id: "call1",
        timestamp: Utils.monotonic_timestamp(),
        module: TestModule,
        function: :function1,
        event_type: :call,
        caller_pid: pid1,
        correlation_id: nil
      }
      
      # Function call in process 2
      call2 = %Events.FunctionExecution{
        id: "call2",
        timestamp: Utils.monotonic_timestamp(),
        module: TestModule,
        function: :function2,
        event_type: :call,
        caller_pid: pid2,
        correlation_id: nil
      }
      
      correlated1 = EventCorrelator.correlate_event(correlator, call1)
      correlated2 = EventCorrelator.correlate_event(correlator, call2)
      
      # Both should be root calls (no parent) since they're in different processes
      assert correlated1.parent_id == nil
      assert correlated2.parent_id == nil
      assert correlated1.correlation_id != correlated2.correlation_id
      
      Process.exit(pid2, :kill)
    end
  end
  
  describe "message correlation" do
    setup do
      {:ok, correlator} = EventCorrelator.start_link([])
      %{correlator: correlator}
    end
    
    test "correlates message send events", %{correlator: correlator} do
      from_pid = self()
      to_pid = spawn(fn -> Process.sleep(1000) end)
      
      message_send = %Events.MessageEvent{
        id: "msg-send-123",
        timestamp: Utils.monotonic_timestamp(),
        from_pid: from_pid,
        to_pid: to_pid,
        message: {:hello, :world},
        event_type: :send
      }
      
      correlated = EventCorrelator.correlate_event(correlator, message_send)
      
      assert correlated.correlation_type == :message_send
      assert correlated.correlation_id != nil
      assert correlated.correlation_confidence == 1.0
      
      Process.exit(to_pid, :kill)
    end
    
    test "correlates message receive events with matching send", %{correlator: correlator} do
      from_pid = self()
      to_pid = spawn(fn -> Process.sleep(1000) end)
      
      # Message send event
      message_send = %Events.MessageEvent{
        id: "msg-send-123",
        timestamp: Utils.monotonic_timestamp(),
        from_pid: from_pid,
        to_pid: to_pid,
        message: {:hello, :world},
        event_type: :send
      }
      
      send_correlated = EventCorrelator.correlate_event(correlator, message_send)
      
      # Message receive event (simulated)
      message_receive = %Events.MessageEvent{
        id: "msg-recv-123",
        timestamp: Utils.monotonic_timestamp() + 500,
        from_pid: from_pid,
        to_pid: to_pid,
        message: {:hello, :world},
        event_type: :receive
      }
      
      recv_correlated = EventCorrelator.correlate_event(correlator, message_receive)
      
      assert recv_correlated.correlation_type == :message_receive
      assert recv_correlated.correlation_id == send_correlated.correlation_id
      assert {:receives, send_correlated.correlation_id} in recv_correlated.links
      
      Process.exit(to_pid, :kill)
    end
  end
  
  describe "batch correlation" do
    setup do
      {:ok, correlator} = EventCorrelator.start_link([])
      %{correlator: correlator}
    end
    
    test "correlates multiple events in batch efficiently", %{correlator: correlator} do
      events = for i <- 1..5 do
        %Events.FunctionExecution{
          id: "batch-event-#{i}",
          timestamp: Utils.monotonic_timestamp() + i,
          module: TestModule,
          function: :batch_function,
          event_type: :call,
          caller_pid: self(),
          correlation_id: nil
        }
      end
      
      correlated_events = EventCorrelator.correlate_batch(correlator, events)
      
      assert length(correlated_events) == 5
      
      # All events should be correlated
      Enum.each(correlated_events, fn correlated ->
        assert %EventCorrelator.CorrelatedEvent{} = correlated
        assert correlated.correlation_id != nil
        assert correlated.correlation_type == :function_call
      end)
      
      # First event should have no parent, others should be nested
      [first | rest] = correlated_events
      assert first.parent_id == nil
      
      Enum.each(rest, fn event ->
        assert event.parent_id != nil
      end)
    end
  end
  
  describe "correlation state management" do
    setup do
      {:ok, correlator} = EventCorrelator.start_link([])
      %{correlator: correlator}
    end
    
    test "tracks correlation metadata", %{correlator: correlator} do
      event = %Events.FunctionExecution{
        id: "metadata-test",
        timestamp: Utils.monotonic_timestamp(),
        module: TestModule,
        function: :metadata_function,
        event_type: :call,
        caller_pid: self(),
        correlation_id: nil
      }
      
      correlated = EventCorrelator.correlate_event(correlator, event)
      
      # Should be able to query correlation metadata
      metadata = EventCorrelator.get_correlation_metadata(correlator, correlated.correlation_id)
      
      assert metadata.correlation_id == correlated.correlation_id
      assert metadata.type == :function_call
      assert is_number(metadata.created_at)
      assert metadata.pid == self()
    end
    
    test "queries correlation chains", %{correlator: correlator} do
      pid = self()
      
      # Create a chain of function calls
      events = for i <- 1..3 do
        %Events.FunctionExecution{
          id: "chain-#{i}",
          timestamp: Utils.monotonic_timestamp() + i * 100,
          module: String.to_atom("Module#{i}"),
          function: String.to_atom("function#{i}"),
          event_type: :call,
          caller_pid: pid,
          correlation_id: nil
        }
      end
      
      correlated_events = Enum.map(events, &EventCorrelator.correlate_event(correlator, &1))
      
      # Get correlation chain from last event
      last_event = List.last(correlated_events)
      chain = EventCorrelator.get_correlation_chain(correlator, last_event.correlation_id)
      
      assert length(chain) >= 1
      assert last_event.correlation_id in Enum.map(chain, & &1.correlation_id)
    end
  end
  
  describe "correlation cleanup" do
    setup do
      config = %{
        cleanup_interval_ms: 100,  # Very fast cleanup for testing
        correlation_ttl_ms: 50     # Very short TTL for testing
      }
      {:ok, correlator} = EventCorrelator.start_link(config)
      %{correlator: correlator}
    end
    
    test "cleans up expired correlations automatically", %{correlator: correlator} do
      event = %Events.FunctionExecution{
        id: "cleanup-test",
        timestamp: Utils.monotonic_timestamp(),
        module: TestModule,
        function: :cleanup_function,
        event_type: :call,
        caller_pid: self(),
        correlation_id: nil
      }
      
      correlated = EventCorrelator.correlate_event(correlator, event)
      
      # Verify correlation exists
      metadata = EventCorrelator.get_correlation_metadata(correlator, correlated.correlation_id)
      assert metadata != nil
      
      # Wait for cleanup to occur
      Process.sleep(200)
      
      # Correlation should be cleaned up
      metadata_after = EventCorrelator.get_correlation_metadata(correlator, correlated.correlation_id)
      assert metadata_after == nil
    end
    
    test "manual cleanup removes expired correlations" do
      # Use a longer cleanup interval to prevent automatic cleanup interference
      config = %{
        cleanup_interval_ms: 300_000,  # Very long interval to prevent automatic cleanup
        correlation_ttl_ms: 50         # Very short TTL for testing
      }
      {:ok, correlator} = EventCorrelator.start_link(config)
      
      # Create several correlations
      events = for i <- 1..5 do
        %Events.FunctionExecution{
          id: "manual-cleanup-#{i}",
          timestamp: Utils.monotonic_timestamp(),
          module: TestModule,
          function: :manual_function,
          event_type: :call,
          caller_pid: self(),
          correlation_id: nil
        }
      end
      
      correlated_events = Enum.map(events, &EventCorrelator.correlate_event(correlator, &1))
      
      # Wait for them to expire
      Process.sleep(100)
      
      # Manual cleanup
      {:ok, cleaned_count} = EventCorrelator.cleanup_expired_correlations(correlator)
      
      assert cleaned_count >= 5
      
      # All correlations should be gone
      Enum.each(correlated_events, fn correlated ->
        metadata = EventCorrelator.get_correlation_metadata(correlator, correlated.correlation_id)
        assert metadata == nil
      end)
      
      GenServer.stop(correlator)
    end
  end
  
  describe "metrics and monitoring" do
    setup do
      {:ok, correlator} = EventCorrelator.start_link([])
      %{correlator: correlator}
    end
    
    test "tracks correlation metrics", %{correlator: correlator} do
      # Correlate some events to generate metrics
      for i <- 1..10 do
        event = %Events.FunctionExecution{
          id: "metrics-#{i}",
          timestamp: Utils.monotonic_timestamp(),
          module: TestModule,
          function: :metrics_function,
          event_type: :call,
          caller_pid: self(),
          correlation_id: nil
        }
        
        EventCorrelator.correlate_event(correlator, event)
      end
      
      metrics = EventCorrelator.get_metrics(correlator)
      
      assert metrics.total_correlations_created >= 10
      assert metrics.active_correlations >= 0
      assert metrics.function_correlations >= 10
      assert metrics.message_correlations >= 0
      assert is_number(metrics.average_correlation_time_ns)
    end
    
    test "reports health status", %{correlator: correlator} do
      health = EventCorrelator.health_check(correlator)
      
      assert health.status == :healthy
      assert is_number(health.active_correlations)
      assert is_number(health.memory_usage_bytes)
      assert is_number(health.uptime_ms)
      assert health.correlation_rate >= 0.0
    end
  end
  
  describe "error handling" do
    setup do
      {:ok, correlator} = EventCorrelator.start_link([])
      %{correlator: correlator}
    end
    
    test "handles malformed events gracefully", %{correlator: correlator} do
      malformed_event = %{}  # Missing required fields
      
      # Should not crash, return event with low confidence
      correlated = EventCorrelator.correlate_event(correlator, malformed_event)
      
      assert %EventCorrelator.CorrelatedEvent{} = correlated
      assert correlated.correlation_confidence < 1.0
      assert correlated.correlation_type == :unknown
    end
    
    test "handles large volumes without performance degradation", %{correlator: correlator} do
      start_time = System.monotonic_time()
      
      # Correlate many events
      for i <- 1..1000 do
        event = %Events.FunctionExecution{
          id: "volume-#{i}",
          timestamp: Utils.monotonic_timestamp(),
          module: TestModule,
          function: :volume_function,
          event_type: :call,
          caller_pid: self(),
          correlation_id: nil
        }
        
        EventCorrelator.correlate_event(correlator, event)
      end
      
      end_time = System.monotonic_time()
      total_time_ms = (end_time - start_time) / 1_000_000
      avg_time_per_event = total_time_ms / 1000
      
      # Should average less than 1ms per event
      assert avg_time_per_event < 1.0
    end
  end
  
  describe "graceful shutdown" do
    test "stops cleanly and cleans up ETS tables" do
      {:ok, correlator} = EventCorrelator.start_link([])
      
      state = EventCorrelator.get_state(correlator)
      
      # Verify tables exist
      assert :ets.info(state.call_stacks_table) != :undefined
      
      # Stop gracefully
      :ok = EventCorrelator.stop(correlator)
      
      # Wait for cleanup
      Process.sleep(100)
      
      # Tables should be cleaned up
      assert :ets.info(state.call_stacks_table) == :undefined
      
      refute Process.alive?(correlator)
    end
  end
end 