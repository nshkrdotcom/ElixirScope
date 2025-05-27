defmodule ElixirScope.Capture.InstrumentationRuntimeTemporalIntegrationTest do
  use ExUnit.Case
  require Logger
  
  alias ElixirScope.Capture.{InstrumentationRuntime, TemporalBridge, TemporalStorage, RingBuffer}
  alias ElixirScope.Utils

  describe "InstrumentationRuntime TemporalBridge integration" do
    setup do
      # Start TemporalStorage
      {:ok, storage} = TemporalStorage.start_link()
      
      # Start TemporalBridge
      {:ok, bridge} = TemporalBridge.start_link(temporal_storage: storage)
      
      # Register the bridge for automatic forwarding
      :ok = TemporalBridge.register_as_handler(bridge)
      
      # Create a test buffer for InstrumentationRuntime
      {:ok, buffer} = RingBuffer.new(size: 1024)
      Application.put_env(:elixir_scope, :main_buffer, buffer)
      
      # Initialize InstrumentationRuntime context
      InstrumentationRuntime.initialize_context()
      
      on_exit(fn ->
        TemporalBridge.unregister_handler()
        InstrumentationRuntime.clear_context()
        Application.delete_env(:elixir_scope, :main_buffer)
        if Process.alive?(bridge), do: GenServer.stop(bridge)
        if Process.alive?(storage), do: GenServer.stop(storage)
      end)
      
      %{bridge: bridge, storage: storage, buffer: buffer}
    end

    @tag :debug
    test "debug: TemporalBridge registration and basic forwarding", %{bridge: bridge} do
      # Verify bridge is registered
      {:ok, registered_bridge} = TemporalBridge.get_registered_bridge()
      assert registered_bridge == bridge
      
      # Test direct event forwarding
      test_event = %{
        event_type: :test_event,
        timestamp: System.monotonic_time(:nanosecond),
        correlation_id: "debug_correlation",
        ast_node_id: "debug_ast_node",
        data: %{test: true}
      }
      
      :ok = TemporalBridge.correlate_event(bridge, test_event)
      
      # Force buffer flush to ensure event is stored
      :ok = TemporalBridge.flush_buffer(bridge)
      
      # Allow time for async processing
      Process.sleep(50)
      
      # Verify event was stored - check the nested data structure
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, "debug_ast_node")
      assert length(events) == 1
      
      stored_event = hd(events)
      assert stored_event.data.event_type == :test_event
      assert stored_event.data.correlation_id == "debug_correlation"
      assert stored_event.data.ast_node_id == "debug_ast_node"
    end

    test "AST function entry events are automatically forwarded to TemporalBridge", %{bridge: bridge} do
      # Given: AST-correlated function entry
      correlation_id = "test_correlation_#{System.unique_integer()}"
      ast_node_id = "test_ast_node_#{System.unique_integer()}"
      
      # When: We report an AST function entry
      :ok = InstrumentationRuntime.report_ast_function_entry_with_node_id(
        TestModule, 
        :test_function, 
        [:arg1, :arg2], 
        correlation_id, 
        ast_node_id
      )
      
      # Allow time for async forwarding and flush buffer
      Process.sleep(100)
      :ok = TemporalBridge.flush_buffer(bridge)
      
      # Then: Event should be available in TemporalBridge
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, ast_node_id)
      
      assert length(events) > 0
      
      function_entry_event = Enum.find(events, fn event ->
        event.data.event_type == :function_entry and
        event.data.correlation_id == correlation_id
      end)
      
      refute is_nil(function_entry_event)
      assert function_entry_event.data.data.module == TestModule
      assert function_entry_event.data.data.function == :test_function
      assert function_entry_event.data.data.ast_node_id == ast_node_id
    end

    test "AST function exit events are automatically forwarded to TemporalBridge", %{bridge: bridge} do
      # Given: AST-correlated function exit
      correlation_id = "test_correlation_#{System.unique_integer()}"
      ast_node_id = "test_ast_node_#{System.unique_integer()}"
      
      # When: We report an AST function exit
      :ok = InstrumentationRuntime.report_ast_function_exit_with_node_id(
        correlation_id, 
        :ok, 
        1000, 
        ast_node_id
      )
      
      # Allow time for async forwarding and flush buffer
      Process.sleep(50)
      :ok = TemporalBridge.flush_buffer(bridge)
      
      # Then: Event should be available in TemporalBridge
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, ast_node_id)
      
      assert length(events) > 0
      
      function_exit_event = Enum.find(events, fn event ->
        event.data.event_type == :function_exit and
        event.data.correlation_id == correlation_id
      end)
      
      refute is_nil(function_exit_event)
      assert function_exit_event.data.data.return_value == :ok
      assert function_exit_event.data.data.duration_ns == 1000
      assert function_exit_event.data.data.ast_node_id == ast_node_id
    end

    test "AST variable snapshots are automatically forwarded to TemporalBridge", %{bridge: bridge} do
      # Given: AST-correlated variable snapshot
      correlation_id = "test_correlation_#{System.unique_integer()}"
      ast_node_id = "test_ast_node_#{System.unique_integer()}"
      variables = %{x: 42, y: "test", z: [1, 2, 3]}
      
      # When: We report an AST variable snapshot
      :ok = InstrumentationRuntime.report_ast_variable_snapshot(
        correlation_id, 
        variables, 
        15, 
        ast_node_id
      )
      
      # Allow time for async forwarding and flush buffer
      Process.sleep(50)
      :ok = TemporalBridge.flush_buffer(bridge)
      
      # Then: Event should be available in TemporalBridge
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, ast_node_id)
      
      assert length(events) > 0
      
      variable_event = Enum.find(events, fn event ->
        event.data.event_type == :local_variable_snapshot and
        event.data.correlation_id == correlation_id
      end)
      
      refute is_nil(variable_event)
      assert variable_event.data.data.variables == variables
      assert variable_event.data.data.line == 15
      assert variable_event.data.data.ast_node_id == ast_node_id
    end

    test "temporal correlation works with execution flow", %{bridge: bridge} do
      # Given: A sequence of AST-correlated events
      correlation_id = "flow_correlation_#{System.unique_integer()}"
      ast_node_id = "flow_ast_node_#{System.unique_integer()}"
      
      # When: We simulate a function execution flow
      :ok = InstrumentationRuntime.report_ast_function_entry_with_node_id(
        FlowModule, :flow_function, [], correlation_id, ast_node_id
      )
      
      Process.sleep(10)  # Small delay to ensure ordering
      
      :ok = InstrumentationRuntime.report_ast_variable_snapshot(
        correlation_id, %{step: 1}, 10, ast_node_id
      )
      
      Process.sleep(10)
      
      :ok = InstrumentationRuntime.report_ast_variable_snapshot(
        correlation_id, %{step: 2, result: 42}, 15, ast_node_id
      )
      
      Process.sleep(10)
      
      :ok = InstrumentationRuntime.report_ast_function_exit_with_node_id(
        correlation_id, 42, 5000, ast_node_id
      )
      
      # Allow time for async forwarding and flush buffer
      Process.sleep(100)
      :ok = TemporalBridge.flush_buffer(bridge)
      
      # Then: All events should be available and chronologically ordered
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, ast_node_id)
      
      assert length(events) == 4
      
      # Verify chronological ordering
      timestamps = Enum.map(events, &(&1.timestamp))
      assert timestamps == Enum.sort(timestamps)
      
      # Verify event types in order
      event_types = Enum.map(events, &(&1.data.event_type))
      assert event_types == [:function_entry, :local_variable_snapshot, :local_variable_snapshot, :function_exit]
    end

    test "integration works when TemporalBridge is not registered", %{bridge: bridge} do
      # Given: TemporalBridge is unregistered
      TemporalBridge.unregister_handler()
      
      # When: We report events (should not crash)
      result = InstrumentationRuntime.report_ast_function_entry_with_node_id(
        TestModule, :test_function, [], "test_correlation", "test_ast_node"
      )
      
      # Then: Should complete successfully without forwarding
      assert result == :ok
      
      # And: No events should be in TemporalBridge
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, "test_ast_node")
      assert events == []
    end

    test "integration handles TemporalBridge errors gracefully" do
      # When: We report events (should not crash even if TemporalBridge fails)
      result = InstrumentationRuntime.report_ast_function_entry_with_node_id(
        TestModule, :test_function, [], "test_correlation", "test_ast_node"
      )
      
      # Then: Should complete successfully even if forwarding fails
      assert result == :ok
    end

    test "performance impact is minimal with temporal forwarding", %{bridge: bridge} do
      # Given: A correlation setup
      correlation_id = "perf_correlation_#{System.unique_integer()}"
      ast_node_id = "perf_ast_node_#{System.unique_integer()}"
      
      # When: We measure performance with temporal forwarding
      {time_us, _result} = :timer.tc(fn ->
        for i <- 1..100 do
          InstrumentationRuntime.report_ast_function_entry_with_node_id(
            TestModule, :perf_test, [i], "#{correlation_id}_#{i}", "#{ast_node_id}_#{i}"
          )
        end
      end)
      
      # Then: Performance should be reasonable (< 10ms for 100 events)
      avg_time_us = time_us / 100
      assert avg_time_us < 100  # Less than 100 microseconds per event on average
      
      # Allow time for async processing
      Process.sleep(200)
      
      # Verify some events were processed
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, "#{ast_node_id}_1")
      assert length(events) > 0
    end
  end

  describe "Cinema Debugger foundation" do
    setup do
      # Start TemporalStorage
      {:ok, storage} = TemporalStorage.start_link()
      
      # Start TemporalBridge
      {:ok, bridge} = TemporalBridge.start_link(temporal_storage: storage)
      
      # Register the bridge
      :ok = TemporalBridge.register_as_handler(bridge)
      
      # Create a test buffer for InstrumentationRuntime
      {:ok, buffer} = RingBuffer.new(size: 1024)
      Application.put_env(:elixir_scope, :main_buffer, buffer)
      
      # Initialize InstrumentationRuntime context
      InstrumentationRuntime.initialize_context()
      
      on_exit(fn ->
        TemporalBridge.unregister_handler()
        InstrumentationRuntime.clear_context()
        Application.delete_env(:elixir_scope, :main_buffer)
        if Process.alive?(bridge), do: GenServer.stop(bridge)
        if Process.alive?(storage), do: GenServer.stop(storage)
      end)
      
      %{bridge: bridge, storage: storage, buffer: buffer}
    end

    test "can query live execution state during runtime", %{bridge: bridge} do
      # Given: A running execution with multiple correlation points
      correlation_id = "live_correlation_#{System.unique_integer()}"
      ast_node_id = "live_ast_node_#{System.unique_integer()}"
      
      # When: We simulate live execution
      :ok = InstrumentationRuntime.report_ast_function_entry_with_node_id(
        LiveModule, :live_function, [:param1], correlation_id, ast_node_id
      )
      
      Process.sleep(10)
      
      :ok = InstrumentationRuntime.report_ast_variable_snapshot(
        correlation_id, %{state: :processing, data: [1, 2, 3]}, 20, ast_node_id
      )
      
      Process.sleep(50)  # Allow async processing
      :ok = TemporalBridge.flush_buffer(bridge)  # Ensure events are stored
      
      # Then: We can query the current execution state
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, ast_node_id)
      assert length(events) >= 2
      
      # Can reconstruct current state
      current_time = Utils.monotonic_timestamp()
      {:ok, state} = TemporalBridge.reconstruct_state_at(bridge, current_time)
      
      # Should have function state
      assert Map.has_key?(state, "Elixir.LiveModule.live_function")
      assert state["Elixir.LiveModule.live_function"][:status] == :active
    end

    test "supports time-travel debugging queries", %{bridge: bridge} do
      # Given: A completed execution flow
      correlation_id = "timetravel_correlation_#{System.unique_integer()}"
      ast_node_id = "timetravel_ast_node_#{System.unique_integer()}"
      
      _start_time = Utils.monotonic_timestamp()
      
      :ok = InstrumentationRuntime.report_ast_function_entry_with_node_id(
        TimeTravelModule, :time_function, [], correlation_id, ast_node_id
      )
      
      Process.sleep(10)
      _mid_time = Utils.monotonic_timestamp()
      
      :ok = InstrumentationRuntime.report_ast_variable_snapshot(
        correlation_id, %{checkpoint: :middle, value: 100}, 25, ast_node_id
      )
      
      Process.sleep(10)
      
      :ok = InstrumentationRuntime.report_ast_function_exit_with_node_id(
        correlation_id, 200, 20000, ast_node_id
      )
      
      _end_time = Utils.monotonic_timestamp()
      Process.sleep(50)  # Allow async processing
      :ok = TemporalBridge.flush_buffer(bridge)  # Ensure events are stored
      
      # Then: We can query state at different points in time
      
      # State at current time - should include all events
      current_time = Utils.monotonic_timestamp()
      {:ok, final_state} = TemporalBridge.reconstruct_state_at(bridge, current_time)
      
      # Should have function state (either active or completed)
      assert Map.has_key?(final_state, "Elixir.TimeTravelModule.time_function")
      
      # Should include variable snapshot data
      assert final_state[:checkpoint] == :middle
      assert final_state[:value] == 100
      
      # Function should be completed since we reported function_exit
      assert final_state["Elixir.TimeTravelModule.time_function"][:status] == :completed
    end
  end
end 