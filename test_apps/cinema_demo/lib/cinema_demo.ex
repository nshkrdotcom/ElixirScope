defmodule CinemaDemo do
  @moduledoc """
  CinemaDemo - A demonstration application for ElixirScope's Cinema Debugger.
  
  This module provides interactive demos that showcase:
  - Real-time execution tracking
  - Time-travel debugging
  - Function call correlation
  - Variable state inspection
  - Performance analysis
  """

  require Logger
  alias CinemaDemo.{TaskManager, DataProcessor}
  alias ElixirScope.Capture.TemporalBridge
  
  @doc """
  Run a comprehensive demo of Cinema Debugger capabilities.
  """
  def run_full_demo do
    Logger.info("🎬 Starting Cinema Debugger Full Demo")
    
    # Demo 1: Task Management Flow
    Logger.info("📋 Demo 1: Task Management Flow")
    task_demo_result = run_task_management_demo()
    
    # Demo 2: Data Processing Pipeline
    Logger.info("🔄 Demo 2: Data Processing Pipeline")
    data_demo_result = run_data_processing_demo()
    
    # Demo 3: Complex Nested Operations
    Logger.info("🧩 Demo 3: Complex Nested Operations")
    nested_demo_result = run_nested_operations_demo()
    
    # Demo 4: Error Handling and Recovery
    Logger.info("⚠️  Demo 4: Error Handling and Recovery")
    error_demo_result = run_error_handling_demo()
    
    # Demo 5: Performance Analysis
    Logger.info("⚡ Demo 5: Performance Analysis")
    perf_demo_result = run_performance_demo()
    
    # Demo 6: Time-Travel Debugging
    Logger.info("⏰ Demo 6: Time-Travel Debugging")
    timetravel_result = run_timetravel_demo()
    
    summary = %{
      task_management: task_demo_result,
      data_processing: data_demo_result,
      nested_operations: nested_demo_result,
      error_handling: error_demo_result,
      performance_analysis: perf_demo_result,
      timetravel_debugging: timetravel_result
    }
    
    Logger.info("🎉 Cinema Debugger Full Demo Complete!")
    Logger.info("📊 Demo Summary: #{inspect(summary, pretty: true)}")
    
    summary
  end
  
  @doc """
  Demonstrate task management with Cinema Debugger tracking.
  """
  def run_task_management_demo do
    Logger.info("Creating and managing tasks...")
    
    # Create several tasks with different priorities
    {:ok, task1} = TaskManager.create_task("Process user data", :high, %{user_count: 1000})
    {:ok, task2} = TaskManager.create_task("Generate reports", :medium, %{report_type: "monthly"})
    {:ok, task3} = TaskManager.create_task("Cleanup old files", :low, %{days_old: 30})
    {:ok, task4} = TaskManager.create_task("Critical security update", :critical, %{patch_id: "SEC-2024-001"})
    
    # Start tasks and observe state changes
    {:ok, _result1} = TaskManager.start_task(task1)
    {:ok, _result2} = TaskManager.start_task(task2)
    {:ok, _result3} = TaskManager.start_task(task3)
    {:ok, _result4} = TaskManager.start_task(task4)
    
    # Complete some tasks
    :ok = TaskManager.complete_task(task1, :success)
    :ok = TaskManager.complete_task(task2, {:error, :timeout})  # This will retry
    :ok = TaskManager.complete_task(task3, :success)
    
    # Get final stats
    stats = TaskManager.get_stats()
    
    Logger.info("Task management demo completed. Stats: #{inspect(stats)}")
    
    %{
      tasks_created: [task1, task2, task3, task4],
      final_stats: stats,
      demo_type: :task_management
    }
  end
  
  @doc """
  Demonstrate data processing pipeline with temporal tracking.
  """
  def run_data_processing_demo do
    Logger.info("Processing various data types...")
    
    # Create test data items
    data_items = [
      %{
        id: "json_001",
        type: :json,
        payload: %{name: "John Doe", age: 30, skills: ["elixir", "erlang", "otp"]},
        metadata: %{source: "user_profile"},
        created_at: System.system_time(:millisecond)
      },
      %{
        id: "text_001", 
        type: :text,
        payload: "This is a sample text for processing. It contains multiple sentences and various words that will be analyzed for complexity and sentiment.",
        metadata: %{source: "document"},
        created_at: System.system_time(:millisecond)
      },
      %{
        id: "numeric_001",
        type: :numeric,
        payload: 12345.67,
        metadata: %{source: "sensor_data"},
        created_at: System.system_time(:millisecond)
      },
      %{
        id: "list_001",
        type: :list,
        payload: [1, 2, 3, 2, 4, 5, 1, 6, 7, 8, 9, 10],
        metadata: %{source: "measurements"},
        created_at: System.system_time(:millisecond)
      }
    ]
    
    # Process individual items
    individual_results = Enum.map(data_items, fn item ->
      case DataProcessor.process_data(item) do
        {:ok, result} -> result
        {:error, error} -> error
      end
    end)
    
    # Process as a batch
    {:ok, batch_result} = DataProcessor.process_batch(data_items)
    
    # Get processing stats
    stats = DataProcessor.get_stats()
    
    Logger.info("Data processing demo completed. Processed #{length(data_items)} items individually and in batch.")
    
    %{
      individual_results: individual_results,
      batch_result: batch_result,
      processing_stats: stats,
      demo_type: :data_processing
    }
  end
  
  @doc """
  Demonstrate complex nested operations for deep call stack tracking.
  """
  def run_nested_operations_demo do
    Logger.info("Running nested operations...")
    
    result = complex_calculation_pipeline(100)
    
    Logger.info("Nested operations demo completed with result: #{inspect(result)}")
    
    %{
      result: result,
      demo_type: :nested_operations
    }
  end
  
  @doc """
  Demonstrate error handling and recovery patterns.
  """
  def run_error_handling_demo do
    Logger.info("Testing error handling patterns...")
    
    # Test various error scenarios
    results = [
      safe_division(10, 2),
      safe_division(10, 0),  # Division by zero
      safe_network_call("valid_endpoint"),
      safe_network_call("invalid_endpoint"),  # Network error
      safe_data_parsing("{\"valid\": \"json\"}"),
      safe_data_parsing("invalid json"),  # Parse error
    ]
    
    Logger.info("Error handling demo completed.")
    
    %{
      results: results,
      demo_type: :error_handling
    }
  end
  
  @doc """
  Demonstrate performance analysis capabilities.
  """
  def run_performance_demo do
    Logger.info("Running performance analysis...")
    
    # Test different performance scenarios
    results = %{
      fast_operation: measure_performance(fn -> fast_operation() end),
      medium_operation: measure_performance(fn -> medium_operation() end),
      slow_operation: measure_performance(fn -> slow_operation() end),
      memory_intensive: measure_performance(fn -> memory_intensive_operation() end),
      cpu_intensive: measure_performance(fn -> cpu_intensive_operation() end)
    }
    
    Logger.info("Performance demo completed.")
    
    %{
      performance_results: results,
      demo_type: :performance_analysis
    }
  end
  
  @doc """
  Demonstrate time-travel debugging by querying past execution states.
  """
  def run_timetravel_demo do
    Logger.info("Demonstrating time-travel debugging...")
    
    # Record timestamps at different points
    start_time = System.monotonic_time(:nanosecond)
    
    # Perform some operations
    {:ok, task_id} = TaskManager.create_task("Time travel test", :medium, %{test: true})
    
    mid_time = System.monotonic_time(:nanosecond)
    
    {:ok, _result} = TaskManager.start_task(task_id)
    
    end_time = System.monotonic_time(:nanosecond)
    
    # Query temporal bridge for state at different times
    bridge = :cinema_demo_bridge
    
    # Allow some time for events to be processed
    Process.sleep(100)
    :ok = TemporalBridge.flush_buffer(bridge)
    
    # Query states at different points in time
    {:ok, start_state} = TemporalBridge.reconstruct_state_at(bridge, start_time)
    {:ok, mid_state} = TemporalBridge.reconstruct_state_at(bridge, mid_time)
    {:ok, end_state} = TemporalBridge.reconstruct_state_at(bridge, end_time)
    
    Logger.info("Time-travel debugging demo completed.")
    
    %{
      timestamps: %{start: start_time, mid: mid_time, end: end_time},
      states: %{start: start_state, mid: mid_state, end: end_state},
      demo_type: :timetravel_debugging
    }
  end
  
  # Private helper functions for demos
  
  defp complex_calculation_pipeline(input) do
    input
    |> step_1_transform()
    |> step_2_validate()
    |> step_3_process()
    |> step_4_aggregate()
    |> step_5_finalize()
  end
  
  defp step_1_transform(value) do
    # Simulate complex transformation
    transformed = value * 2 + 10
    Logger.debug("Step 1: Transformed #{value} to #{transformed}")
    transformed
  end
  
  defp step_2_validate(value) do
    # Simulate validation logic
    if value > 0 and value < 1_000_000 do
      Logger.debug("Step 2: Validation passed for #{value}")
      {:ok, value}
    else
      Logger.warning("Step 2: Validation failed for #{value}")
      {:error, :invalid_range}
    end
  end
  
  defp step_3_process({:ok, value}) do
    # Simulate processing with nested calls
    processed = recursive_fibonacci(10) + value
    Logger.debug("Step 3: Processed value to #{processed}")
    {:ok, processed}
  end
  
  defp step_3_process({:error, reason}) do
    Logger.error("Step 3: Skipped due to error: #{reason}")
    {:error, reason}
  end
  
  defp step_4_aggregate({:ok, value}) do
    # Simulate aggregation
    aggregated = aggregate_with_history(value, [1, 2, 3, 4, 5])
    Logger.debug("Step 4: Aggregated to #{aggregated}")
    {:ok, aggregated}
  end
  
  defp step_4_aggregate({:error, reason}), do: {:error, reason}
  
  defp step_5_finalize({:ok, value}) do
    # Final processing step
    final = %{
      result: value,
      timestamp: System.system_time(:millisecond),
      metadata: %{
        processing_steps: 5,
        complexity_score: calculate_complexity_score(value)
      }
    }
    Logger.debug("Step 5: Finalized result")
    {:ok, final}
  end
  
  defp step_5_finalize({:error, reason}), do: {:error, reason}
  
  defp recursive_fibonacci(0), do: 0
  defp recursive_fibonacci(1), do: 1
  defp recursive_fibonacci(n) when n > 1 do
    recursive_fibonacci(n - 1) + recursive_fibonacci(n - 2)
  end
  
  defp aggregate_with_history(value, history) do
    Enum.reduce(history, value, fn item, acc ->
      acc + item * 2
    end)
  end
  
  defp calculate_complexity_score(value) when is_number(value) do
    # Simple complexity calculation
    abs(value) |> :math.log10() |> round()
  end
  
  defp calculate_complexity_score(_value), do: 1
  
  defp safe_division(a, b) do
    try do
      result = a / b
      Logger.debug("Division #{a}/#{b} = #{result}")
      {:ok, result}
    rescue
      ArithmeticError -> 
        Logger.warning("Division by zero: #{a}/#{b}")
        {:error, :division_by_zero}
    end
  end
  
  defp safe_network_call(endpoint) do
    # Simulate network call
    case endpoint do
      "valid_endpoint" ->
        Process.sleep(50)  # Simulate network delay
        Logger.debug("Network call to #{endpoint} succeeded")
        {:ok, %{status: 200, data: "success"}}
      
      "invalid_endpoint" ->
        Logger.warning("Network call to #{endpoint} failed")
        {:error, :network_timeout}
    end
  end
  
  defp safe_data_parsing(json_string) do
    try do
      result = Jason.decode!(json_string)
      Logger.debug("JSON parsing succeeded")
      {:ok, result}
    rescue
      Jason.DecodeError ->
        Logger.warning("JSON parsing failed for: #{json_string}")
        {:error, :invalid_json}
    end
  end
  
  defp fast_operation do
    # Very quick operation
    1 + 1
  end
  
  defp medium_operation do
    # Medium complexity operation
    Enum.reduce(1..1000, 0, &+/2)
  end
  
  defp slow_operation do
    # Slower operation
    Process.sleep(100)
    Enum.reduce(1..10000, 0, &+/2)
  end
  
  defp memory_intensive_operation do
    # Create and process large data structure
    large_list = Enum.to_list(1..10000)
    large_list |> Enum.map(&(&1 * 2)) |> Enum.sum()
  end
  
  defp cpu_intensive_operation do
    # CPU-intensive calculation
    Enum.reduce(1..1000, 1, fn x, acc ->
      acc + :math.pow(x, 2) + :math.sqrt(x)
    end)
  end
  
  defp measure_performance(fun) do
    start_time = System.monotonic_time(:microsecond)
    start_memory = :erlang.memory(:total)
    
    result = fun.()
    
    end_time = System.monotonic_time(:microsecond)
    end_memory = :erlang.memory(:total)
    
    %{
      result: result,
      execution_time_us: end_time - start_time,
      memory_delta_bytes: end_memory - start_memory
    }
  end
end
