defmodule ElixirScope.Query.EngineTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.Query.Engine
  alias ElixirScope.Storage.EventStore
  alias ElixirScope.Events
  
  setup do
    # Start EventStore for testing
    {:ok, store} = EventStore.start_link(name: :"test_query_store_#{:rand.uniform(10000)}")
    
    # Create test events
    base_time = System.monotonic_time(:millisecond)
    pid1 = spawn(fn -> :ok end)
    pid2 = spawn(fn -> :ok end)
    
    events = [
      create_test_event(%{pid: pid1, event_type: :function_entry, timestamp: base_time}),
      create_test_event(%{pid: pid1, event_type: :function_exit, timestamp: base_time + 100}),
      create_test_event(%{pid: pid2, event_type: :function_entry, timestamp: base_time + 200}),
      create_test_event(%{pid: pid2, event_type: :message_send, timestamp: base_time + 300}),
      create_test_event(%{pid: pid1, event_type: :state_change, timestamp: base_time + 400})
    ]
    
    # Store events
    Enum.each(events, fn event ->
      EventStore.store_event(store, event)
    end)
    
    on_exit(fn ->
      if Process.alive?(store) do
        GenServer.stop(store)
      end
    end)
    
    %{store: store, events: events, pid1: pid1, pid2: pid2, base_time: base_time}
  end
  
  describe "query optimization" do
    test "analyzes query to determine optimal index strategy", %{store: _store} do
      # Test temporal index selection
      temporal_strategy = Engine.analyze_query([since: 1000, until: 2000])
      assert temporal_strategy.index_type == :temporal
      assert temporal_strategy.estimated_cost < 100
      
      # Test process index selection
      process_strategy = Engine.analyze_query([pid: self()])
      assert process_strategy.index_type == :process
      assert process_strategy.estimated_cost < 50
      
      # Test event type index selection
      event_type_strategy = Engine.analyze_query([event_type: :function_entry])
      assert event_type_strategy.index_type == :event_type
      assert event_type_strategy.estimated_cost < 75
      
      # Test full scan fallback
      full_scan_strategy = Engine.analyze_query([custom_filter: :some_value])
      assert full_scan_strategy.index_type == :full_scan
      assert full_scan_strategy.estimated_cost > 100
    end
    
    test "selects optimal index for complex queries", %{store: _store, pid1: pid1} do
      # Query with multiple filters should select most selective index
      complex_query = [
        pid: pid1,
        event_type: :function_entry,
        since: 1000,
        until: 2000
      ]
      
      strategy = Engine.analyze_query(complex_query)
      
      # Should select process index as most selective for single PID
      assert strategy.index_type == :process
      assert strategy.post_filters == [:event_type, :temporal]
    end
    
    test "estimates query cost accurately", %{store: store} do
      # Cost should increase with broader queries
      narrow_query = [pid: self()]
      broad_query = [event_type: :function_entry]
      very_broad_query = []
      
      narrow_cost = Engine.estimate_query_cost(store, narrow_query)
      broad_cost = Engine.estimate_query_cost(store, broad_query)
      very_broad_cost = Engine.estimate_query_cost(store, very_broad_query)
      
      assert narrow_cost < broad_cost
      assert broad_cost < very_broad_cost
    end
  end
  
  describe "query execution" do
    test "executes optimized queries efficiently", %{store: store, pid1: pid1} do
      query = [pid: pid1, limit: 10]
      
      start_time = System.monotonic_time(:microsecond)
      {:ok, results} = Engine.execute_query(store, query)
      end_time = System.monotonic_time(:microsecond)
      
      execution_time = end_time - start_time
      
      # Should execute in less than 10000µs (10ms) - adjusted for test environment
      assert execution_time < 10000
      assert length(results) <= 10
      assert Enum.all?(results, &(&1.pid == pid1))
    end
    
    test "applies filters in optimal order", %{store: store, pid1: pid1, base_time: base_time} do
      # Complex query that should apply most selective filters first
      query = [
        pid: pid1,
        event_type: :function_entry,
        since: base_time - 100,
        until: base_time + 500
      ]
      
      {:ok, results} = Engine.execute_query(store, query)
      
      # Should return only function_entry events for pid1 in time range
      assert length(results) == 1
      result = List.first(results)
      assert result.pid == pid1
      assert result.event_type == :function_entry
      assert result.timestamp >= base_time - 100
      assert result.timestamp <= base_time + 500
    end
    
    test "handles empty result sets gracefully", %{store: store} do
      # Query that should return no results
      non_existent_pid = spawn(fn -> :ok end)
      query = [pid: non_existent_pid]
      
      {:ok, results} = Engine.execute_query(store, query)
      assert results == []
    end
    
    test "maintains result ordering", %{store: store} do
      query = [limit: 10]
      
      {:ok, results} = Engine.execute_query(store, query)
      
      # Results should be ordered by timestamp
      timestamps = Enum.map(results, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps)
    end
  end
  
  describe "query performance monitoring" do
    test "tracks query execution metrics", %{store: store} do
      query = [event_type: :function_entry]
      
      {:ok, results, metrics} = Engine.execute_query_with_metrics(store, query)
      
      assert is_map(metrics)
      assert Map.has_key?(metrics, :execution_time_us)
      assert Map.has_key?(metrics, :index_used)
      assert Map.has_key?(metrics, :events_scanned)
      assert Map.has_key?(metrics, :events_returned)
      assert Map.has_key?(metrics, :filter_efficiency)
      
      assert metrics.events_returned == length(results)
      assert metrics.execution_time_us > 0
    end
    
    test "identifies performance bottlenecks", %{store: store} do
      # Inefficient query that should trigger warnings
      inefficient_query = [custom_filter: fn _event -> true end]
      
      {:ok, _results, metrics} = Engine.execute_query_with_metrics(store, inefficient_query)
      
      assert metrics.index_used == :full_scan
      assert metrics.filter_efficiency < 0.5  # Low efficiency due to full scan
      assert Map.has_key?(metrics, :optimization_suggestions)
    end
    
    test "provides optimization suggestions", %{store: store} do
      # Query that could be optimized
      suboptimal_query = [event_type: :function_entry, limit: 1000]
      
      suggestions = Engine.get_optimization_suggestions(store, suboptimal_query)
      
      assert is_list(suggestions)
      assert length(suggestions) > 0
      
      # Should suggest adding more selective filters
      assert Enum.any?(suggestions, fn suggestion ->
        String.contains?(suggestion, "Consider adding")
      end)
    end
  end
  
  describe "integration with EventStore" do
    test "leverages EventStore indexes efficiently", %{store: store, pid1: pid1} do
      # Query that should use process index
      query = [pid: pid1]
      
      {:ok, _results, metrics} = Engine.execute_query_with_metrics(store, query)
      
      assert metrics.index_used == :process
      assert metrics.events_scanned < 10  # Should scan fewer events due to index
    end
    
    test "falls back gracefully when indexes unavailable", %{store: store} do
      # Query with unsupported filter should fall back to full scan
      query = [custom_attribute: :some_value]
      
      {:ok, results, metrics} = Engine.execute_query_with_metrics(store, query)
      
      assert metrics.index_used == :full_scan
      assert is_list(results)  # Should still return results
    end
  end
  
  describe "error handling" do
    test "handles invalid queries gracefully" do
      invalid_queries = [
        [pid: "not_a_pid"],
        [timestamp: "not_a_number"],
        [limit: -1],
        [since: "invalid_time"]
      ]
      
      Enum.each(invalid_queries, fn query ->
        result = Engine.execute_query(:invalid_store, query)
        assert {:error, _reason} = result
      end)
    end
    
    test "handles store unavailability" do
      query = [event_type: :function_entry]
      
      result = Engine.execute_query(:non_existent_store, query)
      assert {:error, :store_unavailable} = result
    end
  end
  
  # Helper functions
  defp create_test_event(overrides) do
    call_id = "test_call_#{:rand.uniform(1_000_000)}"
    
    base_event = %Events.FunctionEntry{
      call_id: call_id,
      timestamp: System.monotonic_time(:millisecond),
      wall_time: DateTime.utc_now(),
      pid: self(),
      module: TestModule,
      function: :test_function,
      arity: 0,
      args: [],
      correlation_id: "test_corr_#{:rand.uniform(1_000_000)}"
    }
    
    # Add event_type for compatibility with tests
    base_event = Map.put(base_event, :event_type, :function_entry)
    base_event = Map.put(base_event, :id, base_event.call_id)
    
    Map.merge(base_event, overrides)
  end
end 