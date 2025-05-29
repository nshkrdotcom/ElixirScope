defmodule ElixirScope.Capture.InstrumentationRuntime.EctoReporting do
  @moduledoc """
  Ecto database integration reporting functionality.

  Handles Ecto-specific events including query execution start and completion.
  """

  alias ElixirScope.Capture.{RingBuffer, Ingestor}
  alias ElixirScope.Capture.InstrumentationRuntime.Context

  @type correlation_id :: Context.correlation_id()

  @doc """
  Reports Ecto query start.
  """
  @spec report_ecto_query_start(correlation_id(), String.t(), list(), map(), atom()) :: :ok
  def report_ecto_query_start(correlation_id, query, params, metadata, repo) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_ecto_query_start(buffer, correlation_id, query, params, metadata, repo)
      _ -> :ok
    end
  end

  @doc """
  Reports Ecto query completion.
  """
  @spec report_ecto_query_complete(correlation_id(), String.t(), list(), term(), non_neg_integer()) :: :ok
  def report_ecto_query_complete(correlation_id, query, params, result, duration_us) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_ecto_query_complete(buffer, correlation_id, query, params, result, duration_us)
      _ -> :ok
    end
  end
end
