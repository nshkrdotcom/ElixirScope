defmodule ElixirScope.Distributed.EventSynchronizer do
  @moduledoc """
  Synchronizes events across distributed ElixirScope nodes.

  Handles:
  - Efficient event delta synchronization
  - Conflict resolution for overlapping events
  - Bandwidth optimization for large event sets
  - Eventual consistency guarantees
  """

  alias ElixirScope.Storage.DataAccess
  alias ElixirScope.Distributed.GlobalClock

  @sync_batch_size 1000
  @max_sync_age_ms 300_000  # 5 minutes

  @doc """
  Synchronizes events with all nodes in the cluster.
  """
  def sync_with_cluster(cluster_nodes) do
    local_node = node()
    other_nodes = Enum.reject(cluster_nodes, &(&1 == local_node))

    # Get local sync state
    last_sync_times = get_last_sync_times(other_nodes)

    # Sync with each node
    sync_results = for node <- other_nodes do
      sync_with_node(node, last_sync_times[node])
    end

    # Update sync timestamps
    now = GlobalClock.now()
    update_sync_timestamps(other_nodes, now)

    {:ok, sync_results}
  end

  @doc """
  Synchronizes events with a specific node.
  """
  def sync_with_node(target_node, last_sync_time \\ nil) do
    try do
      # Get events since last sync
      since_time = last_sync_time || (GlobalClock.now() - @max_sync_age_ms * 1_000_000)
      local_events = DataAccess.get_events_since(since_time)

      # Send our events and get theirs
      sync_request = %{
        from_node: node(),
        since_time: since_time,
        events: prepare_events_for_sync(local_events)
      }

      case :rpc.call(target_node, __MODULE__, :handle_sync_request, [sync_request]) do
        {:ok, remote_events} ->
          # Store remote events locally
          store_remote_events(remote_events, target_node)
          {:ok, length(remote_events)}

        {:error, reason} ->
          {:error, {target_node, reason}}

        {:badrpc, reason} ->
          {:error, {target_node, :unreachable, reason}}
      end
    rescue
      error -> {:error, {target_node, error}}
    end
  end

  @doc """
  Handles incoming synchronization requests from other nodes.
  """
  def handle_sync_request(%{from_node: from_node, since_time: since_time, events: remote_events}) do
    try do
      # Store remote events
      store_remote_events(remote_events, from_node)

      # Get our events since the requested time
      local_events = DataAccess.get_events_since(since_time)
      prepared_events = prepare_events_for_sync(local_events)

      {:ok, prepared_events}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Forces a full synchronization with all cluster nodes.
  """
  def full_sync_with_cluster(cluster_nodes) do
    # Clear sync timestamps to force full sync
    clear_sync_timestamps()
    sync_with_cluster(cluster_nodes)
  end

  ## Private Functions

  defp get_last_sync_times(nodes) do
    Enum.reduce(nodes, %{}, fn node, acc ->
      last_sync = get_last_sync_time(node)
      Map.put(acc, node, last_sync)
    end)
  end

  defp get_last_sync_time(node) do
    case :ets.lookup(:elixir_scope_sync_state, {:last_sync, node}) do
      [{_, timestamp}] -> timestamp
      [] -> nil
    end
  end

  defp update_sync_timestamps(nodes, timestamp) do
    ensure_sync_table_exists()

    for node <- nodes do
      :ets.insert(:elixir_scope_sync_state, {{:last_sync, node}, timestamp})
    end
  end

  defp clear_sync_timestamps do
    ensure_sync_table_exists()
    :ets.delete_all_objects(:elixir_scope_sync_state)
  end

  defp ensure_sync_table_exists do
    case :ets.whereis(:elixir_scope_sync_state) do
      :undefined ->
        :ets.new(:elixir_scope_sync_state, [:named_table, :public, :set])
      _ ->
        :ok
    end
  end

  defp prepare_events_for_sync(events) do
    # Compress events and remove large payloads for efficient transfer
    Enum.map(events, fn event ->
      %{
        id: event.id,
        timestamp: event.timestamp,
        wall_time: event.wall_time,
        node: event.node,
        pid: event.pid,
        correlation_id: event.correlation_id,
        event_type: event.event_type,
        data: compress_event_data(event.data),
        checksum: calculate_event_checksum(event)
      }
    end)
  end

  defp compress_event_data(data) do
    if byte_size(:erlang.term_to_binary(data)) > 10000 do
      # Large data - compress or truncate
      compressed = :zlib.compress(:erlang.term_to_binary(data))
      {:compressed, compressed}
    else
      data
    end
  end

  defp calculate_event_checksum(event) do
    event
    |> :erlang.term_to_binary()
    |> :erlang.md5()
    |> Base.encode16()
  end

  defp store_remote_events(remote_events, source_node) do
    # Process events in batches to avoid overwhelming the system
    remote_events
    |> Enum.chunk_every(@sync_batch_size)
    |> Enum.each(fn batch ->
      processed_batch = Enum.map(batch, fn event ->
        restore_event_from_sync(event, source_node)
      end)

      # Filter out events we already have
      new_events = Enum.reject(processed_batch, fn event ->
        DataAccess.event_exists?(event.id)
      end)

      # Store new events
      if length(new_events) > 0 do
        DataAccess.store_events(new_events)
      end
    end)
  end

  defp restore_event_from_sync(sync_event, _source_node) do
    restored_data = case sync_event.data do
      {:compressed, compressed_data} ->
        compressed_data
        |> :zlib.uncompress()
        |> :erlang.binary_to_term()

      regular_data ->
        regular_data
    end

    %ElixirScope.Events{
      event_id: sync_event.id,
      timestamp: sync_event.timestamp,
      wall_time: sync_event.wall_time,
      node: sync_event.node,
      pid: sync_event.pid,
      correlation_id: sync_event.correlation_id,
      event_type: sync_event.event_type,
      data: restored_data
    }
  end
end
