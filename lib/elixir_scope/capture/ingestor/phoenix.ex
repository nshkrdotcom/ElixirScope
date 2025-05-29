defmodule ElixirScope.Capture.Ingestor.Phoenix do
  @moduledoc """
  Phoenix-specific event ingestion functions for ElixirScope.

  Handles Phoenix request lifecycle, controller actions, and related events.
  """

  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Events
  alias ElixirScope.Utils

  @type ingest_result :: :ok | {:error, term()}

  @doc """
  Ingests a Phoenix request start event.
  """
  @spec ingest_phoenix_request_start(RingBuffer.t(), term(), binary(), binary(), map(), binary()) :: ingest_result()
  def ingest_phoenix_request_start(buffer, correlation_id, method, path, params, remote_ip) do
    event = Events.new_event(:phoenix_request_start, %{
      method: method,
      path: path,
      params: Utils.truncate_data(params),
      remote_ip: remote_ip
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a Phoenix request complete event.
  """
  @spec ingest_phoenix_request_complete(RingBuffer.t(), term(), integer(), binary(), number()) :: ingest_result()
  def ingest_phoenix_request_complete(buffer, correlation_id, status_code, content_type, duration_ms) do
    event = Events.new_event(:phoenix_request_complete, %{
      status_code: status_code,
      content_type: content_type,
      duration_ms: duration_ms
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a Phoenix controller entry event.
  """
  @spec ingest_phoenix_controller_entry(RingBuffer.t(), term(), module(), atom(), map()) :: ingest_result()
  def ingest_phoenix_controller_entry(buffer, correlation_id, controller, action, metadata) do
    event = Events.new_event(:phoenix_controller_entry, %{
      controller: controller,
      action: action,
      metadata: Utils.truncate_data(metadata)
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a Phoenix controller exit event.
  """
  @spec ingest_phoenix_controller_exit(RingBuffer.t(), term(), module(), atom(), term()) :: ingest_result()
  def ingest_phoenix_controller_exit(buffer, correlation_id, controller, action, result) do
    event = Events.new_event(:phoenix_controller_exit, %{
      controller: controller,
      action: action,
      result: Utils.truncate_data(result)
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests Phoenix action parameters.
  """
  @spec ingest_phoenix_action_params(RingBuffer.t(), atom(), term(), map()) :: ingest_result()
  def ingest_phoenix_action_params(buffer, action_name, conn, params) do
    event = Events.new_event(:phoenix_action_params, %{
      action_name: action_name,
      conn: Utils.truncate_data(conn),
      params: Utils.truncate_data(params)
    })

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests Phoenix action start event.
  """
  @spec ingest_phoenix_action_start(RingBuffer.t(), atom(), term()) :: ingest_result()
  def ingest_phoenix_action_start(buffer, action_name, conn) do
    event = Events.new_event(:phoenix_action_start, %{
      action_name: action_name,
      conn: Utils.truncate_data(conn)
    })

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests Phoenix action success event.
  """
  @spec ingest_phoenix_action_success(RingBuffer.t(), atom(), term(), term()) :: ingest_result()
  def ingest_phoenix_action_success(buffer, action_name, conn, result) do
    event = Events.new_event(:phoenix_action_success, %{
      action_name: action_name,
      conn: Utils.truncate_data(conn),
      result: Utils.truncate_data(result)
    })

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests Phoenix action error event.
  """
  @spec ingest_phoenix_action_error(RingBuffer.t(), atom(), term(), atom(), term()) :: ingest_result()
  def ingest_phoenix_action_error(buffer, action_name, conn, kind, reason) do
    event = Events.new_event(:phoenix_action_error, %{
      action_name: action_name,
      conn: Utils.truncate_data(conn),
      kind: kind,
      reason: Utils.truncate_data(reason)
    })

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests Phoenix action complete event.
  """
  @spec ingest_phoenix_action_complete(RingBuffer.t(), atom(), term()) :: ingest_result()
  def ingest_phoenix_action_complete(buffer, action_name, conn) do
    event = Events.new_event(:phoenix_action_complete, %{
      action_name: action_name,
      conn: Utils.truncate_data(conn)
    })

    RingBuffer.write(buffer, event)
  end
end
