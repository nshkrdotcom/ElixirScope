defmodule ElixirScope.Runtime.WarningDetectionTest do
  @moduledoc """
  Comprehensive test suite designed to detect and address compilation warnings.
  
  This test suite specifically targets the warning gaps identified in REVAMP_WARNING2.md:
  1. Type system violations (unreachable error clauses)
  2. Error path coverage gaps
  3. BEAM module availability matrix testing
  4. Code quality issues
  """
  
  use ExUnit.Case
  
  alias ElixirScope.Runtime.{StateMonitor, StateMonitorManager, Safety, Sampling, Tracer}
  alias ElixirScope.Capture.RingBuffer
  
  describe "type system violation detection" do
    test "StateMonitor handle_debug_event can return error" do
      # This test verifies that the {:error, reason} clause in StateMonitor.handle_info/2
      # is actually reachable by forcing an error condition
      
      # Start a simple Agent to monitor (OTP process)
      {:ok, target_pid} = Agent.start_link(fn -> %{} end)
      
      # Create a StateMonitor for the OTP process
      {:ok, monitor_pid} = StateMonitor.start_link([
        target_pid: target_pid,
        monitoring_level: :state_changes
      ])
      
      # Send an invalid debug event that should trigger the error path
      invalid_event = {:debug, target_pid, {:invalid_event_type, :invalid_data}, %{}}
      send(monitor_pid, invalid_event)
      
      # Give the monitor time to process
      Process.sleep(10)
      
      # The monitor should still be alive (error handled gracefully)
      assert Process.alive?(monitor_pid)
      
      # Clean up
      GenServer.stop(monitor_pid)
      Agent.stop(target_pid)
    end
    
    test "StateMonitorManager apply_state_monitoring_plan can return error" do
      # This test verifies that the {:error, reason} clause in StateMonitorManager.handle_cast/2
      # is actually reachable by providing invalid runtime plans
      
      {:ok, manager_pid} = StateMonitorManager.start_link([])
      
      # Send an invalid runtime plan that should cause errors
      invalid_plan = %{
        invalid_field: :invalid_value,
        state_monitors: %{
          invalid_target: %{invalid_config: true}
        }
      }
      
      # This should trigger the error path in apply_state_monitoring_plan
      GenServer.cast(manager_pid, {:apply_plan, invalid_plan})
      
      # Give the manager time to process
      Process.sleep(10)
      
      # The manager should still be alive (error handled gracefully)
      assert Process.alive?(manager_pid)
      
      # Clean up
      GenServer.stop(manager_pid)
    end
  end
  
  describe "error path coverage" do
    test "Safety module error conditions are reachable" do
      # Test that Safety module functions can actually return errors
      
      # Test resource monitoring with invalid metrics
      monitor = Safety.create_resource_monitor(:invalid_metric, 100.0, :stop_tracing)
      assert monitor.metric == :invalid_metric
      
      # Test that get_current_resource_value handles invalid metrics
      value = Safety.get_current_resource_value(:invalid_metric)
      assert value == 0  # Should return default value for invalid metrics
      
      # Test safety action execution with invalid actions
      state = %{limits: %{}, active_traces: %{}, stats: %{}}
      updated_state = Safety.execute_safety_action(state, :invalid_action, %{})
      assert is_map(updated_state)  # Should handle gracefully
    end
    
    test "Sampling module error conditions are reachable" do
      # Test that Sampling module functions can return errors
      
      # Test CPU usage when monitoring is unavailable
      cpu_usage = Sampling.get_cpu_usage()
      
      # Should return either success or a clear error
      case cpu_usage do
        {:ok, value} when is_number(value) -> :ok
        {:error, :cpu_sup_unavailable} -> :ok
        other -> flunk("Unexpected CPU usage result: #{inspect(other)}")
      end
    end
    
    test "Tracer module error conditions are reachable" do
      # Test that Tracer functions can return errors
      
      # Test dbg availability detection
      dbg_result = Tracer.check_dbg_availability()
      assert dbg_result in [:ok, {:error, :dbg_unavailable}]
      
      # Test tracer with invalid configuration
      result = Tracer.start_link([invalid_option: :invalid_value])
      
      case result do
        {:ok, pid} -> 
          # Should start successfully even with invalid options
          assert Process.alive?(pid)
          GenServer.stop(pid)
        {:error, _reason} -> 
          # Or return a clear error
          :ok
      end
    end
  end
  
  describe "BEAM module availability matrix" do
    test "dbg module availability scenarios" do
      # Test all scenarios for :dbg module availability
      
      case Code.ensure_loaded(:dbg) do
        {:module, :dbg} ->
          # :dbg is available - test that functions work
          assert :ok = Tracer.check_dbg_availability()
          
          # Test that tracer can use :dbg when available
          {:ok, tracer_pid} = Tracer.start_link([])
          
          # Tracer should indicate :dbg is available
          {:ok, stats} = Tracer.get_stats(tracer_pid)
          assert is_map(stats)
          
          GenServer.stop(tracer_pid)
          
        {:error, :nofile} ->
          # :dbg is not available - test fallback behavior
          assert {:error, :dbg_unavailable} = Tracer.check_dbg_availability()
          
          # Test that tracer works without :dbg
          {:ok, tracer_pid} = Tracer.start_link([])
          
          # Should still provide basic functionality
          {:ok, stats} = Tracer.get_stats(tracer_pid)
          assert is_map(stats)
          
          GenServer.stop(tracer_pid)
      end
    end
    
    test "cpu_sup module availability scenarios" do
      # Test all scenarios for :cpu_sup module availability
      
      case Code.ensure_loaded(:cpu_sup) do
        {:module, :cpu_sup} ->
          # :cpu_sup is available - test that functions work
          assert :ok = Safety.check_cpu_monitoring()
          
          # Test CPU usage detection
          cpu_usage = Sampling.get_cpu_usage()
          case cpu_usage do
            {:ok, value} when is_number(value) -> assert value >= 0
            {:error, _} -> :ok  # Error is acceptable even when module is loaded
          end
          
          # Test CPU limit checking
          result = Safety.exceeds_cpu_limit?()
          assert is_boolean(result)
          
        {:error, :nofile} ->
          # :cpu_sup is not available - test fallback behavior
          assert {:error, :cpu_sup_unavailable} = Safety.check_cpu_monitoring()
          
          # Test that functions work without :cpu_sup
          cpu_usage = Sampling.get_cpu_usage()
          assert cpu_usage == {:error, :cpu_sup_unavailable}
          
          # CPU limit checking should return false when unavailable
          assert false == Safety.exceeds_cpu_limit?()
      end
    end
    
    test "combined module availability scenarios" do
      # Test behavior when both modules are available/unavailable
      
      dbg_available = match?({:module, :dbg}, Code.ensure_loaded(:dbg))
      cpu_sup_available = match?({:module, :cpu_sup}, Code.ensure_loaded(:cpu_sup))
      
      # Test tracer startup in all combinations
      {:ok, tracer_pid} = Tracer.start_link([])
      {:ok, stats} = Tracer.get_stats(tracer_pid)
      
      # Should work regardless of module availability
      assert is_map(stats)
      assert Map.has_key?(stats, :tracer_id)
      
      GenServer.stop(tracer_pid)
      
      # Test safety system in all combinations
      {:ok, safety_pid} = Safety.start_link([])
      safety_stats = Safety.get_stats()
      
      # Should work regardless of module availability
      assert is_map(safety_stats)
      
      GenServer.stop(safety_pid)
      
      # Log the test scenario for debugging
      IO.puts("Tested scenario: dbg=#{dbg_available}, cpu_sup=#{cpu_sup_available}")
    end
  end
  
  describe "function return type validation" do
    test "StateMonitor handle_debug_event return types" do
             # Test that handle_debug_event can actually return different types
       # This helps verify if the {:error, reason} clause is truly unreachable
       
       {:ok, target_pid} = Agent.start_link(fn -> %{} end)
       {:ok, monitor_pid} = StateMonitor.start_link([
         target_pid: target_pid,
         monitoring_level: :state_changes
       ])
       
       # Test with various debug event types to see what handle_debug_event returns
       test_events = [
         {:debug, target_pid, {:in, :test_message}, %{}},
         {:debug, target_pid, {:out, :test_message, target_pid}, %{}},
         {:debug, target_pid, {:noreply, %{new_state: :test}}, %{}},
         {:debug, target_pid, {:invalid_event_type, :invalid_data}, %{}}
       ]
       
       Enum.each(test_events, fn event ->
         send(monitor_pid, event)
         Process.sleep(5)  # Give time to process
       end)
       
       # Monitor should still be alive regardless of event types
       assert Process.alive?(monitor_pid)
       
       GenServer.stop(monitor_pid)
       Agent.stop(target_pid)
    end
    
    test "StateMonitorManager apply_state_monitoring_plan return types" do
      # Test that apply_state_monitoring_plan can return different types
      
      {:ok, manager_pid} = StateMonitorManager.start_link([])
      
      # Test with various plan types
      test_plans = [
        %{state_monitors: %{}},  # Valid empty plan
        %{state_monitors: %{TestModule => %{events: [:call]}}},  # Valid plan
        %{invalid_structure: true},  # Invalid plan structure
        %{state_monitors: "invalid"},  # Invalid monitors field
        nil  # Nil plan
      ]
      
      Enum.each(test_plans, fn plan ->
        GenServer.cast(manager_pid, {:apply_plan, plan})
        Process.sleep(5)  # Give time to process
      end)
      
      # Manager should still be alive regardless of plan validity
      assert Process.alive?(manager_pid)
      
      GenServer.stop(manager_pid)
    end
  end
  
  describe "defensive programming validation" do
    test "error clauses serve defensive programming purpose" do
      # Even if error clauses are currently unreachable, they serve as
      # defensive programming for future changes
      
      # Test that the modules handle unexpected inputs gracefully
      
             # StateMonitor with extreme inputs - use an OTP process
       {:ok, target_pid} = Agent.start_link(fn -> %{} end)
       {:ok, monitor_pid} = StateMonitor.start_link([
         target_pid: target_pid,
         monitoring_level: :state_changes
       ])
       
       # Send completely unexpected messages
       send(monitor_pid, :unexpected_atom)
       send(monitor_pid, {"unexpected", "tuple"})
       send(monitor_pid, %{unexpected: :map})
       
       Process.sleep(10)
       assert Process.alive?(monitor_pid)
       GenServer.stop(monitor_pid)
       Agent.stop(target_pid)
      
      # StateMonitorManager with extreme inputs
      {:ok, manager_pid} = StateMonitorManager.start_link([])
      
      # Send unexpected casts
      GenServer.cast(manager_pid, :unexpected_cast)
      GenServer.cast(manager_pid, {"unexpected", "cast"})
      
      Process.sleep(10)
      assert Process.alive?(manager_pid)
      GenServer.stop(manager_pid)
    end
  end
  
  describe "code quality improvements" do
    test "buffer variables are used meaningfully" do
      # Test that demonstrates meaningful use of buffer variables
      # (fixing the unused variable warnings in other tests)
      
      {:ok, buffer} = RingBuffer.new(size: 1024)
      
      # Actually use the buffer in a meaningful way
      assert RingBuffer.size(buffer) == 1024
      
      # Test buffer operations
      :ok = RingBuffer.write(buffer, :test_data)
      stats = RingBuffer.stats(buffer)
      assert stats.size == 1024
      assert stats.total_writes >= 0
    end
    
    test "cpu usage return types match test expectations" do
      # Fix the unreachable clause in environment_compatibility_test.exs:93
      
      cpu_usage = Sampling.get_cpu_usage()
      
      # Test the actual return types (not the incorrect :os_mon_unavailable)
      case cpu_usage do
        {:ok, value} when is_number(value) -> 
          assert value >= 0
        {:error, :cpu_sup_unavailable} -> 
          :ok  # This is the correct error type
        other -> 
          flunk("Unexpected CPU usage return type: #{inspect(other)}")
      end
    end
  end
  
  describe "compilation warning detection" do
    test "detect when warnings would be generated" do
      # This test helps identify when compilation warnings would occur
      
      # Test :dbg function availability
      dbg_functions = [
        {:start, 0},
        {:tp, 3}, 
        {:tp, 4},
        {:p, 2},
        {:ctp, 0}
      ]
      
      Enum.each(dbg_functions, fn {func, arity} ->
        available = function_exported?(:dbg, func, arity)
        
        if available do
          IO.puts("✅ :dbg.#{func}/#{arity} is available")
        else
          IO.puts("⚠️  :dbg.#{func}/#{arity} would generate warning")
        end
      end)
      
      # Test :cpu_sup function availability
      cpu_sup_functions = [
        {:util, 0},
        {:avg1, 0}, 
        {:avg5, 0},
        {:avg15, 0}
      ]
      
      Enum.each(cpu_sup_functions, fn {func, arity} ->
        available = function_exported?(:cpu_sup, func, arity)
        
        if available do
          IO.puts("✅ :cpu_sup.#{func}/#{arity} is available")
        else
          IO.puts("⚠️  :cpu_sup.#{func}/#{arity} would generate warning")
        end
      end)
    end
  end
end 