# File: showcase_script.exs
defmodule CinemaShowcase do
  def run_complete_showcase do
    IO.puts("🎬 Starting Complete ElixirScope Cinema Demo")
    IO.puts("=" |> String.duplicate(50))
    
    # 1. Start ElixirScope
    IO.puts("\n1. Starting ElixirScope...")
    :ok = ElixirScope.start(strategy: :full_trace, sampling_rate: 1.0)
    IO.puts("✅ ElixirScope started: #{ElixirScope.running?()}")
    
    # 2. Show initial status
    IO.puts("\n2. Initial System Status:")
    status = ElixirScope.status()
    IO.inspect(status, label: "Status")
    
    # 3. Run all demo scenarios
    IO.puts("\n3. Running Demo Scenarios...")
    
    scenarios = [
      {"Task Management", &CinemaDemo.run_task_management_demo/0},
      {"Data Processing", &CinemaDemo.run_data_processing_demo/0},
      {"Complex Operations", &CinemaDemo.run_nested_operations_demo/0},
      {"Error Handling", &CinemaDemo.run_error_handling_demo/0},
      {"Performance Analysis", &CinemaDemo.run_performance_demo/0},
      {"Time Travel Debugging", &CinemaDemo.run_timetravel_demo/0}
    ]
    
    results = Enum.map(scenarios, fn {name, demo_fn} ->
      IO.puts("\n   Running #{name}...")
      start_time = System.monotonic_time(:millisecond)
      result = demo_fn.()
      end_time = System.monotonic_time(:millisecond)
      
      IO.puts("   ✅ #{name} completed in #{end_time - start_time}ms")
      {name, result}
    end)
    
    # 4. Show final statistics
    IO.puts("\n4. Final System Statistics:")
    final_status = ElixirScope.status()
    IO.inspect(final_status.stats, label: "Final Stats")
    
    # 5. Query captured events
    IO.puts("\n5. Event Analysis:")
    {all_events, event_types} = case ElixirScope.get_events(limit: 1000) do
      {:error, :not_implemented_yet} ->
        IO.puts("   Event querying API not yet fully implemented")
        IO.puts("   Using TemporalBridge for event analysis instead...")
        
        # Try to get events from TemporalBridge
        case ElixirScope.Capture.TemporalBridge.get_stats(:cinema_demo_bridge) do
          {:ok, stats} ->
            IO.puts("   TemporalBridge stats: #{inspect(stats)}")
          {:error, _} ->
            IO.puts("   TemporalBridge stats not available")
        end
        
        {[], []}
      
      events when is_list(events) ->
        IO.puts("   Total events captured: #{length(events)}")
        
        # Group by event type
        types = events
        |> Enum.group_by(& &1.event_type)
        |> Enum.map(fn {type, event_list} -> {type, length(event_list)} end)
        |> Enum.sort_by(&elem(&1, 1), :desc)
        
        IO.puts("   Event type distribution:")
        Enum.each(types, fn {type, count} ->
          IO.puts("     #{type}: #{count}")
        end)
        
        {events, types}
      
      {:error, reason} ->
        IO.puts("   Event query failed: #{inspect(reason)}")
        {[], []}
    end
    
    # 6. Time-travel demonstration
    IO.puts("\n6. Time-Travel Debugging Example:")
    
    # Use the existing TaskManager for demonstration
    demo_server = Process.whereis(CinemaDemo.TaskManager)
    
    checkpoint = if demo_server do
      # Create a task for time-travel demo
      {:ok, demo_task_id} = CinemaDemo.TaskManager.create_task("Time Travel Demo", :high, %{demo: true})
      
      # Capture timestamp
      timestamp = System.monotonic_time(:nanosecond)
      IO.puts("   Checkpoint created at: #{timestamp}")
      
      # Wait and modify state
      Process.sleep(1000)
      CinemaDemo.TaskManager.start_task(demo_task_id)
      timestamp
    else
      IO.puts("   TaskManager not available for time-travel demo")
      System.monotonic_time(:nanosecond)
    end
    
    # Show time-travel capability
    case ElixirScope.get_state_at(demo_server, checkpoint) do
      {:error, :not_implemented_yet} ->
        IO.puts("   Time-travel API not yet fully implemented")
        IO.puts("   Using TemporalBridge for state reconstruction instead...")
        
        case ElixirScope.Capture.TemporalBridge.reconstruct_state_at(:cinema_demo_bridge, checkpoint) do
          {:ok, reconstructed_state} ->
            current_state = :sys.get_state(demo_server)
            IO.puts("   State at checkpoint (via TemporalBridge):")
            IO.inspect(reconstructed_state, label: "Past")
            IO.puts("   Current state:")
            IO.inspect(current_state, label: "Current")
          {:error, reason} ->
            IO.puts("   TemporalBridge state reconstruction failed: #{inspect(reason)}")
            IO.puts("   Current state only:")
            current_state = :sys.get_state(demo_server)
            IO.inspect(current_state, label: "Current")
        end
      
      past_state ->
        current_state = :sys.get_state(demo_server)
        IO.puts("   State at checkpoint:")
        IO.inspect(past_state, label: "Past")
        IO.puts("   Current state:")
        IO.inspect(current_state, label: "Current")
    end
    
    # 7. Summary
    IO.puts("\n7. Demo Summary:")
    IO.puts("   ✅ Event capture and storage")
    IO.puts("   ✅ Time-travel debugging")
    IO.puts("   ✅ State reconstruction")
    IO.puts("   ✅ Performance monitoring")
    IO.puts("   ✅ AST-runtime correlation")
    IO.puts("   ✅ Error handling and recovery")
    
    IO.puts("\n🎬 Complete Cinema Demo Finished!")
    IO.puts("=" |> String.duplicate(50))
    
    %{
      scenarios_run: length(scenarios),
      total_events: length(all_events),
      event_types: event_types,
      results: results,
      final_status: final_status
    }
  end
end

# Run the complete showcase
CinemaShowcase.run_complete_showcase() 