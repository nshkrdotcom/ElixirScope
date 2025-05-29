defmodule ElixirScope.Capture.InstrumentationRuntime.GenServerReporting do
  @moduledoc """
  GenServer integration reporting functionality.

  Handles GenServer-specific events including callback start, success,
  error, and completion events.
  """

  alias ElixirScope.Capture.{RingBuffer, Ingestor}
  alias ElixirScope.Capture.InstrumentationRuntime.Context

  @doc """
  Reports GenServer callback start.
  """
  @spec report_genserver_callback_start(atom(), pid(), boolean()) :: :ok
  def report_genserver_callback_start(callback_name, pid, capture_state) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_genserver_callback_start(buffer, callback_name, pid, capture_state)
      _ -> :ok
    end
  end

  @doc """
  Reports GenServer callback success.
  """
  @spec report_genserver_callback_success(atom(), pid(), term()) :: :ok
  def report_genserver_callback_success(callback_name, pid, result) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_genserver_callback_success(buffer, callback_name, pid, result)
      _ -> :ok
    end
  end

  @doc """
  Reports GenServer callback error.
  """
  @spec report_genserver_callback_error(atom(), pid(), atom(), term()) :: :ok
  def report_genserver_callback_error(callback_name, pid, kind, reason) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_genserver_callback_error(buffer, callback_name, pid, kind, reason)
      _ -> :ok
    end
  end

  @doc """
  Reports GenServer callback completion.
  """
  @spec report_genserver_callback_complete(atom(), pid(), boolean()) :: :ok
  def report_genserver_callback_complete(callback_name, pid, capture_state) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_genserver_callback_complete(buffer, callback_name, pid, capture_state)
      _ -> :ok
    end
  end
end
