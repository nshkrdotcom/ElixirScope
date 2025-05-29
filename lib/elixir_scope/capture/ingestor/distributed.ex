defmodule ElixirScope.Capture.Ingestor.Distributed do
  @moduledoc """
  Distributed system-specific event ingestion functions for ElixirScope.

  Handles node events, partitions, and distributed system monitoring.
  """

  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Events
  alias ElixirScope.Utils

  @type ingest_result :: :ok | {:error, term()}

  @doc """
  Ingests a node event.
  """
  @spec ingest_node_event(RingBuffer.t(), atom(), atom(), map()) :: ingest_result()
  def ingest_node_event(buffer, event_type, node_name, metadata) do
    event = %Events.NodeEvent{
      event_type: event_type,
      node_name: node_name,
      node_type: :visible,
      connection_id: nil,
      extra_info: Utils.truncate_data(metadata)
    }

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a partition detected event.
  """
  @spec ingest_partition_detected(RingBuffer.t(), list(atom()), map()) :: ingest_result()
  def ingest_partition_detected(buffer, partitioned_nodes, metadata) do
    event = Events.new_event(:partition_detected, %{
      partitioned_nodes: partitioned_nodes,
      metadata: Utils.truncate_data(metadata)
    })

    RingBuffer.write(buffer, event)
  end
end
