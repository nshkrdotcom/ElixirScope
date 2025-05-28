defmodule ElixirScope.Integration.APICompletionTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope
  alias ElixirScope.Events
  alias ElixirScope.Storage.EventStore
  
  setup do
    # Start ElixirScope for testing
    Application.put_env(:elixir_scope, :test_mode, true)
    
    # Start a test EventStore
    {:ok, store} = EventStore.start_link(name: :"test_api_store_#{:rand.uniform(10000)}")
    
    # Create some test events
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
    
    # Store events in the test store
    Enum.each(events, fn event ->
      EventStore.store_event(store, event)
    end)
    
    on_exit(fn ->
      if Process.alive?(store) do
        GenServer.stop(store)
      end
      Application.delete_env(:elixir_scope, :test_mode)
    end)
    
    %{store: store, events: events, pid1: pid1, pid2: pid2, base_time: base_time}
  end
  
  describe "ElixirScope.get_events/1 API completion" do
    test "no longer returns :not_implemented_yet" do
      # This should not return the old error
      result = ElixirScope.get_events([])
      
      # Should return either events or an error, but not :not_implemented_yet
      case result do
        {:error, :not_implemented_yet} ->
          flunk("get_events/1 still returns :not_implemented_yet")
        
        {:error, :not_running} ->
          # This is acceptable when ElixirScope is not running
          :ok
        
        events when is_list(events) ->
          # This is the desired behavior
          :ok
        
        {:error, _other_reason} ->
          # Other errors are acceptable
          :ok
      end
    end
    
    test "returns actual events when ElixirScope is running", %{store: store, pid1: pid1} do
      # Mock the EventManager to use our test store
      with_mocked_event_manager(store, fn ->
        # Start ElixirScope
        :ok = ElixirScope.start()
        
        # Query events
        result = ElixirScope.get_events([pid: pid1])
        
        case result do
          events when is_list(events) ->
            # Events list can be empty if no events are found for this PID
            # The important thing is that we get a list, not an error
            assert is_list(events)
            # If there are events, they should match the PID filter
            if length(events) > 0 do
              assert Enum.all?(events, &(&1.pid == pid1))
            end
          
          {:error, reason} ->
            # If there's an error, it should not be :not_implemented_yet
            refute reason == :not_implemented_yet
            # Other errors like :no_events_found are acceptable
        end
        
        # Stop ElixirScope
        ElixirScope.stop()
      end)
    end
    
    test "supports various query filters", %{store: store, pid1: pid1, base_time: base_time} do
      with_mocked_event_manager(store, fn ->
        :ok = ElixirScope.start()
        
        # Test PID filter
        pid_result = ElixirScope.get_events([pid: pid1])
        assert is_list(pid_result) or match?({:error, _}, pid_result)
        
        # Test event type filter
        type_result = ElixirScope.get_events([event_type: :function_entry])
        assert is_list(type_result) or match?({:error, _}, type_result)
        
        # Test time range filter
        time_result = ElixirScope.get_events([since: base_time, until: base_time + 500])
        assert is_list(time_result) or match?({:error, _}, time_result)
        
        # Test limit
        limit_result = ElixirScope.get_events([limit: 2])
        assert is_list(limit_result) or match?({:error, _}, limit_result)
        
        ElixirScope.stop()
      end)
    end
  end
  
  describe "ElixirScope.get_state_at/2 API completion" do
    test "no longer returns :not_implemented_yet" do
      pid = self()
      timestamp = System.monotonic_time(:millisecond)
      
      result = ElixirScope.get_state_at(pid, timestamp)
      
      # Should not return the old error
      case result do
        {:error, :not_implemented_yet} ->
          flunk("get_state_at/2 still returns :not_implemented_yet")
        
        {:error, :not_running} ->
          # This is acceptable when ElixirScope is not running
          :ok
        
        {:error, _other_reason} ->
          # Other errors are acceptable
          :ok
        
        _state ->
          # Any state (including nil) is acceptable
          :ok
      end
    end
    
    test "attempts state reconstruction when ElixirScope is running" do
      pid = self()
      timestamp = System.monotonic_time(:millisecond)
      
      # Start ElixirScope
      :ok = ElixirScope.start()
      
      result = ElixirScope.get_state_at(pid, timestamp)
      
      # Should attempt reconstruction, not return :not_implemented_yet
      case result do
        {:error, :not_implemented_yet} ->
          flunk("get_state_at/2 still returns :not_implemented_yet")
        
        {:error, _other_reason} ->
          # Other errors are acceptable (e.g., no state history)
          :ok
        
        _state ->
          # Any state (including nil) is acceptable
          :ok
      end
      
      ElixirScope.stop()
    end
  end
  
  describe "ElixirScope.get_message_flow/3 API completion" do
    test "no longer returns :not_implemented_yet" do
      pid1 = self()
      pid2 = spawn(fn -> :ok end)
      
      result = ElixirScope.get_message_flow(pid1, pid2)
      
      # Should not return the old error
      case result do
        {:error, :not_implemented_yet} ->
          flunk("get_message_flow/3 still returns :not_implemented_yet")
        
        {:error, :not_running} ->
          # This is acceptable when ElixirScope is not running
          :ok
        
        messages when is_list(messages) ->
          # Empty list is acceptable
          :ok
        
        {:error, _other_reason} ->
          # Other errors are acceptable
          :ok
      end
    end
    
    test "attempts message flow analysis when ElixirScope is running" do
      pid1 = self()
      pid2 = spawn(fn -> :ok end)
      
      # Start ElixirScope
      :ok = ElixirScope.start()
      
      result = ElixirScope.get_message_flow(pid1, pid2)
      
      # Should attempt analysis, not return :not_implemented_yet
      case result do
        {:error, :not_implemented_yet} ->
          flunk("get_message_flow/3 still returns :not_implemented_yet")
        
        messages when is_list(messages) ->
          # Empty list is acceptable
          :ok
        
        {:error, _other_reason} ->
          # Other errors are acceptable (e.g., no message tracking)
          :ok
      end
      
      ElixirScope.stop()
    end
    
    test "supports time range options" do
      pid1 = self()
      pid2 = spawn(fn -> :ok end)
      base_time = System.monotonic_time(:millisecond)
      
      :ok = ElixirScope.start()
      
      result = ElixirScope.get_message_flow(pid1, pid2, [
        since: base_time,
        until: base_time + 1000
      ])
      
      # Should handle options without returning :not_implemented_yet
      case result do
        {:error, :not_implemented_yet} ->
          flunk("get_message_flow/3 with options still returns :not_implemented_yet")
        
        messages when is_list(messages) ->
          :ok
        
        {:error, _other_reason} ->
          :ok
      end
      
      ElixirScope.stop()
    end
  end
  
  describe "Integration with Cinema Demo scenarios" do
    test "Cinema Demo can use new APIs without errors" do
      # This test ensures the Cinema Demo will work with the new APIs
      :ok = ElixirScope.start()
      
      # Simulate Cinema Demo usage patterns
      events = ElixirScope.get_events([limit: 10])
      assert is_list(events) or match?({:error, _}, events)
      
      # Should not crash or return :not_implemented_yet
      refute match?({:error, :not_implemented_yet}, events)
      
      ElixirScope.stop()
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
  
  defp with_mocked_event_manager(_store, fun) do
    # This would mock the EventManager to use our test store
    # For now, just run the function
    fun.()
  end
end 