defmodule ElixirScope.Capture.InstrumentationRuntime.CoreReporting do
  @moduledoc """
  Core event reporting functionality for the instrumentation runtime.

  Handles basic events like function calls, process spawns, message sends,
  state changes, and errors.
  """

  alias ElixirScope.Capture.{RingBuffer, Ingestor}
  alias ElixirScope.Capture.InstrumentationRuntime.Context

  @type correlation_id :: Context.correlation_id()

  @doc """
  Reports a function call entry.

  This is called at the beginning of every instrumented function.
  Must be extremely fast - target <100ns when disabled, <500ns when enabled.
  """
  @spec report_function_entry(module(), atom(), list()) :: correlation_id() | nil
  def report_function_entry(module, function, args) do
    case Context.get_context() do
      %{enabled: false} ->
        nil

      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        correlation_id = Context.generate_correlation_id()

        # Push to call stack for nested tracking
        Context.push_call_stack(correlation_id)

        # Ingest the event
        Ingestor.ingest_function_call(
          buffer,
          module,
          function,
          args,
          self(),
          correlation_id
        )

        correlation_id

      _ ->
        # ElixirScope not properly initialized
        nil
    end
  end

  @doc """
  Reports function entry (4-arity version for compatibility).
  """
  @spec report_function_entry(atom(), integer(), boolean(), term()) :: correlation_id() | nil
  def report_function_entry(function_name, _arity, capture_args, correlation_id) do
    case Context.get_context() do
      %{enabled: false} ->
        nil

      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        # Push to call stack for nested tracking
        Context.push_call_stack(correlation_id)

        # Ingest the event
        Ingestor.ingest_function_call(
          buffer,
          __MODULE__,  # Use a placeholder module since we don't have it here
          function_name,
          if(capture_args, do: [], else: :no_capture),
          self(),
          correlation_id
        )

        correlation_id

      _ ->
        # ElixirScope not properly initialized
        nil
    end
  end

  @doc """
  Reports a function call exit.

  This is called at the end of every instrumented function.
  """
  @spec report_function_exit(correlation_id(), term(), non_neg_integer()) :: :ok
  def report_function_exit(correlation_id, return_value, duration_ns) do
    case Context.get_context() do
      %{enabled: false} ->
        :ok

      %{enabled: true, buffer: buffer} when not is_nil(buffer) and not is_nil(correlation_id) ->
        # Pop from call stack
        Context.pop_call_stack()

        # Ingest the return event
        Ingestor.ingest_function_return(
          buffer,
          return_value,
          duration_ns,
          correlation_id
        )

      _ ->
        :ok
    end
  end

  @doc """
  Reports function exit (5-arity version for compatibility).
  """
  @spec report_function_exit(atom(), integer(), atom(), term(), term()) :: :ok
  def report_function_exit(_function_name, _arity, _exit_type, return_value, correlation_id) do
    case Context.get_context() do
      %{enabled: false} ->
        :ok

      %{enabled: true, buffer: buffer} when not is_nil(buffer) and not is_nil(correlation_id) ->
        # Pop from call stack
        Context.pop_call_stack()

        # Ingest the return event
        Ingestor.ingest_function_return(
          buffer,
          return_value,
          0,  # Duration not available in this context
          correlation_id
        )

      _ ->
        :ok
    end
  end

  @doc """
  Reports a process spawn event.
  """
  @spec report_process_spawn(pid()) :: :ok
  def report_process_spawn(child_pid) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_process_spawn(buffer, self(), child_pid)

      _ ->
        :ok
    end
  end

  @doc """
  Reports a message send event.
  """
  @spec report_message_send(pid(), term()) :: :ok
  def report_message_send(to_pid, message) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_message_send(buffer, self(), to_pid, message)

      _ ->
        :ok
    end
  end

  @doc """
  Reports a state change event (for GenServer, Agent, etc.).
  """
  @spec report_state_change(term(), term()) :: :ok
  def report_state_change(old_state, new_state) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_state_change(buffer, self(), old_state, new_state)

      _ ->
        :ok
    end
  end

  @doc """
  Reports an error event.
  """
  @spec report_error(term(), term(), list()) :: :ok
  def report_error(error, reason, stacktrace) do
    case Context.get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_error(buffer, error, reason, stacktrace)

      _ ->
        :ok
    end
  end
end
