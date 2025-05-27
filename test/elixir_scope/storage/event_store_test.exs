defmodule ElixirScope.Storage.EventStoreTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.Storage.EventStore
  alias ElixirScope.Events
  
  setup do
    # Start a fresh EventStore for each test
    {:ok, store} = EventStore.start_link(name: :"test_store_#{:rand.uniform(10000)}")
    
    on_exit(fn ->
      if Process.alive?(store) do
        GenServer.stop(store)
      end
    end)
    
    %{store: store}
  end
  
  describe "event storage" do
    test "stores and retrieves events", %{store: store} do
      event = create_test_event()
      
      assert :ok = EventStore.store_event(store, event)
      
      {:ok, events} = EventStore.query_events(store, [])
      assert length(events) == 1
      assert List.first(events).id == event.id
    end
    
    test "stores multiple events efficiently", %{store: store} do
      events = Enum.map(1..100, fn i -> create_test_event(%{sequence: i}) end)
      
      start_time = System.monotonic_time(:microsecond)
      
      Enum.each(events, fn event ->
        assert :ok = EventStore.store_event(store, event)
      end)
      
      end_time = System.monotonic_time(:microsecond)
      avg_time_per_event = (end_time - start_time) / 100
      
      # Should store each event in less than 15µs on average
      assert avg_time_per_event < 15
      
      {:ok, retrieved_events} = EventStore.query_events(store, [])
      assert length(retrieved_events) == 100
    end
    
    test "handles concurrent writes", %{store: store} do
      tasks = Enum.map(1..50, fn i ->
        Task.async(fn ->
          event = create_test_event(%{sequence: i, pid: self()})
          EventStore.store_event(store, event)
        end)
      end)
      
      results = Task.await_many(tasks, 5000)
      assert Enum.all?(results, &(&1 == :ok))
      
      {:ok, events} = EventStore.query_events(store, [])
      assert length(events) == 50
    end
  end
  
  describe "event querying" do
    setup %{store: store} do
      # Create test events with different characteristics
      pid1 = spawn(fn -> :ok end)
      pid2 = spawn(fn -> :ok end)
      
      base_time = System.monotonic_time(:millisecond)
      
      events = [
        create_test_event(%{pid: pid1, event_type: :function_entry, timestamp: base_time}),
        create_test_event(%{pid: pid1, event_type: :function_exit, timestamp: base_time + 100}),
        create_test_event(%{pid: pid2, event_type: :function_entry, timestamp: base_time + 200}),
        create_test_event(%{pid: pid2, event_type: :message_send, timestamp: base_time + 300}),
        create_test_event(%{pid: pid1, event_type: :state_change, timestamp: base_time + 400})
      ]
      
      Enum.each(events, fn event ->
        EventStore.store_event(store, event)
      end)
      
      %{events: events, pid1: pid1, pid2: pid2, base_time: base_time}
    end
    
    test "queries events by pid", %{store: store, pid1: pid1, pid2: pid2} do
      {:ok, pid1_events} = EventStore.query_events(store, [pid: pid1])
      {:ok, pid2_events} = EventStore.query_events(store, [pid: pid2])
      
      assert length(pid1_events) == 3
      assert length(pid2_events) == 2
      
      assert Enum.all?(pid1_events, &(&1.pid == pid1))
      assert Enum.all?(pid2_events, &(&1.pid == pid2))
    end
    
    test "queries events by event_type", %{store: store} do
      {:ok, function_events} = EventStore.query_events(store, [event_type: :function_entry])
      {:ok, message_events} = EventStore.query_events(store, [event_type: :message_send])
      
      assert length(function_events) == 2
      assert length(message_events) == 1
      
      assert Enum.all?(function_events, &(&1.event_type == :function_entry))
      assert Enum.all?(message_events, &(&1.event_type == :message_send))
    end
    
    test "queries events by time range", %{store: store, base_time: base_time} do
      since = base_time + 150
      until = base_time + 350
      
      {:ok, time_range_events} = EventStore.query_events(store, [since: since, until: until])
      
      assert length(time_range_events) == 2
      assert Enum.all?(time_range_events, fn event ->
        event.timestamp >= since and event.timestamp <= until
      end)
    end
    
    test "applies limit to query results", %{store: store} do
      {:ok, limited_events} = EventStore.query_events(store, [limit: 3])
      
      assert length(limited_events) == 3
    end
    
    test "combines multiple filters", %{store: store, pid1: pid1, base_time: base_time} do
      {:ok, filtered_events} = EventStore.query_events(store, [
        pid: pid1,
        event_type: :function_entry,
        since: base_time - 100,
        until: base_time + 100
      ])
      
      assert length(filtered_events) == 1
      event = List.first(filtered_events)
      assert event.pid == pid1
      assert event.event_type == :function_entry
    end
    
    test "query performance meets targets", %{store: store} do
      # Add more events for realistic performance testing
      additional_events = Enum.map(1..1000, fn i -> 
        create_test_event(%{sequence: i + 100})
      end)
      
      Enum.each(additional_events, fn event ->
        EventStore.store_event(store, event)
      end)
      
      start_time = System.monotonic_time(:millisecond)
      {:ok, _events} = EventStore.query_events(store, [limit: 100])
      end_time = System.monotonic_time(:millisecond)
      
      query_time = end_time - start_time
      
      # Should complete query in less than 100ms
      assert query_time < 100
    end
  end
  
  describe "indexing" do
    test "creates and uses temporal index", %{store: store} do
      events = Enum.map(1..10, fn i ->
        create_test_event(%{timestamp: System.monotonic_time(:millisecond) + i * 100})
      end)
      
      Enum.each(events, fn event ->
        EventStore.store_event(store, event)
      end)
      
      # Verify temporal index is being used for time-based queries
      stats = EventStore.get_index_stats(store)
      assert stats.temporal_index_size > 0
    end
    
    test "creates and uses process index", %{store: store} do
      pid1 = spawn(fn -> :ok end)
      pid2 = spawn(fn -> :ok end)
      
      events = [
        create_test_event(%{pid: pid1}),
        create_test_event(%{pid: pid1}),
        create_test_event(%{pid: pid2})
      ]
      
      Enum.each(events, fn event ->
        EventStore.store_event(store, event)
      end)
      
      # Verify process index is being used
      stats = EventStore.get_index_stats(store)
      assert stats.process_index_size > 0
    end
    
    test "creates and uses function index", %{store: store} do
      events = [
        create_test_event(%{event_type: :function_entry, function: "MyModule.my_function/2"}),
        create_test_event(%{event_type: :function_exit, function: "MyModule.my_function/2"}),
        create_test_event(%{event_type: :function_entry, function: "OtherModule.other_function/1"})
      ]
      
      Enum.each(events, fn event ->
        EventStore.store_event(store, event)
      end)
      
      # Verify function index is being used
      stats = EventStore.get_index_stats(store)
      assert stats.function_index_size > 0
    end
  end
  
  describe "integration with existing systems" do
    test "integrates with DataAccess module", %{store: store} do
      # Test that EventStore can work with existing DataAccess
      event = create_test_event()
      
      assert :ok = EventStore.store_event(store, event)
      
      # Should be able to retrieve via DataAccess interface
      {:ok, data_access_events} = EventStore.get_events_via_data_access(store)
      assert length(data_access_events) == 1
    end
  end
  
  # Helper functions
  defp create_test_event(overrides \\ %{}) do
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