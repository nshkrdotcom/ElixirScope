defmodule ElixirScope.Capture.PipelineManagerTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.Capture.PipelineManager
  alias ElixirScope.Capture.AsyncWriterPool
  
  describe "supervisor lifecycle" do
    test "starts successfully with default configuration" do
      # Test that PipelineManager can start as a supervisor
      {:ok, pid} = PipelineManager.start_link([])
      
      assert Process.alive?(pid)
      assert is_pid(pid)
      
      # Clean up
      GenServer.stop(pid)
    end
    
    test "starts with custom configuration" do
      config = %{
        async_writer_pool_size: 4,
        batch_size: 100,
        max_backlog: 1000
      }
      
      {:ok, pid} = PipelineManager.start_link(config)
      
      assert Process.alive?(pid)
      
      # Verify configuration was applied
      state = PipelineManager.get_state(pid)
      assert state.config.async_writer_pool_size == 4
      assert state.config.batch_size == 100
      assert state.config.max_backlog == 1000
      
      GenServer.stop(pid)
    end
    
    test "supervises AsyncWriterPool as child process" do
      {:ok, manager_pid} = PipelineManager.start_link([])
      
      # Verify AsyncWriterPool is started as a child
      children = Supervisor.which_children(manager_pid)
      
      assert length(children) >= 1
      assert Enum.any?(children, fn {name, _pid, _type, _modules} ->
        name == AsyncWriterPool
      end)
      
      GenServer.stop(manager_pid)
    end
  end
  
  describe "child process management" do
    test "restarts failed AsyncWriterPool" do
      {:ok, manager_pid} = PipelineManager.start_link([])
      
      # Get initial AsyncWriterPool pid
      [{AsyncWriterPool, initial_pool_pid, _, _}] = 
        Supervisor.which_children(manager_pid)
        |> Enum.filter(fn {name, _, _, _} -> name == AsyncWriterPool end)
      
      # Kill the AsyncWriterPool
      Process.exit(initial_pool_pid, :kill)
      
      # Wait for supervisor to restart it
      Process.sleep(50)
      
      # Verify new AsyncWriterPool is running
      [{AsyncWriterPool, new_pool_pid, _, _}] = 
        Supervisor.which_children(manager_pid)
        |> Enum.filter(fn {name, _, _, _} -> name == AsyncWriterPool end)
      
      assert new_pool_pid != initial_pool_pid
      assert Process.alive?(new_pool_pid)
      
      GenServer.stop(manager_pid)
    end
  end
  
  describe "configuration management" do
    test "updates configuration dynamically" do
      {:ok, manager_pid} = PipelineManager.start_link([])
      
      # Get initial configuration
      initial_state = PipelineManager.get_state(manager_pid)
      initial_pool_size = initial_state.config.async_writer_pool_size
      
      # Update configuration
      new_config = %{async_writer_pool_size: initial_pool_size + 2}
      :ok = PipelineManager.update_config(manager_pid, new_config)
      
      # Verify configuration was updated
      updated_state = PipelineManager.get_state(manager_pid)
      assert updated_state.config.async_writer_pool_size == initial_pool_size + 2
      
      GenServer.stop(manager_pid)
    end
  end
  
  describe "monitoring and health checks" do
    test "reports healthy status when all children are running" do
      {:ok, manager_pid} = PipelineManager.start_link([])
      
      health = PipelineManager.health_check(manager_pid)
      
      assert health.status == :healthy
      assert health.children_count > 0
      assert health.uptime_ms > 0
      
      GenServer.stop(manager_pid)
    end
    
    test "reports metrics about pipeline performance" do
      {:ok, manager_pid} = PipelineManager.start_link([])
      
      metrics = PipelineManager.get_metrics(manager_pid)
      
      assert is_map(metrics)
      assert Map.has_key?(metrics, :events_processed)
      assert Map.has_key?(metrics, :processing_rate)
      assert Map.has_key?(metrics, :backlog_size)
      
      GenServer.stop(manager_pid)
    end
  end
  
  describe "graceful shutdown" do
    test "stops all child processes gracefully" do
      {:ok, manager_pid} = PipelineManager.start_link([])
      
      # Get child pids before shutdown
      children_before = Supervisor.which_children(manager_pid)
      child_pids = Enum.map(children_before, fn {_, pid, _, _} -> pid end)
      
      # Shutdown gracefully
      :ok = PipelineManager.shutdown(manager_pid)
      
      # Wait for shutdown to complete
      Process.sleep(100)
      
      # Verify all children are stopped
      Enum.each(child_pids, fn pid ->
        refute Process.alive?(pid)
      end)
      
      refute Process.alive?(manager_pid)
    end
  end
end 