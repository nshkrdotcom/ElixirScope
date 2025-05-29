defmodule ElixirScope.Capture.Ingestor.GenServer do
  @moduledoc """
  GenServer-specific event ingestion functions for ElixirScope.

  Handles GenServer callback lifecycle events and state changes.
  """

  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Events
  alias ElixirScope.Utils

  @type ingest_result :: :ok | {:error, term()}

  @doc """
  Ingests a GenServer callback start event.
  """
  @spec ingest_genserver_callback_start(RingBuffer.t(), atom(), pid(), term()) :: ingest_result()
  def ingest_genserver_callback_start(buffer, callback_name, pid, capture_state) do
    event = %Events.StateChange{
      server_pid: pid,
      callback: callback_name,
      old_state: Utils.truncate_data(capture_state),
      new_state: nil,
      state_diff: nil,
      trigger_message: nil,
      trigger_call_id: nil
    }

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a GenServer callback success event.
  """
  @spec ingest_genserver_callback_success(RingBuffer.t(), atom(), pid(), term()) :: ingest_result()
  def ingest_genserver_callback_success(buffer, callback_name, pid, result) do
    event = %Events.StateChange{
      server_pid: pid,
      callback: callback_name,
      old_state: nil,
      new_state: Utils.truncate_data(result),
      state_diff: nil,
      trigger_message: nil,
      trigger_call_id: nil
    }

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a GenServer callback error event.
  """
  @spec ingest_genserver_callback_error(RingBuffer.t(), atom(), pid(), atom(), term()) :: ingest_result()
  def ingest_genserver_callback_error(buffer, callback_name, pid, kind, reason) do
    event = %Events.ErrorEvent{
      error_type: kind,
      error_class: :genserver_callback,
      error_message: Utils.truncate_data(reason),
      stacktrace: nil,
      context: %{callback: callback_name, pid: pid},
      recovery_action: nil
    }

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a GenServer callback complete event.
  """
  @spec ingest_genserver_callback_complete(RingBuffer.t(), atom(), pid(), term()) :: ingest_result()
  def ingest_genserver_callback_complete(buffer, callback_name, pid, capture_state) do
    event = %Events.StateChange{
      server_pid: pid,
      callback: callback_name,
      old_state: nil,
      new_state: Utils.truncate_data(capture_state),
      state_diff: nil,
      trigger_message: nil,
      trigger_call_id: nil
    }

    RingBuffer.write(buffer, event)
  end
end
