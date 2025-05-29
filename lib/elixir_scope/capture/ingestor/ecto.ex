defmodule ElixirScope.Capture.Ingestor.Ecto do
  @moduledoc """
  Ecto-specific event ingestion functions for ElixirScope.

  Handles Ecto query lifecycle events and database operations.
  """

  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Events
  alias ElixirScope.Utils

  @type ingest_result :: :ok | {:error, term()}

  @doc """
  Ingests an Ecto query start event.
  """
  @spec ingest_ecto_query_start(RingBuffer.t(), term(), term(), list(), map(), module()) :: ingest_result()
  def ingest_ecto_query_start(buffer, correlation_id, query, params, metadata, repo) do
    event = Events.new_event(:ecto_query_start, %{
      query: Utils.truncate_data(query),
      params: Utils.truncate_data(params),
      metadata: Utils.truncate_data(metadata),
      repo: repo
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests an Ecto query complete event.
  """
  @spec ingest_ecto_query_complete(RingBuffer.t(), term(), term(), list(), term(), non_neg_integer()) :: ingest_result()
  def ingest_ecto_query_complete(buffer, correlation_id, query, params, result, duration_us) do
    event = Events.new_event(:ecto_query_complete, %{
      query: Utils.truncate_data(query),
      params: Utils.truncate_data(params),
      result: Utils.truncate_data(result),
      duration_us: duration_us
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event)
  end
end
