defmodule ElixirScope.Capture.TemporalBridgeTest do
  use ExUnit.Case
  
  alias ElixirScope.Capture.{TemporalBridge, TemporalStorage}
  alias ElixirScope.Utils

  describe "basic bridge operations" do
    test "starts and stops bridge process" do
      {:ok, bridge} = TemporalBridge.start_link()
      assert Process.alive?(bridge)
      
      # Can get initial stats
      {:ok, stats} = TemporalBridge.get_stats(bridge)
      assert stats.events_processed == 0
      assert stats.events_buffered == 0
      assert is_integer(stats.created_at)
    end
    
    test "starts with custom temporal storage" do
      {:ok, storage} = TemporalStorage.start_link()
      {:ok, bridge} = TemporalBridge.start_link(temporal_storage: storage)
      
      # Verify bridge uses the provided storage
      {:ok, stats} = TemporalBridge.get_stats(bridge)
      assert Map.has_key?(stats, :temporal_storage)
    end
    
    test "starts with custom configuration" do
      {:ok, bridge} = TemporalBridge.start_link(
        buffer_size: 500,
        flush_interval: 50,
        enable_correlation_cache: false
      )
      
      {:ok, stats} = TemporalBridge.get_stats(bridge)
      assert stats.config.buffer_size == 500
      assert stats.config.flush_interval == 50
      assert stats.config.enable_correlation_cache == false
    end
  end

  describe "event correlation and buffering" do
    setup do
      {:ok, bridge} = TemporalBridge.start_link(buffer_size: 5, flush_interval: 1000)
      {:ok, bridge: bridge}
    end
    
    test "correlates and buffers events", %{bridge: bridge} do
      event = %{
        timestamp: 1000,
        correlation_id: "corr_123",
        ast_node_id: "node_456",
        event_type: :function_entry,
        data: %{module: TestModule, function: :test_function}
      }
      
      :ok = TemporalBridge.correlate_event(bridge, event)
      
      # Event should be buffered
      {:ok, stats} = TemporalBridge.get_stats(bridge)
      assert stats.events_processed == 1
      assert stats.events_buffered == 1
    end
    
    test "enriches events with bridge metadata", %{bridge: bridge} do
      event = %{
        correlation_id: "corr_123",
        event_type: :function_entry
      }
      
      :ok = TemporalBridge.correlate_event(bridge, event)
      :ok = TemporalBridge.flush_buffer(bridge)
      
      # Retrieve the event and check enrichment
      {:ok, events} = TemporalBridge.get_events_for_correlation(bridge, "corr_123")
      assert length(events) == 1
      
      enriched_event = hd(events)
      assert is_integer(enriched_event.timestamp)
      assert is_integer(enriched_event.data.bridge_id)  # bridge_id is an integer (Utils.generate_id)
      assert is_integer(enriched_event.data.bridge_timestamp)
      assert enriched_event.data.temporal_correlation == true
    end
    
    test "automatically flushes when buffer is full", %{bridge: bridge} do
      # Add events to fill the buffer (buffer_size: 5)
      for i <- 1..5 do
        event = %{
          correlation_id: "corr_#{i}",
          event_type: :function_entry,
          data: %{step: i}
        }
        :ok = TemporalBridge.correlate_event(bridge, event)
      end
      
      # Buffer should be flushed automatically
      {:ok, stats} = TemporalBridge.get_stats(bridge)
      assert stats.events_processed == 5
      assert stats.events_buffered == 0  # Buffer should be empty after flush
      assert stats.buffer_flushes == 1
    end
    
    test "manual buffer flush", %{bridge: bridge} do
      event = %{
        correlation_id: "corr_manual",
        event_type: :function_entry
      }
      
      :ok = TemporalBridge.correlate_event(bridge, event)
      
      # Manually flush buffer
      :ok = TemporalBridge.flush_buffer(bridge)
      
      {:ok, stats} = TemporalBridge.get_stats(bridge)
      assert stats.events_buffered == 0
      assert stats.buffer_flushes == 1
    end
  end

  describe "temporal queries" do
    setup do
      {:ok, bridge} = TemporalBridge.start_link(flush_interval: 1000)
      
      # Add test events
      events = [
        %{timestamp: 1000, correlation_id: "corr_1", ast_node_id: "node_1", event_type: :function_entry},
        %{timestamp: 1500, correlation_id: "corr_2", ast_node_id: "node_2", event_type: :function_entry},
        %{timestamp: 2000, correlation_id: "corr_1", ast_node_id: "node_1", event_type: :function_exit},
        %{timestamp: 2500, correlation_id: "corr_3", ast_node_id: "node_3", event_type: :function_entry},
        %{timestamp: 3000, correlation_id: "corr_2", ast_node_id: "node_2", event_type: :function_exit}
      ]
      
      for event <- events do
        :ok = TemporalBridge.correlate_event(bridge, event)
      end
      
      # Flush to storage
      :ok = TemporalBridge.flush_buffer(bridge)
      
      {:ok, bridge: bridge}
    end
    
    test "gets events in time range", %{bridge: bridge} do
      {:ok, events} = TemporalBridge.get_events_in_range(bridge, 1000, 2000)
      assert length(events) == 3
      
      timestamps = Enum.map(events, & &1.timestamp)
      assert timestamps == [1000, 1500, 2000]
    end
    
    test "gets events for specific AST node", %{bridge: bridge} do
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, "node_1")
      assert length(events) == 2
      
      assert Enum.all?(events, &(&1.ast_node_id == "node_1"))
      
      event_types = Enum.map(events, &(&1.data.event_type))
      assert event_types == [:function_entry, :function_exit]
    end
    
    test "gets events for specific correlation ID", %{bridge: bridge} do
      {:ok, events} = TemporalBridge.get_events_for_correlation(bridge, "corr_2")
      assert length(events) == 2
      
      assert Enum.all?(events, &(&1.correlation_id == "corr_2"))
      
      timestamps = Enum.map(events, & &1.timestamp)
      assert timestamps == [1500, 3000]
    end
    
    test "handles empty query results", %{bridge: bridge} do
      {:ok, events} = TemporalBridge.get_events_in_range(bridge, 5000, 6000)
      assert events == []
      
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, "nonexistent")
      assert events == []
      
      {:ok, events} = TemporalBridge.get_events_for_correlation(bridge, "nonexistent")
      assert events == []
    end
  end

  describe "Cinema Debugger primitives" do
    setup do
      {:ok, bridge} = TemporalBridge.start_link(flush_interval: 1000)
      
      # Create a realistic execution sequence
      execution_events = [
        %{timestamp: 1000, correlation_id: "exec_1", ast_node_id: "main_func", event_type: :function_entry, data: %{module: MyApp, function: :main}},
        %{timestamp: 1100, correlation_id: "exec_2", ast_node_id: "helper_func", event_type: :function_entry, data: %{module: MyApp, function: :helper}},
        %{timestamp: 1200, correlation_id: "exec_2", ast_node_id: "var_assign", event_type: :state_change, data: %{state: %{x: 42}}},
        %{timestamp: 1300, correlation_id: "exec_2", ast_node_id: "helper_func", event_type: :function_exit, data: %{return_value: 42}},
        %{timestamp: 1400, correlation_id: "exec_1", ast_node_id: "var_assign_2", event_type: :state_change, data: %{state: %{y: 42}}},
        %{timestamp: 1500, correlation_id: "exec_1", ast_node_id: "main_func", event_type: :function_exit, data: %{return_value: :ok}}
      ]
      
      for event <- execution_events do
        :ok = TemporalBridge.correlate_event(bridge, event)
      end
      
      :ok = TemporalBridge.flush_buffer(bridge)
      
      {:ok, bridge: bridge, execution_events: execution_events}
    end
    
    test "reconstructs state at specific timestamp", %{bridge: bridge} do
      # Reconstruct state at timestamp 1250 (after helper function entry but before helper exit)
      {:ok, state} = TemporalBridge.reconstruct_state_at(bridge, 1250)
      
      # Should have both functions in the reconstructed state (Elixir prefixes module names)
      assert Map.has_key?(state, "Elixir.MyApp.main")
      assert Map.has_key?(state, "Elixir.MyApp.helper")
      assert state["Elixir.MyApp.main"][:status] == :active
      assert state["Elixir.MyApp.helper"][:status] == :active  # Still active at 1250, exits at 1300
      
      # Should have state changes
      assert state[:x] == 42
    end
    
    test "traces execution path for correlation", %{bridge: bridge} do
      target_event = %{correlation_id: "exec_2"}
      
      {:ok, execution_path} = TemporalBridge.trace_execution_path(bridge, target_event)
      assert length(execution_path) == 3
      
      # Should be ordered by timestamp
      timestamps = Enum.map(execution_path, & &1.timestamp)
      assert timestamps == [1100, 1200, 1300]
      
      # Should trace the helper function execution
      event_types = Enum.map(execution_path, &(&1.data.event_type))
      assert event_types == [:function_entry, :state_change, :function_exit]
    end
    
    test "gets active AST nodes in time range", %{bridge: bridge} do
      {:ok, ast_nodes} = TemporalBridge.get_active_ast_nodes(bridge, 1150, 1350)
      
      # Should include nodes active during this time window
      assert "helper_func" in ast_nodes
      assert "var_assign" in ast_nodes
      assert length(ast_nodes) >= 2
    end
    
    test "handles Cinema Debugger queries with no correlation ID", %{bridge: bridge} do
      target_event = %{event_type: :function_entry}  # No correlation_id
      
      {:error, :no_correlation_id} = TemporalBridge.trace_execution_path(bridge, target_event)
    end
  end

  describe "InstrumentationRuntime integration" do
    test "registers and unregisters as temporal handler" do
      # Clean up any existing registration first
      TemporalBridge.unregister_handler()
      
      {:ok, bridge} = TemporalBridge.start_link()
      
      # Initially no bridge registered
      {:error, :not_registered} = TemporalBridge.get_registered_bridge()
      
      # Register bridge
      :ok = TemporalBridge.register_as_handler(bridge)
      {:ok, registered_bridge} = TemporalBridge.get_registered_bridge()
      assert registered_bridge == bridge
      
      # Unregister bridge
      :ok = TemporalBridge.unregister_handler()
      {:error, :not_registered} = TemporalBridge.get_registered_bridge()
    end
    
    test "integration with InstrumentationRuntime event flow" do
      {:ok, bridge} = TemporalBridge.start_link(flush_interval: 1000)
      :ok = TemporalBridge.register_as_handler(bridge)
      
      # Simulate InstrumentationRuntime sending events
      runtime_event = %{
        timestamp: Utils.monotonic_timestamp(),
        correlation_id: "runtime_corr_123",
        ast_node_id: "runtime_node_456",
        event_type: :function_entry,
        data: %{
          module: TestModule,
          function: :test_function,
          args: [1, 2, 3],
          source: :instrumentation_runtime
        }
      }
      
      :ok = TemporalBridge.correlate_event(bridge, runtime_event)
      :ok = TemporalBridge.flush_buffer(bridge)
      
      # Verify event was stored with correlation
      {:ok, events} = TemporalBridge.get_events_for_correlation(bridge, "runtime_corr_123")
      assert length(events) == 1
      
      stored_event = hd(events)
      assert stored_event.ast_node_id == "runtime_node_456"
      assert stored_event.data.data.source == :instrumentation_runtime
      assert stored_event.data.temporal_correlation == true
    end
  end

  describe "performance and statistics" do
    test "tracks comprehensive statistics" do
      {:ok, bridge} = TemporalBridge.start_link(
        buffer_size: 3,
        enable_correlation_cache: true,
        flush_interval: 1000
      )
      
      # Add some events
      for i <- 1..5 do
        event = %{
          correlation_id: "perf_corr_#{i}",
          ast_node_id: "perf_node_#{rem(i, 3)}",
          event_type: :function_entry
        }
        :ok = TemporalBridge.correlate_event(bridge, event)
      end
      
      {:ok, stats} = TemporalBridge.get_stats(bridge)
      
      # Bridge statistics
      assert stats.events_processed == 5
      assert stats.buffer_flushes >= 1  # Should have auto-flushed
      assert is_integer(stats.created_at)
      
      # TemporalStorage statistics
      assert Map.has_key?(stats, :temporal_storage)
      assert stats.temporal_storage.total_events >= 3  # At least some events stored
      
      # Configuration
      assert stats.config.buffer_size == 3
      assert stats.config.enable_correlation_cache == true
    end
    
    test "handles high-volume event processing" do
      {:ok, bridge} = TemporalBridge.start_link(
        buffer_size: 100,
        flush_interval: 50  # Fast flush for testing
      )
      
      # Generate many events quickly
      events = for i <- 1..500 do
        %{
          timestamp: Utils.monotonic_timestamp() + i,
          correlation_id: "volume_corr_#{rem(i, 10)}",
          ast_node_id: "volume_node_#{rem(i, 5)}",
          event_type: :function_entry,
          data: %{iteration: i}
        }
      end
      
      # Send all events
      for event <- events do
        :ok = TemporalBridge.correlate_event(bridge, event)
      end
      
      # Wait for processing and flush
      Process.sleep(100)
      :ok = TemporalBridge.flush_buffer(bridge)
      
      {:ok, stats} = TemporalBridge.get_stats(bridge)
      assert stats.events_processed == 500
      assert stats.temporal_storage.total_events == 500
    end
  end

  describe "error handling and edge cases" do
    test "handles events without timestamps" do
      {:ok, bridge} = TemporalBridge.start_link(flush_interval: 1000)
      
      event = %{
        correlation_id: "no_timestamp",
        event_type: :function_entry
      }
      
      :ok = TemporalBridge.correlate_event(bridge, event)
      :ok = TemporalBridge.flush_buffer(bridge)
      
      {:ok, events} = TemporalBridge.get_events_for_correlation(bridge, "no_timestamp")
      assert length(events) == 1
      
      stored_event = hd(events)
      assert is_integer(stored_event.timestamp)
    end
    
    test "handles events with minimal data" do
      {:ok, bridge} = TemporalBridge.start_link(flush_interval: 1000)
      
      minimal_event = %{event_type: :unknown}
      
      :ok = TemporalBridge.correlate_event(bridge, minimal_event)
      :ok = TemporalBridge.flush_buffer(bridge)
      
      {:ok, stats} = TemporalBridge.get_stats(bridge)
      assert stats.events_processed == 1
      assert stats.temporal_storage.total_events == 1
    end
    
    test "handles concurrent event correlation" do
      {:ok, bridge} = TemporalBridge.start_link(
        buffer_size: 1000,
        flush_interval: 1000
      )
      
      # Simulate concurrent event correlation
      tasks = for i <- 1..50 do
        Task.async(fn ->
          event = %{
            timestamp: Utils.monotonic_timestamp() + i,
            correlation_id: "concurrent_corr_#{i}",
            ast_node_id: "concurrent_node_#{rem(i, 5)}",
            event_type: :function_entry,
            data: %{task_id: i}
          }
          TemporalBridge.correlate_event(bridge, event)
        end)
      end
      
      # Wait for all tasks to complete
      results = Task.await_many(tasks, 5000)
      assert Enum.all?(results, &(&1 == :ok))
      
      # Flush and verify all events were processed
      :ok = TemporalBridge.flush_buffer(bridge)
      
      {:ok, stats} = TemporalBridge.get_stats(bridge)
      assert stats.events_processed == 50
      assert stats.temporal_storage.total_events == 50
    end
    
    test "graceful degradation when TemporalStorage fails" do
      # This test would require mocking TemporalStorage failures
      # For now, we'll test that the bridge doesn't crash on errors
      {:ok, bridge} = TemporalBridge.start_link(flush_interval: 1000)
      
      # Normal operation should work
      event = %{correlation_id: "test", event_type: :function_entry}
      :ok = TemporalBridge.correlate_event(bridge, event)
      
      # Bridge should still be alive
      assert Process.alive?(bridge)
    end
  end

  describe "Cinema Debugger integration scenarios" do
    test "supports time-travel debugging workflow" do
      {:ok, bridge} = TemporalBridge.start_link(flush_interval: 1000)
      
      # Simulate a debugging scenario: function call with error
      debug_events = [
        %{timestamp: 1000, correlation_id: "debug_session", ast_node_id: "main_entry", event_type: :function_entry, data: %{function: :problematic_function}},
        %{timestamp: 1100, correlation_id: "debug_session", ast_node_id: "var_init", event_type: :state_change, data: %{state: %{counter: 0}}},
        %{timestamp: 1200, correlation_id: "debug_session", ast_node_id: "loop_start", event_type: :state_change, data: %{state: %{counter: 1}}},
        %{timestamp: 1300, correlation_id: "debug_session", ast_node_id: "loop_iteration", event_type: :state_change, data: %{state: %{counter: 2}}},
        %{timestamp: 1400, correlation_id: "debug_session", ast_node_id: "error_point", event_type: :error, data: %{error: :division_by_zero}}
      ]
      
      for event <- debug_events do
        :ok = TemporalBridge.correlate_event(bridge, event)
      end
      
      :ok = TemporalBridge.flush_buffer(bridge)
      
      # Time-travel debugging: What was the state just before the error?
      {:ok, state_before_error} = TemporalBridge.reconstruct_state_at(bridge, 1350)
      assert state_before_error[:counter] == 2
      
      # Execution trace: How did we get to the error?
      error_event = %{correlation_id: "debug_session"}
      {:ok, execution_path} = TemporalBridge.trace_execution_path(bridge, error_event)
      assert length(execution_path) == 5
      
      # Active nodes: What code was executing when the error occurred?
      {:ok, active_nodes} = TemporalBridge.get_active_ast_nodes(bridge, 1350, 1450)
      assert "error_point" in active_nodes
    end
    
    test "supports execution flow analysis" do
      {:ok, bridge} = TemporalBridge.start_link(flush_interval: 1000)
      
      # Simulate complex execution flow with multiple correlations
      flow_events = [
        # Main execution
        %{timestamp: 1000, correlation_id: "main_flow", ast_node_id: "main_start", event_type: :function_entry},
        %{timestamp: 1100, correlation_id: "main_flow", ast_node_id: "call_helper", event_type: :function_call},
        
        # Helper execution (spawned)
        %{timestamp: 1150, correlation_id: "helper_flow", ast_node_id: "helper_start", event_type: :function_entry},
        %{timestamp: 1200, correlation_id: "helper_flow", ast_node_id: "helper_work", event_type: :state_change},
        %{timestamp: 1250, correlation_id: "helper_flow", ast_node_id: "helper_end", event_type: :function_exit},
        
        # Main continues
        %{timestamp: 1300, correlation_id: "main_flow", ast_node_id: "process_result", event_type: :state_change},
        %{timestamp: 1400, correlation_id: "main_flow", ast_node_id: "main_end", event_type: :function_exit}
      ]
      
      for event <- flow_events do
        :ok = TemporalBridge.correlate_event(bridge, event)
      end
      
      :ok = TemporalBridge.flush_buffer(bridge)
      
      # Analyze main flow
      {:ok, main_events} = TemporalBridge.get_events_for_correlation(bridge, "main_flow")
      assert length(main_events) == 4  # main_start, call_helper, process_result, main_end
      
      # Analyze helper flow
      {:ok, helper_events} = TemporalBridge.get_events_for_correlation(bridge, "helper_flow")
      assert length(helper_events) == 3
      
      # Find concurrent execution period
      {:ok, concurrent_nodes} = TemporalBridge.get_active_ast_nodes(bridge, 1100, 1300)
      assert "call_helper" in concurrent_nodes
      assert "helper_start" in concurrent_nodes
      assert "helper_work" in concurrent_nodes
    end
  end
end 