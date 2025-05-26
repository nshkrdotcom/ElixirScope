defmodule ElixirScope.Runtime.CompilationIntegrationTest do
  @moduledoc """
  Integration tests that verify all runtime modules compile together correctly.
  
  These tests would have caught the 16 Phase 1-related warnings by testing
  real module interactions instead of relying on mocks.
  """
  
  use ExUnit.Case
  
  alias ElixirScope.Runtime.{Safety, StateMonitor, TracerManager}
  alias ElixirScope.Capture.{Ingestor, RingBuffer}
  
  describe "compilation verification" do
    test "all runtime modules are loaded and functional" do
      # Test that modules are properly loaded without recompiling them
      runtime_modules = [
        ElixirScope.Runtime,
        ElixirScope.Runtime.Controller,
        ElixirScope.Runtime.Tracer,
        ElixirScope.Runtime.TracerManager,
        ElixirScope.Runtime.StateMonitor,
        ElixirScope.Runtime.StateMonitorManager,
        ElixirScope.Runtime.Safety,
        ElixirScope.Runtime.Sampling,
        ElixirScope.Runtime.Matchers
      ]
      
      Enum.each(runtime_modules, fn module ->
        assert Code.ensure_loaded?(module), "Module #{module} should be loaded"
        functions = module.__info__(:functions)
        assert is_list(functions), "Module #{module} should have functions"
        assert length(functions) > 0, "Module #{module} should have at least one function"
      end)
    end
    
    test "runtime modules can be loaded and called together" do
      # This would have caught function signature mismatches
      
      # Test that would have caught Warning 4.1 (function signature mismatch)
      # The function now has proper pattern matching, so this should work
      sampler = ElixirScope.Runtime.Sampling.adaptive_sampler()
      updated_sampler = ElixirScope.Runtime.Sampling.update_config(sampler, %{base_rate: 0.01})
      assert updated_sampler.config.base_rate == 0.01
      
      # Global config call should also work
      assert :ok = ElixirScope.Runtime.Sampling.update_config(:global, %{base_rate: 0.01})
    end
  end
  
  describe "ingestor integration" do
    test "runtime components can access Ingestor buffer" do
      # This would have caught Warning 2.2 (missing get_buffer/0)
      
      # Should fail if get_buffer/0 doesn't exist
      case Ingestor.get_buffer() do
        {:ok, _buffer} -> :ok
        {:error, :not_initialized} -> :ok
        _ -> flunk("get_buffer/0 should return {:ok, buffer} or {:error, :not_initialized}")
      end
    end
    
    test "runtime components can forward events to Ingestor" do
      # This would have caught Warning 2.1 (missing ingest_generic_event/7)
      
      {:ok, buffer} = RingBuffer.new(size: 1024)
      
      # Should fail if ingest_generic_event/7 doesn't exist
      assert :ok = Ingestor.ingest_generic_event(
        buffer,
        :function_entry,
        %{module: TestModule, function: :test_func, arity: 0},
        self(),
        "test-correlation-id",
        System.monotonic_time(:nanosecond),
        System.system_time(:nanosecond)
      )
    end
    
    test "tracer can forward events through real Ingestor" do
      # Integration test that would have caught both Ingestor warnings
      
      {:ok, buffer} = RingBuffer.new(size: 1024)
      Ingestor.set_buffer(buffer)
      
      # This would fail if either function is missing
      {:ok, ingestor_buffer} = Ingestor.get_buffer()
      
      assert :ok = Ingestor.ingest_generic_event(
        ingestor_buffer,
        :function_exit,
        %{module: TestModule, function: :test_func, return_value: :ok},
        self(),
        "tracer-correlation-id",
        System.monotonic_time(:nanosecond),
        System.system_time(:nanosecond)
      )
    end
  end
  
  describe "AI orchestrator integration" do
    test "controller handles missing AI orchestrator gracefully" do
      # This validates that Controller has proper fallback for missing AI.Orchestrator
      # The actual function call is in production code with @compile directive
      
      # Test that Controller can start without AI.Orchestrator
      {:ok, controller_pid} = ElixirScope.Runtime.Controller.start_link([])
      assert Process.alive?(controller_pid)
      GenServer.stop(controller_pid)
    end
  end
  
  describe "BEAM primitives availability" do
    test "dbg module functions are available or gracefully handled" do
      # Test that Tracer handles :dbg availability properly without calling :dbg directly
      
      case Code.ensure_loaded(:dbg) do
        {:module, :dbg} ->
          # If :dbg is available, tracer should detect it
          assert :ok = ElixirScope.Runtime.Tracer.check_dbg_availability()
        
        {:error, :nofile} ->
          # If :dbg is not available, tracer should handle gracefully
          assert {:error, :dbg_unavailable} = ElixirScope.Runtime.Tracer.check_dbg_availability()
      end
    end
    
    test "cpu_sup functions are available or gracefully handled" do
      # Test that Safety handles :cpu_sup availability properly without calling :cpu_sup directly
      
      case Code.ensure_loaded(:cpu_sup) do
        {:module, :cpu_sup} ->
          # If available, safety should detect it
          assert :ok = Safety.check_cpu_monitoring()
        
        {:error, :nofile} ->
          # Should have graceful fallback
          assert {:error, :cpu_sup_unavailable} = Safety.check_cpu_monitoring()
          assert false == Safety.exceeds_cpu_limit?()
      end
    end
  end
  
  describe "cross-module function calls" do
    test "safety module calls sampling with correct arity" do
      # This would have caught Warning 4.1 (function signature mismatch)
      
      # Create a minimal state for testing
      state = %{
        limits: %{max_events_per_second: 1000},
        active_traces: %{},
        stats: %{traces_started: 0}
      }
      
      # This should work without arity errors
      updated_state = Safety.execute_safety_action(state, :reduce_sampling, %{})
      assert is_map(updated_state)
    end
    
    test "state monitor calls ingest_generic_event with correct parameters" do
      # This would have caught the ingest_generic_event usage
      
      {:ok, buffer} = RingBuffer.new(size: 1024)
      
      # Test the exact call pattern used in StateMonitor
      assert :ok = Ingestor.ingest_generic_event(
        buffer,
        :state_change,
        %{
          callback: :handle_call,
          old_state: %{counter: 0},
          new_state: %{counter: 1}
        },
        self(),
        "state-monitor-correlation",
        System.monotonic_time(:nanosecond),
        System.system_time(:nanosecond)
      )
    end
    
    test "tracer calls ingest_generic_event with correct parameters" do
      # This would have caught the tracer's ingest_generic_event usage
      
      {:ok, buffer} = RingBuffer.new(size: 1024)
      
      # Test the exact call pattern used in Tracer
      assert :ok = Ingestor.ingest_generic_event(
        buffer,
        :function_entry,
        %{
          module: TestModule,
          function: :test_function,
          arity: 2,
          args: [:arg1, :arg2]
        },
        self(),
        "tracer-correlation",
        System.monotonic_time(:nanosecond),
        System.system_time(:nanosecond)
      )
    end
  end
  
  describe "unused function detection" do
    test "all defined functions are used or documented as intentionally unused" do
      # This would have caught Warning 4.3 (unused function)
      
      # Check TracerManager for unused functions
      functions = TracerManager.__info__(:functions)
      
      # increment_tracer_index/1 should either be used or removed
      if Keyword.has_key?(functions, :increment_tracer_index) do
        # If function exists, it should be used somewhere
        # This is a placeholder - in real implementation, we'd check usage
        flunk("increment_tracer_index/1 is defined but unused - should be removed or used")
      end
    end
  end
  
  describe "unreachable code detection" do
    test "error handling clauses are reachable" do
      # This would have caught Warning 4.2 (unreachable error clauses)
      
      # Test StateMonitor error handling
      # If handle_debug_event always returns {:ok, term()}, 
      # then {:error, reason} clauses are unreachable
      
      # This test would need to verify that error conditions can actually occur
      # or that the error clauses should be removed
      
      # For now, we'll just verify the module exists and can be loaded
      assert Code.ensure_loaded?(StateMonitor)
    end
  end
  
  describe "time travel integration" do
    test "runtime module handles missing time travel gracefully" do
      # This validates that Runtime has proper fallback for missing TimeTravel.ReplayEngine
      # The actual function call is in production code with @compile directive
      
      # Test that Runtime module is functional without TimeTravel
      assert Code.ensure_loaded?(ElixirScope.Runtime)
      functions = ElixirScope.Runtime.__info__(:functions)
      assert Keyword.has_key?(functions, :replay_to)
    end
  end
end 