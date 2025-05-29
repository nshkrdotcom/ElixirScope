defmodule ElixirScope.Capture.Ingestor.LiveView do
  @moduledoc """
  LiveView-specific event ingestion functions for ElixirScope.

  Handles LiveView mount, event handling, and callback lifecycle events.
  """

  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Events
  alias ElixirScope.Utils

  @type ingest_result :: :ok | {:error, term()}

  @doc """
  Ingests a LiveView mount start event.
  """
  @spec ingest_liveview_mount_start(RingBuffer.t(), term(), module(), map(), map()) :: ingest_result()
  def ingest_liveview_mount_start(buffer, correlation_id, module, params, session) do
    event = Events.new_event(:liveview_mount_start, %{
      module: module,
      params: Utils.truncate_data(params),
      session: Utils.truncate_data(session)
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a LiveView mount complete event.
  """
  @spec ingest_liveview_mount_complete(RingBuffer.t(), term(), module(), map()) :: ingest_result()
  def ingest_liveview_mount_complete(buffer, correlation_id, module, socket_assigns) do
    event = Events.new_event(:liveview_mount_complete, %{
      module: module,
      socket_assigns: Utils.truncate_data(socket_assigns)
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests a LiveView handle_event start event.
  """
  @spec ingest_liveview_handle_event_start(RingBuffer.t(), term(), binary(), map(), map()) :: ingest_result()
  def ingest_liveview_handle_event_start(buffer, correlation_id, event, params, socket_assigns) do
    event_struct = Events.new_event(:liveview_handle_event_start, %{
      event: event,
      params: Utils.truncate_data(params),
      socket_assigns: Utils.truncate_data(socket_assigns)
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event_struct)
  end

  @doc """
  Ingests a LiveView handle_event complete event.
  """
  @spec ingest_liveview_handle_event_complete(RingBuffer.t(), term(), binary(), map(), map(), term()) :: ingest_result()
  def ingest_liveview_handle_event_complete(buffer, correlation_id, event, params, before_assigns, result) do
    event_struct = Events.new_event(:liveview_handle_event_complete, %{
      event: event,
      params: Utils.truncate_data(params),
      before_assigns: Utils.truncate_data(before_assigns),
      result: Utils.truncate_data(result)
    }, [correlation_id: correlation_id])

    RingBuffer.write(buffer, event_struct)
  end

  @doc """
  Ingests LiveView assigns change event.
  """
  @spec ingest_liveview_assigns(RingBuffer.t(), atom(), term()) :: ingest_result()
  def ingest_liveview_assigns(buffer, callback_name, socket) do
    event = Events.new_event(:liveview_assigns_change, %{
      callback_name: callback_name,
      socket: Utils.truncate_data(socket)
    })

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests LiveView event.
  """
  @spec ingest_liveview_event(RingBuffer.t(), binary(), map(), term()) :: ingest_result()
  def ingest_liveview_event(buffer, event, params, socket) do
    event_struct = Events.new_event(:liveview_event, %{
      event: event,
      params: Utils.truncate_data(params),
      socket: Utils.truncate_data(socket)
    })

    RingBuffer.write(buffer, event_struct)
  end

  @doc """
  Ingests LiveView callback event.
  """
  @spec ingest_liveview_callback(RingBuffer.t(), atom(), term()) :: ingest_result()
  def ingest_liveview_callback(buffer, callback_name, socket) do
    event = Events.new_event(:liveview_callback, %{
      callback_name: callback_name,
      socket: Utils.truncate_data(socket)
    })

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests LiveView callback success event.
  """
  @spec ingest_liveview_callback_success(RingBuffer.t(), atom(), term(), term()) :: ingest_result()
  def ingest_liveview_callback_success(buffer, callback_name, socket, result) do
    event = Events.new_event(:liveview_callback_success, %{
      callback_name: callback_name,
      socket: Utils.truncate_data(socket),
      result: Utils.truncate_data(result)
    })

    RingBuffer.write(buffer, event)
  end

  @doc """
  Ingests LiveView callback error event.
  """
  @spec ingest_liveview_callback_error(RingBuffer.t(), atom(), term(), atom(), term()) :: ingest_result()
  def ingest_liveview_callback_error(buffer, callback_name, socket, kind, reason) do
    event = Events.new_event(:liveview_callback_error, %{
      callback_name: callback_name,
      socket: Utils.truncate_data(socket),
      kind: kind,
      reason: Utils.truncate_data(reason)
    })

    RingBuffer.write(buffer, event)
  end
end
