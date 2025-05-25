defmodule ElixirScope.Distributed.GlobalClock do
  @moduledoc """
  Distributed global clock for ElixirScope event synchronization.
  
  Provides logical timestamps and clock synchronization across distributed nodes.
  Uses hybrid logical clocks for ordering events across the cluster.
  """

  use GenServer
  
  defstruct [
    :logical_time,
    :wall_time_offset,
    :node_id,
    :cluster_nodes,
    :sync_interval
  ]

  @sync_interval 30_000  # 30 seconds

  ## Public API

  @doc """
  Starts the global clock GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current logical timestamp.
  """
  def now do
    case GenServer.call(__MODULE__, :now, 5000) do
      {:ok, timestamp} -> timestamp
      {:error, _} -> fallback_timestamp()
    end
  catch
    :exit, _ -> fallback_timestamp()
  end

  @doc """
  Updates the clock with a timestamp from another node.
  """
  def update_from_remote(remote_timestamp, remote_node) do
    GenServer.cast(__MODULE__, {:update_from_remote, remote_timestamp, remote_node})
  end

  @doc """
  Synchronizes the clock with all known cluster nodes.
  """
  def sync_with_cluster do
    GenServer.cast(__MODULE__, :sync_with_cluster)
  end

  @doc """
  Initializes the cluster with the given nodes.
  """
  def initialize_cluster(nodes) do
    GenServer.cast(__MODULE__, {:initialize_cluster, nodes})
  end

  @doc """
  Gets the current state of the global clock.
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  ## GenServer Implementation

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, node())
    sync_interval = Keyword.get(opts, :sync_interval, @sync_interval)
    
    state = %__MODULE__{
      logical_time: 0,
      wall_time_offset: calculate_wall_time_offset(),
      node_id: node_id,
      cluster_nodes: [],
      sync_interval: sync_interval
    }

    # Schedule periodic synchronization
    schedule_sync(sync_interval)

    {:ok, state}
  end

  @impl true
  def handle_call(:now, _from, state) do
    new_logical_time = state.logical_time + 1
    timestamp = generate_timestamp(new_logical_time, state)
    
    new_state = %{state | logical_time: new_logical_time}
    {:reply, {:ok, timestamp}, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update_from_remote, remote_timestamp, _remote_node}, state) do
    {remote_logical, remote_wall, _remote_node} = parse_timestamp(remote_timestamp)
    
    # Update logical time to max(local, remote) + 1
    new_logical_time = max(state.logical_time, remote_logical) + 1
    
    # Adjust wall time offset if needed
    new_wall_time_offset = adjust_wall_time_offset(state.wall_time_offset, remote_wall)
    
    new_state = %{state | 
      logical_time: new_logical_time,
      wall_time_offset: new_wall_time_offset
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:initialize_cluster, nodes}, state) do
    new_state = %{state | cluster_nodes: nodes}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:sync_with_cluster, state) do
    perform_cluster_sync(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:sync_tick, state) do
    perform_cluster_sync(state)
    schedule_sync(state.sync_interval)
    {:noreply, state}
  end

  ## Private Functions

  defp generate_timestamp(logical_time, state) do
    wall_time = :os.system_time(:microsecond) + state.wall_time_offset
    
    # Format: {logical_time, wall_time, node_id}
    {logical_time, wall_time, state.node_id}
  end

  defp parse_timestamp({logical_time, wall_time, node_id}) do
    {logical_time, wall_time, node_id}
  end
  defp parse_timestamp(timestamp) when is_integer(timestamp) do
    # Fallback for simple timestamps
    {timestamp, :os.system_time(:microsecond), node()}
  end

  defp calculate_wall_time_offset do
    # For now, no offset - could be enhanced with NTP synchronization
    0
  end

  defp adjust_wall_time_offset(current_offset, remote_wall_time) do
    local_wall_time = :os.system_time(:microsecond)
    time_diff = remote_wall_time - local_wall_time
    
    # Gradual adjustment to avoid clock jumps
    if abs(time_diff) > 1_000_000 do  # More than 1 second difference
      current_offset + div(time_diff, 10)  # Adjust by 10%
    else
      current_offset
    end
  end

  defp perform_cluster_sync(state) do
    current_timestamp = generate_timestamp(state.logical_time, state)
    
    for node <- state.cluster_nodes, node != state.node_id do
      try do
        :rpc.cast(node, __MODULE__, :update_from_remote, [current_timestamp, state.node_id])
      catch
        _, _ -> :ok  # Ignore failed sync attempts
      end
    end
  end

  defp schedule_sync(interval) do
    Process.send_after(self(), :sync_tick, interval)
  end

  defp fallback_timestamp do
    # Fallback when GenServer is not available
    :os.system_time(:microsecond)
  end
end 