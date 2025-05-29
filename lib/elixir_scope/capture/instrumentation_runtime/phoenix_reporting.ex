defmodule ElixirScope.Capture.InstrumentationRuntime.PhoenixReporting do
  @moduledoc """
  Phoenix framework integration reporting functionality.

  Handles Phoenix-specific events including HTTP requests, controllers,
  LiveView events, and Phoenix channels.
  """

  alias ElixirScope.Capture.{RingBuffer, Ingestor}
  alias ElixirScope.Capture.InstrumentationRuntime.Context

  @type correlation_id :: Context.correlation_id()

  # Phoenix HTTP Request Functions

  @doc """
  Reports Phoenix request start.
  """
  @spec report_phoenix_request_start(correlation_id(), String.t(), String.t(), map(), tuple()) :: :ok
  def report_phoenix_request_start(correlation_id, method, path, params, remote_ip) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_request_start(buffer, correlation_id, method, path, params, remote_ip)
      _ -> :ok
    end
  end

  @doc """
  Reports Phoenix request completion.
  """
  @spec report_phoenix_request_complete(correlation_id(), integer(), String.t(), non_neg_integer()) :: :ok
  def report_phoenix_request_complete(correlation_id, status_code, content_type, duration_ms) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_request_complete(buffer, correlation_id, status_code, content_type, duration_ms)
      _ -> :ok
    end
  end

  @doc """
  Reports Phoenix controller entry.
  """
  @spec report_phoenix_controller_entry(correlation_id(), module(), atom(), map()) :: :ok
  def report_phoenix_controller_entry(correlation_id, controller, action, metadata) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_controller_entry(buffer, correlation_id, controller, action, metadata)
      _ -> :ok
    end
  end

  @doc """
  Reports Phoenix controller exit.
  """
  @spec report_phoenix_controller_exit(correlation_id(), module(), atom(), term()) :: :ok
  def report_phoenix_controller_exit(correlation_id, controller, action, result) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_controller_exit(buffer, correlation_id, controller, action, result)
      _ -> :ok
    end
  end

  # Phoenix Action Functions (for InjectorHelpers compatibility)

  @doc """
  Reports Phoenix action parameters.
  """
  @spec report_phoenix_action_params(atom(), map(), map(), boolean()) :: :ok
  def report_phoenix_action_params(action_name, conn, params, should_capture) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) and should_capture ->
        Ingestor.ingest_phoenix_action_params(buffer, action_name, conn, params)
      _ -> :ok
    end
  end

  @doc """
  Reports Phoenix action start.
  """
  @spec report_phoenix_action_start(atom(), map(), boolean()) :: :ok
  def report_phoenix_action_start(action_name, conn, should_capture_state) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) and should_capture_state ->
        Ingestor.ingest_phoenix_action_start(buffer, action_name, conn)
      _ -> :ok
    end
  end

  @doc """
  Reports Phoenix action success.
  """
  @spec report_phoenix_action_success(atom(), map(), term()) :: :ok
  def report_phoenix_action_success(action_name, conn, result) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_action_success(buffer, action_name, conn, result)
      _ -> :ok
    end
  end

  @doc """
  Reports Phoenix action error.
  """
  @spec report_phoenix_action_error(atom(), map(), atom(), term()) :: :ok
  def report_phoenix_action_error(action_name, conn, kind, reason) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_action_error(buffer, action_name, conn, kind, reason)
      _ -> :ok
    end
  end

  @doc """
  Reports Phoenix action completion.
  """
  @spec report_phoenix_action_complete(atom(), map(), boolean()) :: :ok
  def report_phoenix_action_complete(action_name, conn, should_capture_response) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) and should_capture_response ->
        Ingestor.ingest_phoenix_action_complete(buffer, action_name, conn)
      _ -> :ok
    end
  end

  # LiveView Integration Functions

  @doc """
  Reports LiveView mount start.
  """
  @spec report_liveview_mount_start(correlation_id(), module(), map(), map()) :: :ok
  def report_liveview_mount_start(correlation_id, module, params, session) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_liveview_mount_start(buffer, correlation_id, module, params, session)
      _ -> :ok
    end
  end

  @doc """
  Reports LiveView mount completion.
  """
  @spec report_liveview_mount_complete(correlation_id(), module(), map()) :: :ok
  def report_liveview_mount_complete(correlation_id, module, socket_assigns) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_liveview_mount_complete(buffer, correlation_id, module, socket_assigns)
      _ -> :ok
    end
  end

  @doc """
  Reports LiveView handle_event start.
  """
  @spec report_liveview_handle_event_start(correlation_id(), String.t(), map(), map()) :: :ok
  def report_liveview_handle_event_start(correlation_id, event, params, socket_assigns) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_liveview_handle_event_start(buffer, correlation_id, event, params, socket_assigns)
      _ -> :ok
    end
  end

  @doc """
  Reports LiveView handle_event completion.
  """
  @spec report_liveview_handle_event_complete(correlation_id(), String.t(), map(), map(), term()) :: :ok
  def report_liveview_handle_event_complete(correlation_id, event, params, before_assigns, result) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_liveview_handle_event_complete(buffer, correlation_id, event, params, before_assigns, result)
      _ -> :ok
    end
  end

  @doc """
  Reports LiveView assigns.
  """
  @spec report_liveview_assigns(atom(), map(), boolean()) :: :ok
  def report_liveview_assigns(callback_name, socket, should_capture) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) and should_capture ->
        Ingestor.ingest_liveview_assigns(buffer, callback_name, socket)
      _ -> :ok
    end
  end

  @doc """
  Reports LiveView event.
  """
  @spec report_liveview_event(String.t(), map(), map(), boolean()) :: :ok
  def report_liveview_event(event, params, socket, should_capture) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) and should_capture ->
        Ingestor.ingest_liveview_event(buffer, event, params, socket)
      _ -> :ok
    end
  end

  @doc """
  Reports LiveView callback.
  """
  @spec report_liveview_callback(atom(), map()) :: :ok
  def report_liveview_callback(callback_name, socket) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_liveview_callback(buffer, callback_name, socket)
      _ -> :ok
    end
  end

  @doc """
  Reports LiveView callback success.
  """
  @spec report_liveview_callback_success(atom(), map(), term()) :: :ok
  def report_liveview_callback_success(callback_name, socket, result) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_liveview_callback_success(buffer, callback_name, socket, result)
      _ -> :ok
    end
  end

  @doc """
  Reports LiveView callback error.
  """
  @spec report_liveview_callback_error(atom(), map(), atom(), term()) :: :ok
  def report_liveview_callback_error(callback_name, socket, kind, reason) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_liveview_callback_error(buffer, callback_name, socket, kind, reason)
      _ -> :ok
    end
  end

  # Phoenix Channel Functions

  @doc """
  Reports Phoenix channel join start.
  """
  @spec report_phoenix_channel_join_start(correlation_id(), String.t(), map(), map()) :: :ok
  def report_phoenix_channel_join_start(correlation_id, topic, payload, socket) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_channel_join_start(buffer, correlation_id, topic, payload, socket)
      _ -> :ok
    end
  end

  @doc """
  Reports Phoenix channel join completion.
  """
  @spec report_phoenix_channel_join_complete(correlation_id(), String.t(), map(), term()) :: :ok
  def report_phoenix_channel_join_complete(correlation_id, topic, payload, result) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_channel_join_complete(buffer, correlation_id, topic, payload, result)
      _ -> :ok
    end
  end

  @doc """
  Reports Phoenix channel message start.
  """
  @spec report_phoenix_channel_message_start(correlation_id(), String.t(), map(), map()) :: :ok
  def report_phoenix_channel_message_start(correlation_id, event, payload, socket) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_channel_message_start(buffer, correlation_id, event, payload, socket)
      _ -> :ok
    end
  end

  @doc """
  Reports Phoenix channel message completion.
  """
  @spec report_phoenix_channel_message_complete(correlation_id(), String.t(), map(), term()) :: :ok
  def report_phoenix_channel_message_complete(correlation_id, event, payload, result) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_channel_message_complete(buffer, correlation_id, event, payload, result)
      _ -> :ok
    end
  end
end
