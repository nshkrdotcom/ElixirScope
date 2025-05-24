defmodule ElixirScope.Capture.InstrumentationRuntime do
  @moduledoc """
  Runtime API for instrumented code to report events to ElixirScope.
  
  This module provides the interface that AST-transformed code will call.
  It must be extremely fast and have graceful degradation when ElixirScope
  is disabled or not available.
  
  Key design principles:
  - Minimal overhead when disabled (single boolean check)
  - No crashes if ElixirScope is not running
  - Efficient correlation ID management
  - Support for nested function calls
  """

  alias ElixirScope.Capture.{RingBuffer, Ingestor}

  @type correlation_id :: term()
  @type instrumentation_context :: %{
    buffer: RingBuffer.t() | nil,
    correlation_id: correlation_id(),
    call_stack: [correlation_id()],
    enabled: boolean()
  }

  # Process dictionary keys for fast access
  @context_key :elixir_scope_context
  @call_stack_key :elixir_scope_call_stack

  @doc """
  Reports a function call entry.
  
  This is called at the beginning of every instrumented function.
  Must be extremely fast - target <100ns when disabled, <500ns when enabled.
  """
  @spec report_function_entry(module(), atom(), list()) :: correlation_id() | nil
  def report_function_entry(module, function, args) do
    case get_context() do
      %{enabled: false} -> 
        nil
        
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        correlation_id = generate_correlation_id()
        
        # Push to call stack for nested tracking
        push_call_stack(correlation_id)
        
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
  Reports a function call exit.
  
  This is called at the end of every instrumented function.
  """
  @spec report_function_exit(correlation_id(), term(), non_neg_integer()) :: :ok
  def report_function_exit(correlation_id, return_value, duration_ns) do
    case get_context() do
      %{enabled: false} -> 
        :ok
        
      %{enabled: true, buffer: buffer} when not is_nil(buffer) and not is_nil(correlation_id) ->
        # Pop from call stack
        pop_call_stack()
        
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
  Reports a process spawn event.
  """
  @spec report_process_spawn(pid()) :: :ok
  def report_process_spawn(child_pid) do
    case get_context() do
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
    case get_context() do
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
    case get_context() do
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
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_error(buffer, error, reason, stacktrace)
        
      _ ->
        :ok
    end
  end

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
  Measures the overhead of instrumentation calls.
  
  Returns timing statistics for performance validation.
  """
  @spec measure_overhead(pos_integer()) :: %{
    entry_avg_ns: float(),
    exit_avg_ns: float(),
    disabled_avg_ns: float()
  }
  def measure_overhead(iterations \\ 10000) do
    # Initialize context for testing
    initialize_context()
    
    # Measure function entry overhead
    entry_times = for _ <- 1..iterations do
      start = System.monotonic_time(:nanosecond)
      correlation_id = report_function_entry(TestModule, :test_function, [])
      duration = System.monotonic_time(:nanosecond) - start
      
      # Clean up
      if correlation_id, do: report_function_exit(correlation_id, :ok, 0)
      
      duration
    end
    
    # Measure function exit overhead
    exit_times = for _ <- 1..iterations do
      correlation_id = report_function_entry(TestModule, :test_function, [])
      
      start = System.monotonic_time(:nanosecond)
      report_function_exit(correlation_id, :ok, 0)
      duration = System.monotonic_time(:nanosecond) - start
      
      duration
    end
    
    # Measure disabled overhead
    clear_context()
    disabled_times = for _ <- 1..iterations do
      start = System.monotonic_time(:nanosecond)
      report_function_entry(TestModule, :test_function, [])
      System.monotonic_time(:nanosecond) - start
    end
    
    %{
      entry_avg_ns: Enum.sum(entry_times) / length(entry_times),
      exit_avg_ns: Enum.sum(exit_times) / length(exit_times),
      disabled_avg_ns: Enum.sum(disabled_times) / length(disabled_times)
    }
  end

  # Private functions

  defp get_context do
    Process.get(@context_key, %{enabled: false, buffer: nil, correlation_id: nil, call_stack: []})
  end

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

  defp generate_correlation_id do
    # Use a simple but unique correlation ID
    {System.monotonic_time(:nanosecond), self(), make_ref()}
  end

  defp push_call_stack(correlation_id) do
    current_stack = Process.get(@call_stack_key, [])
    Process.put(@call_stack_key, [correlation_id | current_stack])
  end

  defp pop_call_stack do
    case Process.get(@call_stack_key, []) do
      [_ | rest] -> Process.put(@call_stack_key, rest)
      [] -> :ok
    end
  end
end 