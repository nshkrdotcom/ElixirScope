defmodule ElixirScope.Capture.AsyncWriterPoolTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.Capture.AsyncWriterPool
  alias ElixirScope.Capture.AsyncWriter
  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Events
  alias ElixirScope.Utils
  
  describe "pool lifecycle" do
    test "starts successfully with default configuration" do
      {:ok, pid} = AsyncWriterPool.start_link([])
      
      assert Process.alive?(pid)
      assert is_pid(pid)
      
      GenServer.stop(pid)
    end
    
    test "starts with custom configuration" do
      config = %{
        pool_size: 3,
        ring_buffer: nil,
        batch_size: 25,
        poll_interval_ms: 50
      }
      
      {:ok, pid} = AsyncWriterPool.start_link(config)
      
      assert Process.alive?(pid)
      
      # Verify configuration was applied
      state = AsyncWriterPool.get_state(pid)
      assert state.config.pool_size == 3
      assert state.config.batch_size == 25
      assert state.config.poll_interval_ms == 50
      
      GenServer.stop(pid)
    end
    
    test "starts configured number of worker processes" do
      config = %{pool_size: 4}
      
      {:ok, pid} = AsyncWriterPool.start_link(config)
      
      state = AsyncWriterPool.get_state(pid)
      assert length(state.workers) == 4
      
      # Verify all workers are alive
      Enum.each(state.workers, fn worker_pid ->
        assert Process.alive?(worker_pid)
      end)
      
      GenServer.stop(pid)
    end
  end
  
  describe "worker management" do
    test "restarts failed workers automatically" do
      # Trap exits to avoid test process being killed
      Process.flag(:trap_exit, true)
      
      config = %{pool_size: 2}
      
      {:ok, pool_pid} = AsyncWriterPool.start_link(config)
      
      # Get initial worker pids
      initial_state = AsyncWriterPool.get_state(pool_pid)
      [worker1, worker2] = initial_state.workers
      
      # Kill one worker
      Process.exit(worker1, :kill)
      
      # Wait for restart
      Process.sleep(200)
      
      # Check that pool still has 2 workers and the killed one was replaced
      new_state = AsyncWriterPool.get_state(pool_pid)
      assert length(new_state.workers) == 2
      
      # The new worker should be different from the killed one
      refute worker1 in new_state.workers
      assert worker2 in new_state.workers
      
      GenServer.stop(pool_pid)
      
      # Clean up any exit messages
      receive do
        {:EXIT, _, _} -> :ok
      after
        0 -> :ok
      end
    end
    
    test "scales pool size dynamically" do
      {:ok, pool_pid} = AsyncWriterPool.start_link(%{pool_size: 2})
      
      # Verify initial size
      initial_state = AsyncWriterPool.get_state(pool_pid)
      assert length(initial_state.workers) == 2
      
      # Scale up
      :ok = AsyncWriterPool.scale_pool(pool_pid, 4)
      
      scaled_state = AsyncWriterPool.get_state(pool_pid)
      assert length(scaled_state.workers) == 4
      
      # Scale down
      :ok = AsyncWriterPool.scale_pool(pool_pid, 3)
      
      final_state = AsyncWriterPool.get_state(pool_pid)
      assert length(final_state.workers) == 3
      
      GenServer.stop(pool_pid)
    end
  end
  
  describe "event distribution" do
    setup do
      # Create a ring buffer with test events
      {:ok, ring_buffer} = RingBuffer.new(size: 1024)
      
      events = for i <- 1..10 do
        %Events.FunctionExecution{
          id: "pool-test-#{i}",
          timestamp: Utils.monotonic_timestamp() + i,
          module: TestModule,
          function: :pool_test,
          event_type: :call,
          args: [i],
          return_value: nil,
          duration_ns: nil,
          caller_pid: self(),
          correlation_id: nil
        }
      end
      
      Enum.each(events, fn event ->
        RingBuffer.write(ring_buffer, event)
      end)
      
      %{ring_buffer: ring_buffer, events: events}
    end
    
    test "distributes events across workers", %{ring_buffer: ring_buffer} do
      config = %{
        pool_size: 3,
        ring_buffer: ring_buffer,
        batch_size: 2,
        poll_interval_ms: 10
      }
      
      {:ok, pool_pid} = AsyncWriterPool.start_link(config)
      
      # Give workers time to process events
      Process.sleep(200)
      
      # Check that events were processed
      metrics = AsyncWriterPool.get_metrics(pool_pid)
      assert metrics.total_events_processed > 0
      assert metrics.total_events_read > 0
      
      GenServer.stop(pool_pid)
    end
    
    test "coordinates workers with different ring buffer positions", %{ring_buffer: ring_buffer} do
      config = %{
        pool_size: 2,
        ring_buffer: ring_buffer,
        batch_size: 3,
        poll_interval_ms: 20
      }
      
      {:ok, pool_pid} = AsyncWriterPool.start_link(config)
      
      # Allow processing
      Process.sleep(150)
      
      state = AsyncWriterPool.get_state(pool_pid)
      
      # Workers should have processed events and advanced their positions
      worker_positions = Enum.map(state.workers, fn worker_pid ->
        worker_state = AsyncWriter.get_state(worker_pid)
        worker_state.current_position
      end)
      
      # At least one worker should have advanced beyond position 0
      assert Enum.any?(worker_positions, fn pos -> pos > 0 end)
      
      GenServer.stop(pool_pid)
    end
  end
  
  describe "load balancing" do
    test "assigns work segments to different workers" do
      config = %{pool_size: 3}
      
      {:ok, pool_pid} = AsyncWriterPool.start_link(config)
      
      # Get worker assignments
      assignments = AsyncWriterPool.get_worker_assignments(pool_pid)
      
      assert is_map(assignments)
      assert map_size(assignments) == 3
      
      # Each worker should have a unique segment assignment
      segments = Map.values(assignments)
      assert length(Enum.uniq(segments)) == 3
      
      GenServer.stop(pool_pid)
    end
    
    test "redistributes work when pool is scaled" do
      {:ok, pool_pid} = AsyncWriterPool.start_link(%{pool_size: 2})
      
      initial_assignments = AsyncWriterPool.get_worker_assignments(pool_pid)
      assert map_size(initial_assignments) == 2
      
      # Scale up
      AsyncWriterPool.scale_pool(pool_pid, 4)
      
      new_assignments = AsyncWriterPool.get_worker_assignments(pool_pid)
      assert map_size(new_assignments) == 4
      
      # Work should be redistributed
      refute initial_assignments == new_assignments
      
      GenServer.stop(pool_pid)
    end
  end
  
  describe "metrics and monitoring" do
    test "aggregates metrics from all workers" do
      config = %{pool_size: 2}
      
      {:ok, pool_pid} = AsyncWriterPool.start_link(config)
      
      metrics = AsyncWriterPool.get_metrics(pool_pid)
      
      assert is_map(metrics)
      assert Map.has_key?(metrics, :total_events_read)
      assert Map.has_key?(metrics, :total_events_processed)
      assert Map.has_key?(metrics, :total_batches_processed)
      assert Map.has_key?(metrics, :average_processing_rate)
      assert Map.has_key?(metrics, :total_errors)
      assert Map.has_key?(metrics, :worker_count)
      
      assert metrics.worker_count == 2
      
      GenServer.stop(pool_pid)
    end
    
    test "reports health status of all workers" do
      {:ok, pool_pid} = AsyncWriterPool.start_link(%{pool_size: 3})
      
      health = AsyncWriterPool.health_check(pool_pid)
      
      assert health.status == :healthy
      assert health.worker_count == 3
      assert health.healthy_workers == 3
      assert health.failed_workers == 0
      assert is_number(health.uptime_ms)
      
      GenServer.stop(pool_pid)
    end
  end
  
  describe "error handling" do
    test "handles worker failures gracefully" do
      # Trap exits to avoid test process being killed
      Process.flag(:trap_exit, true)
      
      {:ok, pool_pid} = AsyncWriterPool.start_link(%{pool_size: 3})
      
      initial_state = AsyncWriterPool.get_state(pool_pid)
      worker_to_kill = List.first(initial_state.workers)
      
      # Kill a worker
      Process.exit(worker_to_kill, :kill)
      
      # Pool should recover
      Process.sleep(200)
      
      health = AsyncWriterPool.health_check(pool_pid)
      assert health.status == :healthy
      assert health.worker_count == 3
      
      GenServer.stop(pool_pid)
      
      # Clean up any exit messages
      receive do
        {:EXIT, _, _} -> :ok
      after
        0 -> :ok
      end
    end
    
    test "continues processing even with partial worker failures" do
      # Trap exits to avoid test process being killed
      Process.flag(:trap_exit, true)
      
      {:ok, ring_buffer} = RingBuffer.new(size: 1024)
      
      # Add events
      for i <- 1..5 do
        event = %Events.FunctionExecution{
          id: "resilience-test-#{i}",
          timestamp: Utils.monotonic_timestamp() + i,
          module: TestModule,
          function: :resilience_test,
          event_type: :call,
          args: [i],
          return_value: nil,
          duration_ns: nil,
          caller_pid: self(),
          correlation_id: nil
        }
        RingBuffer.write(ring_buffer, event)
      end
      
      config = %{
        pool_size: 3,
        ring_buffer: ring_buffer,
        batch_size: 2,
        poll_interval_ms: 10
      }
      
      {:ok, pool_pid} = AsyncWriterPool.start_link(config)
      
      # Kill one worker
      state = AsyncWriterPool.get_state(pool_pid)
      Process.exit(List.first(state.workers), :kill)
      
      # Allow processing to continue
      Process.sleep(300)
      
      # Should still process events with remaining workers
      metrics = AsyncWriterPool.get_metrics(pool_pid)
      assert metrics.total_events_processed > 0
      
      GenServer.stop(pool_pid)
      
      # Clean up any exit messages
      receive do
        {:EXIT, _, _} -> :ok
      after
        0 -> :ok
      end
    end
  end
  
  describe "graceful shutdown" do
    test "stops all workers gracefully" do
      {:ok, pool_pid} = AsyncWriterPool.start_link(%{pool_size: 3})
      
      state = AsyncWriterPool.get_state(pool_pid)
      worker_pids = state.workers
      
      # All workers should be alive
      Enum.each(worker_pids, fn pid ->
        assert Process.alive?(pid)
      end)
      
      # Stop pool gracefully
      :ok = AsyncWriterPool.stop(pool_pid)
      
      # Wait for shutdown
      Process.sleep(100)
      
      # All workers should be stopped
      Enum.each(worker_pids, fn pid ->
        refute Process.alive?(pid)
      end)
      
      refute Process.alive?(pool_pid)
    end
  end
end 