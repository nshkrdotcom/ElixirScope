defmodule ElixirScope.Distributed.NodeCoordinator do
  @moduledoc """
  Coordinates ElixirScope tracing across multiple BEAM nodes.

  Handles:
  - Node discovery and registration
  - Event synchronization across nodes
  - Distributed correlation ID management
  - Network partition handling
  - Cross-node query coordination
  """

  use GenServer

  alias ElixirScope.Distributed.EventSynchronizer
  alias ElixirScope.Distributed.GlobalClock
  alias ElixirScope.Storage.DataAccess

  defstruct [
    :local_node,
    :cluster_nodes,
    :sync_interval,
    :partition_detector,
    :global_clock
  ]

  @sync_interval_ms 1000
  @partition_check_interval_ms 5000

  ## Public API

  @doc """
  Starts the NodeCoordinator for the local node.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sets up ElixirScope cluster with the given nodes.
  """
  def setup_cluster(nodes) do
    # Start coordinator on each node
    for node <- nodes do
      :rpc.call(node, __MODULE__, :start_link, [[cluster_nodes: nodes]])
    end

    # Wait for all nodes to be ready
    Process.sleep(100)

    # Initialize global clock synchronization
    GlobalClock.initialize_cluster(nodes)

    :ok
  end

  @doc """
  Registers a new node with the cluster.
  """
  def register_node(node) do
    GenServer.call(__MODULE__, {:register_node, node})
  end

  @doc """
  Gets all nodes currently in the cluster.
  """
  def get_cluster_nodes do
    GenServer.call(__MODULE__, :get_cluster_nodes)
  end

  @doc """
  Synchronizes events across all cluster nodes.
  """
  def sync_events do
    GenServer.call(__MODULE__, :sync_events)
  end

  @doc """
  Queries events across all nodes in the cluster.
  """
  def distributed_query(query_params) do
    GenServer.call(__MODULE__, {:distributed_query, query_params})
  end

  ## GenServer Implementation

  @impl true
  def init(opts) do
    cluster_nodes = Keyword.get(opts, :cluster_nodes, [node()])

    state = %__MODULE__{
      local_node: node(),
      cluster_nodes: cluster_nodes,
      sync_interval: @sync_interval_ms,
      partition_detector: nil,
      global_clock: nil
    }

    # Monitor node connections
    :net_kernel.monitor_nodes(true)

    # Schedule periodic synchronization
    schedule_sync()
    schedule_partition_check()

    {:ok, state}
  end

  @impl true
  def handle_call({:register_node, new_node}, _from, state) do
    if new_node not in state.cluster_nodes do
      updated_nodes = [new_node | state.cluster_nodes]
      updated_state = %{state | cluster_nodes: updated_nodes}

      # Notify other nodes about the new member
      notify_cluster_change(updated_nodes, {:node_joined, new_node})

      {:reply, :ok, updated_state}
    else
      {:reply, :already_registered, state}
    end
  end

  @impl true
  def handle_call(:get_cluster_nodes, _from, state) do
    {:reply, state.cluster_nodes, state}
  end

  @impl true
  def handle_call(:sync_events, _from, state) do
    result = perform_event_sync(state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:distributed_query, query_params}, _from, state) do
    results = execute_distributed_query(query_params, state)
    {:reply, results, state}
  end

  @impl true
  def handle_info(:periodic_sync, state) do
    perform_event_sync(state)
    schedule_sync()
    {:noreply, state}
  end

  @impl true
  def handle_info(:check_partitions, state) do
    updated_state = check_for_partitions(state)
    schedule_partition_check()
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    ElixirScope.Capture.InstrumentationRuntime.report_node_event(
      :nodeup,
      node,
      System.monotonic_time()
    )

    # Attempt to add node to cluster if it's running ElixirScope
    case :rpc.call(node, __MODULE__, :register_node, [state.local_node]) do
      :ok ->
        updated_state = %{state | cluster_nodes: [node | state.cluster_nodes]}
        {:noreply, updated_state}
      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    ElixirScope.Capture.InstrumentationRuntime.report_node_event(
      :nodedown,
      node,
      System.monotonic_time()
    )

    # Remove node from cluster
    updated_nodes = List.delete(state.cluster_nodes, node)
    updated_state = %{state | cluster_nodes: updated_nodes}

    # Notify remaining nodes
    notify_cluster_change(updated_nodes, {:node_left, node})

    {:noreply, updated_state}
  end

  ## Private Functions

  defp schedule_sync do
    Process.send_after(self(), :periodic_sync, @sync_interval_ms)
  end

  defp schedule_partition_check do
    Process.send_after(self(), :check_partitions, @partition_check_interval_ms)
  end

  defp perform_event_sync(state) do
    try do
      EventSynchronizer.sync_with_cluster(state.cluster_nodes)
    rescue
      error ->
        Logger.warning("Event sync failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp execute_distributed_query(query_params, state) do
    # Execute query on all reachable nodes
    query_tasks = for node <- state.cluster_nodes do
      Task.async(fn ->
        case :rpc.call(node, DataAccess, :query_events, [query_params]) do
          {:badrpc, reason} -> {:error, {node, reason}}
          result -> {:ok, {node, result}}
        end
      end)
    end

    # Collect results with timeout
    results = Task.await_many(query_tasks, 5000)

    # Merge successful results
    successful_results =
      results
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, {node, events}} -> {node, events} end)

    # Combine and deduplicate events
    all_events =
      successful_results
      |> Enum.flat_map(fn {_node, events} -> events end)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.timestamp)

    {:ok, all_events}
  end

  defp check_for_partitions(state) do
    # Check connectivity to all cluster nodes
    reachable_nodes = Enum.filter(state.cluster_nodes, fn node ->
      node == state.local_node or Node.ping(node) == :pong
    end)

    unreachable_nodes = state.cluster_nodes -- reachable_nodes

    if length(unreachable_nodes) > 0 do
      ElixirScope.Capture.InstrumentationRuntime.report_partition_detected(
        unreachable_nodes,
        System.monotonic_time()
      )
    end

    %{state | cluster_nodes: reachable_nodes}
  end

  defp notify_cluster_change(nodes, change_event) do
    for node <- nodes do
      if node != node() do
        :rpc.cast(node, __MODULE__, :handle_cluster_change, [change_event])
      end
    end
  end

  def handle_cluster_change(change_event) do
    GenServer.cast(__MODULE__, {:cluster_change, change_event})
  end
end
