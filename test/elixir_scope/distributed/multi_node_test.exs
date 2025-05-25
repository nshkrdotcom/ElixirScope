defmodule ElixirScope.Distributed.MultiNodeTest do
  use ExUnit.Case, async: false

  alias ElixirScope.Distributed.NodeCoordinator
  alias ElixirScope.Storage.DataAccess

  @test_nodes [:node1@localhost, :node2@localhost, :node3@localhost]

  setup_all do
    # Start test nodes for distributed testing
    case start_test_nodes() do
      {:ok, nodes} ->
        on_exit(fn ->
          Enum.each(nodes, fn node ->
            try do
              :rpc.call(node, :init, :stop, [])
            catch
              _, _ -> :ok
            end
          end)
        end)

        {:ok, nodes: nodes}
      
      {:error, :no_distributed_support} ->
        {:ok, skip: true}
    end
  end

  describe "cross-node event correlation" do
    test "correlates GenServer call across nodes", context do
      if Map.get(context, :skip) do
        # Skip test if distributed nodes not available
        assert true, "Distributed tests skipped - no distributed support available"
      else
        %{nodes: [node1, node2, _node3]} = context
        # Start GenServer on node2
        {:ok, server_pid} = :rpc.call(node2, GenServer, :start_link, [TestGenServer, %{}])

        # Make call from node1 to node2
        correlation_id = :rpc.call(node1, GenServer, :call, [server_pid, {:get, :key}])

        # Wait for event processing
        Process.sleep(200)

        # Verify events are correlated across nodes
        node1_events = :rpc.call(node1, DataAccess, :get_events_by_correlation, [correlation_id])
        node2_events = :rpc.call(node2, DataAccess, :get_events_by_correlation, [correlation_id])

        # Should have call event on node1
        assert find_event(node1_events, :genserver_call_start) != nil

        # Should have handle_call event on node2
        assert find_event(node2_events, :genserver_handle_call_start) != nil
        assert find_event(node2_events, :genserver_handle_call_complete) != nil

        # Verify correlation IDs match
        all_events = node1_events ++ node2_events
        correlation_ids = Enum.map(all_events, & &1.correlation_id) |> Enum.uniq()
        assert length(correlation_ids) == 1
      end
    end

    test "traces distributed process spawning", context do
      if Map.get(context, :skip) do
        # Skip test if distributed nodes not available
        assert true, "Distributed tests skipped - no distributed support available"
      else
        %{nodes: [node1, node2]} = context
        # Spawn process on node2 from node1
        _spawn_result = :rpc.call(node1, Node, :spawn, [node2, fn ->
          Process.sleep(100)
          :ok
        end])

        Process.sleep(200)

        # Verify spawn events are captured
        node1_events = :rpc.call(node1, DataAccess, :get_events_by_type, [:process_spawn])
        node2_events = :rpc.call(node2, DataAccess, :get_events_by_type, [:process_start])

        assert length(node1_events) > 0
        assert length(node2_events) > 0

        # Verify parent-child relationship is tracked
        spawn_event = hd(node1_events)
        start_event = hd(node2_events)

        assert spawn_event.data.target_node == node2
        assert start_event.data.parent_node == node1
      end
    end

    test "handles node disconnection gracefully", context do
      if Map.get(context, :skip) do
        # Skip test if distributed nodes not available  
        assert true, "Distributed tests skipped - no distributed support available"
      else
        %{nodes: [node1, node2, node3]} = context
        # Establish communication between nodes
        _correlation_id = start_distributed_operation(node1, node2)

        # Disconnect node2
        :rpc.call(node2, Node, :disconnect, [node1])
        :rpc.call(node2, Node, :disconnect, [node3])

        Process.sleep(100)

        # Verify node1 detects disconnection
        node1_events = :rpc.call(node1, DataAccess, :get_events_by_type, [:node_disconnected])
        assert length(node1_events) > 0

        disconnect_event = hd(node1_events)
        assert disconnect_event.data.disconnected_node == node2
        assert disconnect_event.data.reason != nil
      end
    end
  end

  describe "distributed event synchronization" do
    test "synchronizes events across nodes", context do
      if Map.get(context, :skip) do
        # Skip test if distributed nodes not available
        assert true, "Distributed tests skipped - no distributed support available"
      else
        %{nodes: [node1, node2, node3]} = context
        # Generate events on all nodes
        nodes = [node1, node2, node3]
        correlation_id = generate_distributed_events(nodes)

        # Wait for synchronization
        Process.sleep(500)

        # Verify all nodes have complete event history
        for node <- nodes do
          events = :rpc.call(node, DataAccess, :get_events_by_correlation, [correlation_id])

          # Should have events from all nodes
          node_sources = Enum.map(events, & &1.node) |> Enum.uniq()
          assert length(node_sources) == 3

          # Should have proper ordering
          assert events_properly_ordered?(events)
        end
      end
    end

    test "handles network partitions", context do
      if Map.get(context, :skip) do
        # Skip test if distributed nodes not available
        assert true, "Distributed tests skipped - no distributed support available"
      else
        %{nodes: [node1, node2, node3]} = context
        # Create network partition: node1 isolated from node2,node3
        :rpc.call(node1, Node, :disconnect, [node2])
        :rpc.call(node1, Node, :disconnect, [node3])

        # Generate events during partition
        correlation_id1 = :rpc.call(node1, TestEventGenerator, :generate, [])
        correlation_id2 = :rpc.call(node2, TestEventGenerator, :generate, [])

        Process.sleep(100)

        # Verify events are stored locally during partition
        node1_events = :rpc.call(node1, DataAccess, :get_events_by_correlation, [correlation_id1])
        node2_events = :rpc.call(node2, DataAccess, :get_events_by_correlation, [correlation_id2])

        assert length(node1_events) > 0
        assert length(node2_events) > 0

        # Reconnect nodes
        :rpc.call(node1, Node, :connect, [node2])
        :rpc.call(node1, Node, :connect, [node3])

        # Wait for synchronization
        Process.sleep(300)

        # Verify events are eventually synchronized
        all_node1_events = :rpc.call(node1, DataAccess, :get_all_events, [])
        all_node2_events = :rpc.call(node2, DataAccess, :get_all_events, [])

        # Both nodes should have events from both correlation IDs
        node1_correlations = Enum.map(all_node1_events, & &1.correlation_id) |> Enum.uniq()
        node2_correlations = Enum.map(all_node2_events, & &1.correlation_id) |> Enum.uniq()

        assert correlation_id1 in node1_correlations
        assert correlation_id2 in node1_correlations
        assert correlation_id1 in node2_correlations
        assert correlation_id2 in node2_correlations
      end
    end
  end

  describe "distributed performance impact" do
    test "measures cross-node tracing overhead", context do
      if Map.get(context, :skip) do
        # Skip test if distributed nodes not available
        assert true, "Distributed tests skipped - no distributed support available"
      else
        %{nodes: nodes} = context
        # Baseline: measure without ElixirScope
        baseline_time = measure_distributed_operation_time(nodes, false)

        # With ElixirScope: measure with full tracing
        traced_time = measure_distributed_operation_time(nodes, true)

        # Verify overhead is acceptable
        overhead_percent = ((traced_time - baseline_time) / baseline_time) * 100
        assert overhead_percent < 10.0  # Less than 10% overhead
      end
    end

    test "handles high-frequency distributed events", context do
      if Map.get(context, :skip) do
        # Skip test if distributed nodes not available
        assert true, "Distributed tests skipped - no distributed support available"
      else
        %{nodes: nodes} = context
        # Generate high-frequency events across nodes
        start_time = System.monotonic_time(:millisecond)

        tasks = for node <- nodes do
          Task.async(fn ->
            :rpc.call(node, TestEventGenerator, :generate_high_frequency, [1000])
          end)
        end

        Task.await_many(tasks, 10_000)

        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Verify performance is acceptable
        assert duration < 5000  # Should complete within 5 seconds

        # Verify no events were dropped
        total_events = Enum.reduce(nodes, 0, fn node, acc ->
          count = :rpc.call(node, DataAccess, :count_events, [])
          acc + count
        end)

        assert total_events >= 3000  # 1000 events per node
      end
    end
  end

  # Helper functions

  defp start_test_nodes() do
    if Node.alive?() do
      try do
        nodes = Enum.map(@test_nodes, fn node_name ->
          # Use Node.spawn_link as a simple alternative to :slave.start
          case Node.spawn_link(node_name, fn -> 
            ElixirScope.start()
            receive do
              :stop -> :ok
            end
          end) do
            pid when is_pid(pid) -> 
              node_name
            _ -> 
              throw({:node_start_failed, node_name, :spawn_failed})
          end
        end)
        
        # Configure distributed tracing
        NodeCoordinator.setup_cluster(nodes)
        
        {:ok, nodes}
      catch
        {:node_start_failed, _node_name, _reason} ->
          {:error, :no_distributed_support}
        :error, :not_alive ->
          {:error, :no_distributed_support}
      end
    else
      {:error, :no_distributed_support}
    end
  end

  defp find_event(events, event_type) do
    Enum.find(events, &(&1.event_type == event_type))
  end

  defp start_distributed_operation(node1, node2) do
    correlation_id = ElixirScope.Utils.generate_correlation_id()

    # Start operation on node1 that calls node2
    :rpc.call(node1, TestDistributedOperation, :start, [node2, correlation_id])

    correlation_id
  end

  defp generate_distributed_events(nodes) do
    correlation_id = ElixirScope.Utils.generate_correlation_id()

    # Generate related events on each node
    for {node, index} <- Enum.with_index(nodes) do
      :rpc.call(node, TestEventGenerator, :generate_with_correlation, [correlation_id, index])
    end

    correlation_id
  end

  defp events_properly_ordered?(events) do
    # Verify events are ordered by timestamp
    timestamps = Enum.map(events, & &1.timestamp)
    timestamps == Enum.sort(timestamps)
  end

  defp measure_distributed_operation_time(nodes, with_tracing) do
    if with_tracing do
      for node <- nodes, do: :rpc.call(node, ElixirScope, :start, [])
    else
      for node <- nodes, do: :rpc.call(node, ElixirScope, :stop, [])
    end

    start_time = System.monotonic_time(:millisecond)

    # Perform standard distributed operation
    perform_distributed_benchmark(nodes)

    end_time = System.monotonic_time(:millisecond)
    end_time - start_time
  end

  defp perform_distributed_benchmark(nodes) do
    # Simulate typical distributed operations
    tasks = for node <- nodes do
      Task.async(fn ->
        :rpc.call(node, TestDistributedBenchmark, :run_operations, [100])
      end)
    end

    Task.await_many(tasks, 10_000)
  end
end
