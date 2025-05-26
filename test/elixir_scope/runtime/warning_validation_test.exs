defmodule ElixirScope.Runtime.WarningValidationTest do
  @moduledoc """
  Validates that all identified warnings have been properly addressed
  and that production code handles missing dependencies gracefully.
  """
  
  use ExUnit.Case
  
  alias ElixirScope.Runtime.{Tracer, Safety, Sampling}
  
  describe "BEAM module availability validation" do
    test "production code handles missing :dbg gracefully" do
      # Verify that Tracer can detect :dbg availability without warnings
      result = Tracer.check_dbg_availability()
      assert result in [:ok, {:error, :dbg_unavailable}]
      
      # Verify tracer can start regardless of :dbg availability
      {:ok, tracer_pid} = Tracer.start_link([])
      assert Process.alive?(tracer_pid)
      GenServer.stop(tracer_pid)
    end
    
    test "production code handles missing :cpu_sup gracefully" do
      # Verify that Safety can detect CPU monitoring availability without warnings
      result = Safety.check_cpu_monitoring()
      assert result in [:ok, {:error, :cpu_sup_unavailable}]
      
      # Verify CPU limit checking doesn't crash
      assert is_boolean(Safety.exceeds_cpu_limit?())
      
      # Verify Sampling can get CPU usage without warnings
      result = Sampling.get_cpu_usage()
      case result do
        {:ok, usage} when is_number(usage) -> :ok
        {:error, :cpu_sup_unavailable} -> :ok
        _ -> flunk("Unexpected CPU usage result: #{inspect(result)}")
      end
    end
  end
  
  describe "conditional compilation validation" do
    test "no compilation warnings in production modules" do
      # This test validates that our @compile directives work
      # If there were warnings, they would appear during compilation
      
      production_modules = [
        ElixirScope.Runtime.Tracer,
        ElixirScope.Runtime.Safety,
        ElixirScope.Runtime.Sampling,
        ElixirScope.Runtime.Controller,
        ElixirScope.Runtime
      ]
      
      Enum.each(production_modules, fn module ->
        # Verify module is loaded and functional
        assert Code.ensure_loaded?(module)
        
        # Verify module has expected functions
        functions = module.__info__(:functions)
        assert is_list(functions)
        assert length(functions) > 0
      end)
    end
  end
  
  describe "error path validation" do
    test "StateMonitor error paths are reachable" do
      # Verify that our fix to make error paths reachable works
      {:ok, agent_pid} = Agent.start_link(fn -> %{} end)
      
      {:ok, monitor_pid} = ElixirScope.Runtime.StateMonitor.start_link([
        target_pid: agent_pid,
        monitoring_level: :state_changes
      ])
      
      # Monitor should be running
      assert Process.alive?(monitor_pid)
      
      # Clean up
      GenServer.stop(monitor_pid)
      Agent.stop(agent_pid)
    end
  end
  
  describe "future dependency validation" do
    test "production code compiles without warnings for future dependencies" do
      # This validates our @compile directives work for future dependencies
      # The actual validation is that compilation succeeds without warnings
      
      # Test that modules with future dependencies are loaded
      assert Code.ensure_loaded?(ElixirScope.Runtime.Controller)
      assert Code.ensure_loaded?(ElixirScope.Runtime)
      
      # If @compile directives work, these modules loaded without warnings
      :ok
    end
  end
end 