# test/elixir_scope/capture/temporal_storage_test.exs
defmodule ElixirScope.Capture.TemporalStorageTest do
  use ExUnit.Case
  
  # @moduletag :skip  # Enabled for TemporalStorage implementation
  use ExUnitProperties

  alias ElixirScope.Capture.TemporalStorage
  alias ElixirScope.Utils

  describe "temporal event storage with AST correlation" do
    test "stores events with temporal indexing and AST links" do
      {:ok, storage} = TemporalStorage.start_link()

      # Given: Events with temporal sequence and AST correlation
      events = [
        %{timestamp: 1000, ast_node_id: "node1", correlation_id: "corr1"},
        %{timestamp: 2000, ast_node_id: "node2", correlation_id: "corr2"},
        %{timestamp: 1500, ast_node_id: "node1", correlation_id: "corr3"}
      ]

      # When: We store them
      for event <- events do
        :ok = TemporalStorage.store_event(storage, event)
      end

      # Then: We can query by time range with AST correlation
      {:ok, range_events} = TemporalStorage.get_events_in_range(storage, 1000, 2000)
      assert length(range_events) == 3

      # Events should be temporally ordered
      timestamps = Enum.map(range_events, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps)
    end

    test "enables efficient temporal queries with AST filtering" do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Store events with different AST nodes
      events = [
        %{timestamp: 1000, ast_node_id: "node1", correlation_id: "corr1", data: %{type: :function_entry}},
        %{timestamp: 1100, ast_node_id: "node2", correlation_id: "corr2", data: %{type: :function_entry}},
        %{timestamp: 1200, ast_node_id: "node1", correlation_id: "corr3", data: %{type: :function_exit}},
        %{timestamp: 1300, ast_node_id: "node3", correlation_id: "corr4", data: %{type: :function_entry}}
      ]
      
      for event <- events do
        :ok = TemporalStorage.store_event(storage, event)
      end
      
      # Query events for specific AST node
      {:ok, node1_events} = TemporalStorage.get_events_for_ast_node(storage, "node1")
      assert length(node1_events) == 2
      assert Enum.all?(node1_events, &(&1.ast_node_id == "node1"))
      
      # Events should be ordered by timestamp
      timestamps = Enum.map(node1_events, & &1.timestamp)
      assert timestamps == [1000, 1200]
    end
  end

  describe "basic storage operations" do
    test "starts and stops storage process" do
      {:ok, storage} = TemporalStorage.start_link()
      assert Process.alive?(storage)
      
      # Can get initial stats
      {:ok, stats} = TemporalStorage.get_stats(storage)
      assert stats.total_events == 0
      assert is_integer(stats.memory_usage)
    end
    
    test "stores events with automatic timestamp generation" do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Event without timestamp should get one automatically
      event = %{ast_node_id: "node1", data: %{test: true}}
      :ok = TemporalStorage.store_event(storage, event)
      
      {:ok, all_events} = TemporalStorage.get_all_events(storage)
      assert length(all_events) == 1
      
      stored_event = hd(all_events)
      assert is_integer(stored_event.timestamp)
      assert stored_event.ast_node_id == "node1"
      assert stored_event.data == %{test: true}
    end
    
    test "handles events with minimal data" do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Minimal event
      event = %{timestamp: 1000}
      :ok = TemporalStorage.store_event(storage, event)
      
      {:ok, events} = TemporalStorage.get_all_events(storage)
      assert length(events) == 1
      
      stored_event = hd(events)
      assert stored_event.timestamp == 1000
      assert stored_event.ast_node_id == nil
      assert stored_event.correlation_id == nil
    end
  end

  describe "time-range queries" do
    setup do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Create events across different time periods
      events = [
        %{timestamp: 1000, ast_node_id: "node1", data: %{period: :early}},
        %{timestamp: 1500, ast_node_id: "node2", data: %{period: :early}},
        %{timestamp: 2000, ast_node_id: "node1", data: %{period: :middle}},
        %{timestamp: 2500, ast_node_id: "node3", data: %{period: :middle}},
        %{timestamp: 3000, ast_node_id: "node2", data: %{period: :late}},
        %{timestamp: 3500, ast_node_id: "node1", data: %{period: :late}}
      ]
      
      for event <- events do
        :ok = TemporalStorage.store_event(storage, event)
      end
      
      {:ok, storage: storage}
    end
    
    test "queries events in specific time ranges", %{storage: storage} do
      # Query early period
      {:ok, early_events} = TemporalStorage.get_events_in_range(storage, 1000, 1999)
      assert length(early_events) == 2
      assert Enum.all?(early_events, &(&1.data.period == :early))
      
      # Query middle period
      {:ok, middle_events} = TemporalStorage.get_events_in_range(storage, 2000, 2999)
      assert length(middle_events) == 2
      assert Enum.all?(middle_events, &(&1.data.period == :middle))
      
      # Query late period
      {:ok, late_events} = TemporalStorage.get_events_in_range(storage, 3000, 3999)
      assert length(late_events) == 2
      assert Enum.all?(late_events, &(&1.data.period == :late))
    end
    
    test "handles edge cases in time ranges", %{storage: storage} do
      # Empty range
      {:ok, empty_events} = TemporalStorage.get_events_in_range(storage, 5000, 6000)
      assert length(empty_events) == 0
      
      # Single point range
      {:ok, point_events} = TemporalStorage.get_events_in_range(storage, 2000, 2000)
      assert length(point_events) == 1
      assert hd(point_events).timestamp == 2000
      
      # Overlapping range
      {:ok, overlap_events} = TemporalStorage.get_events_in_range(storage, 1500, 2500)
      assert length(overlap_events) == 3
      timestamps = Enum.map(overlap_events, & &1.timestamp)
      assert timestamps == [1500, 2000, 2500]
    end
    
    test "maintains chronological ordering in results", %{storage: storage} do
      {:ok, all_events} = TemporalStorage.get_events_in_range(storage, 0, 9999)
      timestamps = Enum.map(all_events, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps)
      assert timestamps == [1000, 1500, 2000, 2500, 3000, 3500]
    end
  end

  describe "AST node correlation" do
    setup do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Events with different AST nodes and overlapping times
      events = [
        %{timestamp: 1000, ast_node_id: "function_def_1", correlation_id: "exec_1", data: %{action: :entry}},
        %{timestamp: 1100, ast_node_id: "function_def_2", correlation_id: "exec_2", data: %{action: :entry}},
        %{timestamp: 1200, ast_node_id: "function_def_1", correlation_id: "exec_1", data: %{action: :call}},
        %{timestamp: 1300, ast_node_id: "function_def_1", correlation_id: "exec_3", data: %{action: :entry}},
        %{timestamp: 1400, ast_node_id: "function_def_2", correlation_id: "exec_2", data: %{action: :exit}},
        %{timestamp: 1500, ast_node_id: "function_def_1", correlation_id: "exec_1", data: %{action: :exit}}
      ]
      
      for event <- events do
        :ok = TemporalStorage.store_event(storage, event)
      end
      
      {:ok, storage: storage}
    end
    
    test "retrieves events for specific AST nodes", %{storage: storage} do
      {:ok, func1_events} = TemporalStorage.get_events_for_ast_node(storage, "function_def_1")
      assert length(func1_events) == 4
      assert Enum.all?(func1_events, &(&1.ast_node_id == "function_def_1"))
      
      {:ok, func2_events} = TemporalStorage.get_events_for_ast_node(storage, "function_def_2")
      assert length(func2_events) == 2
      assert Enum.all?(func2_events, &(&1.ast_node_id == "function_def_2"))
      
      # Non-existent AST node
      {:ok, empty_events} = TemporalStorage.get_events_for_ast_node(storage, "nonexistent")
      assert length(empty_events) == 0
    end
    
    test "maintains temporal ordering for AST node events", %{storage: storage} do
      {:ok, func1_events} = TemporalStorage.get_events_for_ast_node(storage, "function_def_1")
      timestamps = Enum.map(func1_events, & &1.timestamp)
      assert timestamps == [1000, 1200, 1300, 1500]
      assert timestamps == Enum.sort(timestamps)
    end
  end

  describe "correlation ID tracking" do
    setup do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Events with correlation IDs representing execution flows
      events = [
        %{timestamp: 1000, ast_node_id: "node1", correlation_id: "flow_a", data: %{step: 1}},
        %{timestamp: 1100, ast_node_id: "node2", correlation_id: "flow_b", data: %{step: 1}},
        %{timestamp: 1200, ast_node_id: "node3", correlation_id: "flow_a", data: %{step: 2}},
        %{timestamp: 1300, ast_node_id: "node4", correlation_id: "flow_c", data: %{step: 1}},
        %{timestamp: 1400, ast_node_id: "node5", correlation_id: "flow_a", data: %{step: 3}},
        %{timestamp: 1500, ast_node_id: "node6", correlation_id: "flow_b", data: %{step: 2}}
      ]
      
      for event <- events do
        :ok = TemporalStorage.store_event(storage, event)
      end
      
      {:ok, storage: storage}
    end
    
    test "retrieves events for specific correlation IDs", %{storage: storage} do
      {:ok, flow_a_events} = TemporalStorage.get_events_for_correlation(storage, "flow_a")
      assert length(flow_a_events) == 3
      assert Enum.all?(flow_a_events, &(&1.correlation_id == "flow_a"))
      
      steps = Enum.map(flow_a_events, &(&1.data.step))
      assert steps == [1, 2, 3]
      
      {:ok, flow_b_events} = TemporalStorage.get_events_for_correlation(storage, "flow_b")
      assert length(flow_b_events) == 2
      assert Enum.all?(flow_b_events, &(&1.correlation_id == "flow_b"))
    end
    
    test "maintains temporal ordering for correlation events", %{storage: storage} do
      {:ok, flow_a_events} = TemporalStorage.get_events_for_correlation(storage, "flow_a")
      timestamps = Enum.map(flow_a_events, & &1.timestamp)
      assert timestamps == [1000, 1200, 1400]
      assert timestamps == Enum.sort(timestamps)
    end
  end

  describe "statistics and monitoring" do
    test "tracks storage statistics" do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Initial stats
      {:ok, initial_stats} = TemporalStorage.get_stats(storage)
      assert initial_stats.total_events == 0
      assert initial_stats.oldest_event == nil
      assert initial_stats.newest_event == nil
      assert is_integer(initial_stats.memory_usage)
      
      # Add some events
      events = [
        %{timestamp: 1000, ast_node_id: "node1"},
        %{timestamp: 2000, ast_node_id: "node2"},
        %{timestamp: 1500, ast_node_id: "node3"}
      ]
      
      for event <- events do
        :ok = TemporalStorage.store_event(storage, event)
      end
      
      # Updated stats
      {:ok, updated_stats} = TemporalStorage.get_stats(storage)
      assert updated_stats.total_events == 3
      assert updated_stats.oldest_event == 1000
      assert updated_stats.newest_event == 2000
      assert updated_stats.memory_usage > initial_stats.memory_usage
      assert updated_stats.events_table_size == 3
    end
    
    test "tracks memory usage accurately" do
      {:ok, storage} = TemporalStorage.start_link()
      
      {:ok, initial_stats} = TemporalStorage.get_stats(storage)
      initial_memory = initial_stats.memory_usage
      
      # Add events and check memory growth
      for i <- 1..100 do
        event = %{
          timestamp: i * 1000,
          ast_node_id: "node_#{i}",
          correlation_id: "corr_#{i}",
          data: %{large_data: String.duplicate("x", 100)}
        }
        :ok = TemporalStorage.store_event(storage, event)
      end
      
      {:ok, final_stats} = TemporalStorage.get_stats(storage)
      assert final_stats.memory_usage > initial_memory
      assert final_stats.total_events == 100
    end
  end

  describe "error handling and edge cases" do
    test "handles malformed events gracefully" do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Event with invalid timestamp should still work (gets auto-generated)
      :ok = TemporalStorage.store_event(storage, %{data: "test"})
      
      {:ok, events} = TemporalStorage.get_all_events(storage)
      assert length(events) == 1
      assert is_integer(hd(events).timestamp)
    end
    
    test "handles empty queries gracefully" do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Empty storage queries
      {:ok, empty_range} = TemporalStorage.get_events_in_range(storage, 1000, 2000)
      assert empty_range == []
      
      {:ok, empty_ast} = TemporalStorage.get_events_for_ast_node(storage, "nonexistent")
      assert empty_ast == []
      
      {:ok, empty_corr} = TemporalStorage.get_events_for_correlation(storage, "nonexistent")
      assert empty_corr == []
      
      {:ok, empty_all} = TemporalStorage.get_all_events(storage)
      assert empty_all == []
    end
    
    test "handles concurrent access" do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Simulate concurrent writes
      tasks = for i <- 1..50 do
        Task.async(fn ->
          event = %{
            timestamp: Utils.monotonic_timestamp() + i,
            ast_node_id: "node_#{rem(i, 5)}",
            correlation_id: "corr_#{rem(i, 3)}",
            data: %{task_id: i}
          }
          TemporalStorage.store_event(storage, event)
        end)
      end
      
      # Wait for all tasks to complete
      results = Task.await_many(tasks, 5000)
      assert Enum.all?(results, &(&1 == :ok))
      
      # Verify all events were stored
      {:ok, all_events} = TemporalStorage.get_all_events(storage)
      assert length(all_events) == 50
      
      # Verify temporal ordering is maintained
      timestamps = Enum.map(all_events, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps)
    end
  end

  describe "Cinema Debugger foundation" do
    test "supports time-travel debugging primitives" do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Simulate a function execution sequence
      execution_events = [
        %{timestamp: 1000, ast_node_id: "function_def_main", correlation_id: "exec_1", data: %{event: :entry, function: :main}},
        %{timestamp: 1100, ast_node_id: "function_def_helper", correlation_id: "exec_2", data: %{event: :entry, function: :helper}},
        %{timestamp: 1200, ast_node_id: "variable_assignment_x", correlation_id: "exec_2", data: %{event: :assignment, var: :x, value: 42}},
        %{timestamp: 1300, ast_node_id: "function_def_helper", correlation_id: "exec_2", data: %{event: :exit, function: :helper, return: 42}},
        %{timestamp: 1400, ast_node_id: "variable_assignment_y", correlation_id: "exec_1", data: %{event: :assignment, var: :y, value: 42}},
        %{timestamp: 1500, ast_node_id: "function_def_main", correlation_id: "exec_1", data: %{event: :exit, function: :main, return: :ok}}
      ]
      
      for event <- execution_events do
        :ok = TemporalStorage.store_event(storage, event)
      end
      
      # Time-travel query: What was happening at timestamp 1250?
      {:ok, active_events} = TemporalStorage.get_events_in_range(storage, 1200, 1300)
      assert length(active_events) == 2
      
      # Execution flow reconstruction: What happened in exec_2?
      {:ok, exec_2_flow} = TemporalStorage.get_events_for_correlation(storage, "exec_2")
      assert length(exec_2_flow) == 3
      
      flow_events = Enum.map(exec_2_flow, &(&1.data.event))
      assert flow_events == [:entry, :assignment, :exit]
      
      # AST node activity: What happened to function_def_main?
      {:ok, main_activity} = TemporalStorage.get_events_for_ast_node(storage, "function_def_main")
      assert length(main_activity) == 2
      
      main_events = Enum.map(main_activity, &(&1.data.event))
      assert main_events == [:entry, :exit]
    end
    
    test "enables state reconstruction at specific points in time" do
      {:ok, storage} = TemporalStorage.start_link()
      
      # Simulate state changes over time
      state_events = [
        %{timestamp: 1000, ast_node_id: "state_init", data: %{state: %{counter: 0, status: :init}}},
        %{timestamp: 1100, ast_node_id: "state_update", data: %{state: %{counter: 1, status: :running}}},
        %{timestamp: 1200, ast_node_id: "state_update", data: %{state: %{counter: 2, status: :running}}},
        %{timestamp: 1300, ast_node_id: "state_update", data: %{state: %{counter: 3, status: :running}}},
        %{timestamp: 1400, ast_node_id: "state_final", data: %{state: %{counter: 3, status: :complete}}}
      ]
      
      for event <- state_events do
        :ok = TemporalStorage.store_event(storage, event)
      end
      
      # Reconstruct state at different points in time
      {:ok, early_state} = TemporalStorage.get_events_in_range(storage, 0, 1150)
      assert length(early_state) == 2
      
      {:ok, mid_state} = TemporalStorage.get_events_in_range(storage, 0, 1250)
      assert length(mid_state) == 3
      
      {:ok, final_state} = TemporalStorage.get_events_in_range(storage, 0, 1500)
      assert length(final_state) == 5
    end
  end

  # TODO: Re-enable when ExUnitProperties is updated and we want property-based testing
  # property "temporal storage maintains chronological ordering" do
  #   check all events <- Generators.temporal_event_sequence(min_length: 10) do
  #     {:ok, storage} = TemporalStorage.start_link()
  #
  #     # Store events in random order
  #     shuffled_events = Enum.shuffle(events)
  #     for event <- shuffled_events do
  #       TemporalStorage.store_event(storage, event)
  #     end
  #
  #     # Retrieved events should be chronologically ordered
  #     {:ok, retrieved} = TemporalStorage.get_all_events(storage)
  #     timestamps = Enum.map(retrieved, & &1.timestamp)
  #     assert timestamps == Enum.sort(timestamps)
  #   end
  # end
end
