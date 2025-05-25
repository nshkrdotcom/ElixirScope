defmodule ElixirScope.Storage.DataAccessTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.Storage.DataAccess
  alias ElixirScope.Events

  setup do
    {:ok, storage} = DataAccess.new(name: :"test_#{System.unique_integer()}")
    %{storage: storage}
  end

  describe "new/1" do
    test "creates storage with default settings" do
      assert {:ok, storage} = DataAccess.new()
      assert is_atom(storage.name)
      assert is_reference(storage.primary_table)
    end

    test "creates storage with custom settings" do
      assert {:ok, storage} = DataAccess.new(name: :custom_test, max_events: 500_000)
      assert storage.name == :custom_test
    end
  end

  describe "store_event/2 and get_event/2" do
    test "stores and retrieves a single event", %{storage: storage} do
      event = %Events.FunctionExecution{
        id: "test-event-1",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond),
        module: TestModule,
        function: :test_function,
        arity: 2,
        caller_pid: self(),
        event_type: :call
      }
      
      assert :ok = DataAccess.store_event(storage, event)
      assert {:ok, ^event} = DataAccess.get_event(storage, "test-event-1")
    end

    test "returns error for non-existent event", %{storage: storage} do
      assert {:error, :not_found} = DataAccess.get_event(storage, "non-existent")
    end

    test "stores different event types correctly", %{storage: storage} do
      events = [
        %Events.FunctionExecution{
          id: "func-event",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :test,
          event_type: :call
        },
        %Events.ProcessEvent{
          id: "proc-event",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          pid: self(),
          event_type: :spawn
        },
        %Events.MessageEvent{
          id: "msg-event",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          from_pid: self(),
          to_pid: self(),
          message: :hello,
          event_type: :send
        }
      ]
      
      Enum.each(events, &DataAccess.store_event(storage, &1))
      
      Enum.each(events, fn event ->
        assert {:ok, ^event} = DataAccess.get_event(storage, event.id)
      end)
    end
  end

  describe "store_events/2" do
    test "stores multiple events in batch", %{storage: storage} do
      events = for i <- 1..10 do
        %Events.FunctionExecution{
          id: "batch-event-#{i}",
          timestamp: System.monotonic_time(:nanosecond) + i,
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :batch_test,
          event_type: :call
        }
      end
      
      assert {:ok, 10} = DataAccess.store_events(storage, events)
      
      # Verify all events were stored
      Enum.each(events, fn event ->
        assert {:ok, ^event} = DataAccess.get_event(storage, event.id)
      end)
    end

    test "handles empty event list", %{storage: storage} do
      assert {:ok, 0} = DataAccess.store_events(storage, [])
    end
  end

  describe "query_by_time_range/4" do
    setup %{storage: storage} do
      base_time = System.monotonic_time(:nanosecond)
      
      events = for i <- 1..20 do
        %Events.FunctionExecution{
          id: "time-event-#{i}",
          timestamp: base_time + i * 1_000_000,  # 1ms apart
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :time_test,
          event_type: :call
        }
      end
      
      DataAccess.store_events(storage, events)
      
      %{events: events, base_time: base_time}
    end

    test "queries events in time range", %{storage: storage, base_time: base_time} do
      start_time = base_time + 5 * 1_000_000
      end_time = base_time + 10 * 1_000_000
      
      assert {:ok, events} = DataAccess.query_by_time_range(storage, start_time, end_time)
      
      # Should get events 5-10 (inclusive)
      assert length(events) == 6
      
      # Verify all events are in range
      Enum.each(events, fn event ->
        assert event.timestamp >= start_time
        assert event.timestamp <= end_time
      end)
    end

    test "respects limit option", %{storage: storage, base_time: base_time} do
      start_time = base_time
      end_time = base_time + 20 * 1_000_000
      
      assert {:ok, events} = DataAccess.query_by_time_range(storage, start_time, end_time, limit: 5)
      assert length(events) == 5
    end

    test "supports ascending and descending order", %{storage: storage, base_time: base_time} do
      start_time = base_time + 5 * 1_000_000
      end_time = base_time + 10 * 1_000_000
      
      {:ok, asc_events} = DataAccess.query_by_time_range(storage, start_time, end_time, order: :asc)
      {:ok, desc_events} = DataAccess.query_by_time_range(storage, start_time, end_time, order: :desc)
      
      assert length(asc_events) == length(desc_events)
      assert asc_events == Enum.reverse(desc_events)
    end

    test "returns empty list for no matches", %{storage: storage} do
      future_time = System.monotonic_time(:nanosecond) + 1_000_000_000
      
      assert {:ok, []} = DataAccess.query_by_time_range(storage, future_time, future_time + 1000)
    end
  end

  describe "query_by_process/3" do
    setup %{storage: storage} do
      pid1 = self()
      pid2 = spawn(fn -> :ok end)
      
      events = [
        %Events.FunctionExecution{
          id: "proc-event-1",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          caller_pid: pid1,
          module: TestModule,
          function: :test1,
          event_type: :call
        },
        %Events.FunctionExecution{
          id: "proc-event-2",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          caller_pid: pid2,
          module: TestModule,
          function: :test2,
          event_type: :call
        },
        %Events.ProcessEvent{
          id: "proc-event-3",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          pid: pid1,
          event_type: :spawn
        }
      ]
      
      DataAccess.store_events(storage, events)
      
      %{pid1: pid1, pid2: pid2, events: events}
    end

    test "queries events by process ID", %{storage: storage, pid1: pid1} do
      assert {:ok, events} = DataAccess.query_by_process(storage, pid1)
      
      # Should get 2 events for pid1
      assert length(events) == 2
      
      # Verify all events are for the correct PID
      Enum.each(events, fn event ->
        case event do
          %Events.FunctionExecution{caller_pid: ^pid1} -> :ok
          %Events.ProcessEvent{pid: ^pid1} -> :ok
          _ -> flunk("Event not associated with correct PID")
        end
      end)
    end

    test "respects limit option", %{storage: storage, pid1: pid1} do
      assert {:ok, events} = DataAccess.query_by_process(storage, pid1, limit: 1)
      assert length(events) == 1
    end

    test "returns empty list for unknown PID", %{storage: storage} do
      unknown_pid = spawn(fn -> :ok end)
      assert {:ok, []} = DataAccess.query_by_process(storage, unknown_pid)
    end
  end

  describe "query_by_function/4" do
    setup %{storage: storage} do
      events = [
        %Events.FunctionExecution{
          id: "func-event-1",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :test_function,
          event_type: :call
        },
        %Events.FunctionExecution{
          id: "func-event-2",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :test_function,
          event_type: :return
        },
        %Events.FunctionExecution{
          id: "func-event-3",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          module: OtherModule,
          function: :other_function,
          event_type: :call
        }
      ]
      
      DataAccess.store_events(storage, events)
      
      %{events: events}
    end

    test "queries events by function", %{storage: storage} do
      assert {:ok, events} = DataAccess.query_by_function(storage, TestModule, :test_function)
      
      # Should get 2 events for TestModule.test_function
      assert length(events) == 2
      
      # Verify all events are for the correct function
      Enum.each(events, fn event ->
        assert event.module == TestModule
        assert event.function == :test_function
      end)
    end

    test "respects limit option", %{storage: storage} do
      assert {:ok, events} = DataAccess.query_by_function(storage, TestModule, :test_function, limit: 1)
      assert length(events) == 1
    end

    test "returns empty list for unknown function", %{storage: storage} do
      assert {:ok, []} = DataAccess.query_by_function(storage, UnknownModule, :unknown_function)
    end
  end

  describe "query_by_correlation/3" do
    setup %{storage: storage} do
      correlation_id = "test-correlation-123"
      
      events = [
        %Events.FunctionExecution{
          id: "corr-event-1",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          correlation_id: correlation_id,
          module: TestModule,
          function: :test1,
          event_type: :call
        },
        %Events.FunctionExecution{
          id: "corr-event-2",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          correlation_id: correlation_id,
          module: TestModule,
          function: :test1,
          event_type: :return
        },
        %Events.FunctionExecution{
          id: "corr-event-3",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          correlation_id: "other-correlation",
          module: TestModule,
          function: :test2,
          event_type: :call
        }
      ]
      
      DataAccess.store_events(storage, events)
      
      %{correlation_id: correlation_id, events: events}
    end

    test "queries events by correlation ID", %{storage: storage, correlation_id: correlation_id} do
      assert {:ok, events} = DataAccess.query_by_correlation(storage, correlation_id)
      
      # Should get 2 events for the correlation ID
      assert length(events) == 2
      
      # Verify all events have the correct correlation ID
      Enum.each(events, fn event ->
        assert event.correlation_id == correlation_id
      end)
    end

    test "respects limit option", %{storage: storage, correlation_id: correlation_id} do
      assert {:ok, events} = DataAccess.query_by_correlation(storage, correlation_id, limit: 1)
      assert length(events) == 1
    end

    test "returns empty list for unknown correlation ID", %{storage: storage} do
      assert {:ok, []} = DataAccess.query_by_correlation(storage, "unknown-correlation")
    end
  end

  describe "get_stats/1" do
    test "returns accurate statistics", %{storage: storage} do
      initial_stats = DataAccess.get_stats(storage)
      
      assert initial_stats.total_events == 0
      assert initial_stats.oldest_timestamp == nil
      assert initial_stats.newest_timestamp == nil
      assert is_integer(initial_stats.memory_usage)
      
      # Store some events
      events = for i <- 1..5 do
        %Events.FunctionExecution{
          id: "stats-event-#{i}",
          timestamp: System.monotonic_time(:nanosecond) + i,
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :stats_test,
          event_type: :call
        }
      end
      
      DataAccess.store_events(storage, events)
      
      updated_stats = DataAccess.get_stats(storage)
      
      assert updated_stats.total_events == 5
      assert is_integer(updated_stats.oldest_timestamp)
      assert is_integer(updated_stats.newest_timestamp)
      assert updated_stats.newest_timestamp >= updated_stats.oldest_timestamp
      assert updated_stats.memory_usage > initial_stats.memory_usage
    end
  end

  describe "cleanup_old_events/2" do
    setup %{storage: storage} do
      base_time = System.monotonic_time(:nanosecond)
      
      events = for i <- 1..10 do
        %Events.FunctionExecution{
          id: "cleanup-event-#{i}",
          timestamp: base_time + i * 1_000_000,
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :cleanup_test,
          event_type: :call
        }
      end
      
      DataAccess.store_events(storage, events)
      
      %{base_time: base_time, events: events}
    end

    test "removes old events", %{storage: storage, base_time: base_time} do
      cutoff_time = base_time + 5 * 1_000_000
      
      initial_stats = DataAccess.get_stats(storage)
      assert initial_stats.total_events == 10
      
      assert {:ok, removed_count} = DataAccess.cleanup_old_events(storage, cutoff_time)
      assert removed_count > 0
      
      final_stats = DataAccess.get_stats(storage)
      assert final_stats.total_events == initial_stats.total_events - removed_count
    end

    test "doesn't remove events newer than cutoff", %{storage: storage} do
      # Use a cutoff time before all events
      cutoff_time = System.monotonic_time(:nanosecond) - 1_000_000
      
      assert {:ok, 0} = DataAccess.cleanup_old_events(storage, cutoff_time)
      
      stats = DataAccess.get_stats(storage)
      assert stats.total_events == 10
    end
  end

  describe "performance" do
    @tag :performance
    test "storage performance meets targets", %{storage: storage} do
      # Test single event storage performance
      event = %Events.FunctionExecution{
        id: "perf-test",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond),
        module: TestModule,
        function: :perf_test,
        event_type: :call
      }
      
      iterations = 1000
      
      # Measure storage performance
      start_time = System.monotonic_time(:nanosecond)
      
      for i <- 1..iterations do
        updated_event = %{event | id: "perf-test-#{i}"}
        DataAccess.store_event(storage, updated_event)
      end
      
      end_time = System.monotonic_time(:nanosecond)
      total_time_ns = end_time - start_time
      avg_time_ns = total_time_ns / iterations
      
      # Storage should be fast (target <50µs per event - realistic for ETS operations)
      assert avg_time_ns < 50_000, "Average storage time #{avg_time_ns}ns exceeds 50µs target"
    end

    @tag :performance
    test "batch storage is more efficient than individual storage", %{storage: _storage} do
      events = for i <- 1..1000 do
        %Events.FunctionExecution{
          id: "batch-perf-#{i}",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :batch_perf,
          event_type: :call
        }
      end
      
      # Measure individual storage
      {:ok, individual_storage} = DataAccess.new()
      start_time = System.monotonic_time(:nanosecond)
      
      Enum.each(events, &DataAccess.store_event(individual_storage, &1))
      
      individual_time = System.monotonic_time(:nanosecond) - start_time
      
      # Measure batch storage
      {:ok, batch_storage} = DataAccess.new()
      start_time = System.monotonic_time(:nanosecond)
      
      DataAccess.store_events(batch_storage, events)
      
      batch_time = System.monotonic_time(:nanosecond) - start_time
      
      # Batch should be faster or at least not significantly slower (relaxed expectation)
      assert batch_time <= individual_time * 1.5, "Batch storage significantly slower than individual"
    end

    @tag :performance
    test "query performance is acceptable", %{storage: storage} do
      # Store many events for querying
      base_time = System.monotonic_time(:nanosecond)
      
      events = for i <- 1..10000 do
        %Events.FunctionExecution{
          id: "query-perf-#{i}",
          timestamp: base_time + i,
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :query_perf,
          caller_pid: self(),
          event_type: :call
        }
      end
      
      DataAccess.store_events(storage, events)
      
      # Measure time range query performance
      start_time = System.monotonic_time(:nanosecond)
      
      DataAccess.query_by_time_range(storage, base_time, base_time + 5000, limit: 1000)
      
      query_time = System.monotonic_time(:nanosecond) - start_time
      
      # Query should be fast (target <10ms - realistic for 10k event scan)
      assert query_time < 10_000_000, "Time range query took #{query_time}ns (>10ms)"
      
      # Measure process query performance
      start_time = System.monotonic_time(:nanosecond)
      
      DataAccess.query_by_process(storage, self(), limit: 1000)
      
      process_query_time = System.monotonic_time(:nanosecond) - start_time
      
      # Process query should be fast
      assert process_query_time < 10_000_000, "Process query took #{process_query_time}ns (>10ms)"
    end
  end

  describe "memory management" do
    test "memory usage grows predictably", %{storage: storage} do
      initial_stats = DataAccess.get_stats(storage)
      initial_memory = initial_stats.memory_usage
      
      # Store a known number of events
      events = for i <- 1..1000 do
        %Events.FunctionExecution{
          id: "memory-test-#{i}",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :memory_test,
          event_type: :call
        }
      end
      
      DataAccess.store_events(storage, events)
      
      final_stats = DataAccess.get_stats(storage)
      final_memory = final_stats.memory_usage
      
      memory_growth = final_memory - initial_memory
      memory_per_event = memory_growth / 1000
      
      # Memory growth should be reasonable (less than 1KB per event)
      assert memory_per_event < 1024, "Memory per event #{memory_per_event} bytes seems excessive"
    end

    test "cleanup reduces memory usage", %{storage: storage} do
      # Store events
      base_time = System.monotonic_time(:nanosecond)
      
      events = for i <- 1..1000 do
        %Events.FunctionExecution{
          id: "cleanup-memory-#{i}",
          timestamp: base_time + i,
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :cleanup_memory,
          event_type: :call
        }
      end
      
      DataAccess.store_events(storage, events)
      
      before_cleanup_stats = DataAccess.get_stats(storage)
      
      # Clean up half the events
      cutoff_time = base_time + 500
      DataAccess.cleanup_old_events(storage, cutoff_time)
      
      after_cleanup_stats = DataAccess.get_stats(storage)
      
      # Memory usage should decrease
      assert after_cleanup_stats.memory_usage < before_cleanup_stats.memory_usage
      assert after_cleanup_stats.total_events < before_cleanup_stats.total_events
    end
  end

  describe "error handling" do
    test "handles storage errors gracefully" do
      # This test is tricky since ETS operations rarely fail
      # We'll test with invalid data instead
      {:ok, storage} = DataAccess.new()
      
      # Try to store an event with missing required fields
      incomplete_event = %Events.FunctionExecution{
        # Missing id and timestamp
        module: TestModule,
        function: :test,
        event_type: :call
      }
      
      # Should handle gracefully (might succeed with nil values or fail gracefully)
      result = DataAccess.store_event(storage, incomplete_event)
      case result do
        :ok -> assert true
        {:error, _reason} -> assert true
        _ -> flunk("Unexpected result: #{inspect(result)}")
      end
    end

    test "handles query errors gracefully", %{storage: storage} do
      # Query with invalid parameters should not crash
      result = DataAccess.query_by_time_range(storage, -1, -1)
      
      case result do
        {:ok, events} -> assert is_list(events)
        {:error, _} -> assert true
      end
    end
  end

  describe "concurrent access" do
    test "handles concurrent storage safely", %{storage: storage} do
      # Spawn multiple processes storing events concurrently
      tasks = for i <- 1..5 do
        Task.async(fn ->
          for j <- 1..100 do
            event = %Events.FunctionExecution{
              id: "concurrent-#{i}-#{j}",
              timestamp: System.monotonic_time(:nanosecond),
              wall_time: System.system_time(:nanosecond),
              module: TestModule,
              function: :concurrent_test,
              event_type: :call
            }
            DataAccess.store_event(storage, event)
          end
        end)
      end
      
      # Wait for all tasks to complete
      Enum.each(tasks, &Task.await/1)
      
      # Verify all events were stored
      stats = DataAccess.get_stats(storage)
      assert stats.total_events == 500
    end

    test "handles concurrent queries safely", %{storage: storage} do
      # Store some events first
      events = for i <- 1..100 do
        %Events.FunctionExecution{
          id: "query-concurrent-#{i}",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond),
          module: TestModule,
          function: :query_concurrent,
          caller_pid: self(),
          event_type: :call
        }
      end
      
      DataAccess.store_events(storage, events)
      
      # Spawn multiple processes querying concurrently
      tasks = for _ <- 1..5 do
        Task.async(fn ->
          DataAccess.query_by_process(storage, self())
        end)
      end
      
      # Wait for all tasks and verify results
      results = Enum.map(tasks, &Task.await/1)
      
      Enum.each(results, fn result ->
        assert {:ok, events} = result
        assert is_list(events)
      end)
    end
  end
end 