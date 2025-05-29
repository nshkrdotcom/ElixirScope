defmodule ElixirScope.Capture.InstrumentationRuntime.Context do
  @moduledoc """
  Manages instrumentation context for processes.

  Handles initialization, cleanup, and state management for instrumentation
  contexts including correlation IDs, call stacks, and enablement state.
  """

  alias ElixirScope.Capture.RingBuffer

  @type correlation_id :: term()
  @type t :: %{
    buffer: RingBuffer.t() | nil,
    correlation_id: correlation_id(),
    call_stack: [correlation_id()],
    enabled: boolean()
  }

  # Process dictionary keys for fast access
  @context_key :elixir_scope_context
  @call_stack_key :elixir_scope_call_stack

  @doc """
  Initializes the instrumentation context for the current process.

  This should be called when a process starts or when ElixirScope is enabled.
  """
  @spec initialize_context() :: :ok
  def initialize_context do
    case get_buffer() do
      {:ok, buffer} ->
        context = %{
          buffer: buffer,
          correlation_id: nil,
          call_stack: [],
          enabled: true  # For now, always enabled when buffer is available
        }

        Process.put(@context_key, context)
        Process.put(@call_stack_key, [])
        :ok

      {:error, _} ->
        # ElixirScope not available, set disabled context
        context = %{
          buffer: nil,
          correlation_id: nil,
          call_stack: [],
          enabled: false
        }

        Process.put(@context_key, context)
        :ok
    end
  end

  @doc """
  Clears the instrumentation context for the current process.
  """
  @spec clear_context() :: :ok
  def clear_context do
    Process.delete(@context_key)
    Process.delete(@call_stack_key)
    :ok
  end

  @doc """
  Checks if instrumentation is enabled for the current process.

  This is the fastest possible check - just a process dictionary lookup.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    case Process.get(@context_key) do
      %{enabled: enabled} -> enabled
      _ -> false
    end
  end

  @doc """
  Gets the current correlation ID (for nested calls).
  """
  @spec current_correlation_id() :: correlation_id() | nil
  def current_correlation_id do
    case Process.get(@call_stack_key) do
      [current | _] -> current
      _ -> nil
    end
  end

  @doc """
  Gets the current instrumentation context.
  """
  @spec get_context() :: t()
  def get_context do
    Process.get(@context_key, %{enabled: false, buffer: nil, correlation_id: nil, call_stack: []})
  end

  @doc """
  Temporarily disables instrumentation for the current process.

  Useful for avoiding recursive instrumentation in ElixirScope's own code.
  """
  @spec with_instrumentation_disabled((() -> term())) :: term()
  def with_instrumentation_disabled(fun) do
    old_context = Process.get(@context_key)

    # Temporarily disable
    case old_context do
      %{} = context ->
        Process.put(@context_key, %{context | enabled: false})

      _ ->
        Process.put(@context_key, %{enabled: false, buffer: nil, correlation_id: nil, call_stack: []})
    end

    try do
      fun.()
    after
      # Restore old context
      if old_context do
        Process.put(@context_key, old_context)
      else
        Process.delete(@context_key)
      end
    end
  end

  @doc """
  Generates a unique correlation ID.
  """
  @spec generate_correlation_id() :: correlation_id()
  def generate_correlation_id do
    # Use a simple but unique correlation ID
    {System.monotonic_time(:nanosecond), self(), make_ref()}
  end

  @doc """
  Pushes a correlation ID onto the call stack.
  """
  @spec push_call_stack(correlation_id()) :: :ok
  def push_call_stack(correlation_id) do
    current_stack = Process.get(@call_stack_key, [])
    Process.put(@call_stack_key, [correlation_id | current_stack])
    :ok
  end

  @doc """
  Pops a correlation ID from the call stack.
  """
  @spec pop_call_stack() :: :ok
  def pop_call_stack do
    case Process.get(@call_stack_key, []) do
      [_ | rest] -> Process.put(@call_stack_key, rest)
      [] -> :ok
    end
    :ok
  end

  # Private functions

  defp get_buffer do
    # Try to get the main buffer from the application
    case Application.get_env(:elixir_scope, :main_buffer) do
      nil ->
        {:error, :no_buffer_configured}

      buffer_name when is_atom(buffer_name) ->
        try do
          buffer_key = :"elixir_scope_buffer_#{buffer_name}"
          case :persistent_term.get(buffer_key, nil) do
            nil -> {:error, :buffer_not_found}
            buffer -> {:ok, buffer}
          end
        rescue
          _ -> {:error, :buffer_access_failed}
        end

      buffer when is_map(buffer) ->
        {:ok, buffer}
    end
  end
end
