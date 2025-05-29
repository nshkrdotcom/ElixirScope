defmodule ElixirScope.Capture.Ingestor.Channel do
  @moduledoc """
  Phoenix Channel-specific event ingestion functions for ElixirScope.

  Handles Phoenix channel join and message lifecycle events.
  """

  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Events
  alias ElixirScope.Utils

  @type ingest_result :: :ok | {:error, term()}

  @doc """
  Ingests a Phoenix channel join start event.
  """
  @spec ingest_phoenix_channel_join_start(RingBuffer.t(), term(), binary(), map(), term()) :: ingest_result()
  def ingest_phoenix_channel_join_start(buffer, correlation_id, topic, payload, socket) do
    event = Events.new_event(:phoenix_channel_join_start, %{
      topic: topic,
      payload: Utils.truncate_data(payload),
      socket: Utils.truncate_data(socket)
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a Phoenix channel join complete event.
  """
  @spec ingest_phoenix_channel_join_complete(RingBuffer.t(), term(), binary(), map(), term()) :: ingest_result()
  def ingest_phoenix_channel_join_complete(buffer, correlation_id, topic, payload, result) do
    event = Events.new_event(:phoenix_channel_join_complete, %{
      topic: topic,
      payload: Utils.truncate_data(payload),
      result: Utils.truncate_data(result)
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a Phoenix channel message start event.
  """
  @spec ingest_phoenix_channel_message_start(RingBuffer.t(), term(), binary(), map(), term()) :: ingest_result()
  def ingest_phoenix_channel_message_start(buffer, correlation_id, event, payload, socket) do
    event_struct = Events.new_event(:phoenix_channel_message_start, %{
      event: event,
      payload: Utils.truncate_data(payload),
      socket: Utils.truncate_data(socket)
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event_struct)
  end

  @doc """
  Ingests a Phoenix channel message complete event.
  """
  @spec ingest_phoenix_channel_message_complete(RingBuffer.t(), term(), binary(), map(), term()) :: ingest_result()
  def ingest_phoenix_channel_message_complete(buffer, correlation_id, event, payload, result) do
    event_struct = Events.new_event(:phoenix_channel_message_complete, %{
      event: event,
      payload: Utils.truncate_data(payload),
      result: Utils.truncate_data(result)
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event_struct)
  end
end
