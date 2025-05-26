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
  Reports a local variable snapshot (AST-specific).
  
  This is called by AST-injected code to capture local variable values
  at specific points in function execution.
  Enhanced to support AST node correlation for hybrid architecture.
  """
  @spec report_local_variable_snapshot(correlation_id(), map(), non_neg_integer(), atom()) :: :ok
  def report_local_variable_snapshot(correlation_id, variables, line, _source \\ :ast) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :local_variable_snapshot,
          %{
            variables: variables,
            line: line,
            correlation_id: correlation_id,
            source: :ast
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports a local variable snapshot with AST node correlation.
  
  This version includes AST node ID for direct correlation with the AST Repository.
  Used by the enhanced AST transformer for hybrid architecture support.
  """
  @spec report_ast_variable_snapshot(correlation_id(), map(), non_neg_integer(), String.t()) :: :ok
  def report_ast_variable_snapshot(correlation_id, variables, line, ast_node_id) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :local_variable_snapshot,
          %{
            variables: variables,
            line: line,
            correlation_id: correlation_id,
            ast_node_id: ast_node_id,
            source: :ast,
            ast_correlation: true
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports an expression value (AST-specific).
  
  This is called by AST-injected code to capture the value of specific
  expressions during execution.
  Enhanced to support AST node correlation for hybrid architecture.
  """
  @spec report_expression_value(correlation_id(), String.t(), term(), non_neg_integer(), atom()) :: :ok
  def report_expression_value(correlation_id, expression, value, line, _source \\ :ast) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :expression_value,
          %{
            expression: expression,
            value: value,
            line: line,
            correlation_id: correlation_id,
            source: :ast
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports line execution (AST-specific).
  
  This is called by AST-injected code to mark execution of specific lines.
  Enhanced to support AST node correlation for hybrid architecture.
  """
  @spec report_line_execution(correlation_id(), non_neg_integer(), map(), atom()) :: :ok
  def report_line_execution(correlation_id, line, context, _source \\ :ast) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :line_execution,
          %{
            line: line,
            context: context,
            correlation_id: correlation_id,
            source: :ast
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports AST function entry with source tagging.
  
  This is similar to report_function_entry but specifically for AST-injected calls.
  Enhanced to support AST node correlation for hybrid architecture.
  """
  @spec report_ast_function_entry(module(), atom(), list(), correlation_id()) :: :ok
  def report_ast_function_entry(module, function, args, correlation_id) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :function_entry,
          %{
            module: module,
            function: function,
            arity: length(args),
            args: args,
            source: :ast,
            correlation_id: correlation_id
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports AST function entry with enhanced correlation metadata.
  
  This version includes AST node ID for direct correlation with the AST Repository.
  Used by the enhanced AST transformer for hybrid architecture support.
  """
  @spec report_ast_function_entry_with_node_id(module(), atom(), list(), correlation_id(), String.t()) :: :ok
  def report_ast_function_entry_with_node_id(module, function, args, correlation_id, ast_node_id) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        # Push to call stack for nested tracking
        push_call_stack(correlation_id)
        
        Ingestor.ingest_generic_event(
          buffer,
          :function_entry,
          %{
            module: module,
            function: function,
            arity: length(args),
            args: args,
            source: :ast,
            correlation_id: correlation_id,
            ast_node_id: ast_node_id,
            ast_correlation: true
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports AST function exit with source tagging.
  Enhanced to support AST node correlation for hybrid architecture.
  """
  @spec report_ast_function_exit(correlation_id(), term(), non_neg_integer()) :: :ok
  def report_ast_function_exit(correlation_id, return_value, duration_ns) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        # Pop from call stack
        pop_call_stack()
        
        Ingestor.ingest_generic_event(
          buffer,
          :function_exit,
          %{
            return_value: return_value,
            duration_ns: duration_ns,
            source: :ast,
            correlation_id: correlation_id
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports AST function exit with enhanced correlation metadata.
  
  This version includes AST node ID for direct correlation with the AST Repository.
  Used by the enhanced AST transformer for hybrid architecture support.
  """
  @spec report_ast_function_exit_with_node_id(correlation_id(), term(), non_neg_integer(), String.t()) :: :ok
  def report_ast_function_exit_with_node_id(correlation_id, return_value, duration_ns, ast_node_id) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        # Pop from call stack
        pop_call_stack()
        
        Ingestor.ingest_generic_event(
          buffer,
          :function_exit,
          %{
            return_value: return_value,
            duration_ns: duration_ns,
            source: :ast,
            correlation_id: correlation_id,
            ast_node_id: ast_node_id,
            ast_correlation: true
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports AST expression evaluation with node correlation.
  
  This version includes AST node ID for direct correlation with the AST Repository.
  Used to track specific expression evaluations in the hybrid architecture.
  """
  @spec report_ast_expression_value(correlation_id(), String.t(), term(), non_neg_integer(), String.t()) :: :ok
  def report_ast_expression_value(correlation_id, expression, value, line, ast_node_id) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :expression_value,
          %{
            expression: expression,
            value: value,
            line: line,
            correlation_id: correlation_id,
            ast_node_id: ast_node_id,
            source: :ast,
            ast_correlation: true
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports AST line execution with node correlation.
  
  This version includes AST node ID for direct correlation with the AST Repository.
  Used to track specific line executions in the hybrid architecture.
  """
  @spec report_ast_line_execution(correlation_id(), non_neg_integer(), map(), String.t()) :: :ok
  def report_ast_line_execution(correlation_id, line, context, ast_node_id) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :line_execution,
          %{
            line: line,
            context: context,
            correlation_id: correlation_id,
            ast_node_id: ast_node_id,
            source: :ast,
            ast_correlation: true
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports AST pattern match with node correlation.
  
  Used to track pattern matching operations in the hybrid architecture.
  Provides insights into pattern match success/failure and variable bindings.
  """
  @spec report_ast_pattern_match(correlation_id(), term(), term(), boolean(), non_neg_integer(), String.t()) :: :ok
  def report_ast_pattern_match(correlation_id, pattern, value, match_success, line, ast_node_id) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :pattern_match,
          %{
            pattern: pattern,
            value: value,
            match_success: match_success,
            line: line,
            correlation_id: correlation_id,
            ast_node_id: ast_node_id,
            source: :ast,
            ast_correlation: true
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports AST conditional branch execution with node correlation.
  
  Used to track which branches of conditionals (if/case/cond) are taken.
  Provides insights into code path execution patterns.
  """
  @spec report_ast_branch_execution(correlation_id(), atom(), term(), boolean(), non_neg_integer(), String.t()) :: :ok
  def report_ast_branch_execution(correlation_id, branch_type, condition, branch_taken, line, ast_node_id) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :branch_execution,
          %{
            branch_type: branch_type,
            condition: condition,
            branch_taken: branch_taken,
            line: line,
            correlation_id: correlation_id,
            ast_node_id: ast_node_id,
            source: :ast,
            ast_correlation: true
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  @doc """
  Reports AST loop iteration with node correlation.
  
  Used to track loop iterations (Enum.map, for comprehensions, etc.).
  Provides insights into iteration patterns and performance.
  """
  @spec report_ast_loop_iteration(correlation_id(), atom(), non_neg_integer(), term(), non_neg_integer(), String.t()) :: :ok
  def report_ast_loop_iteration(correlation_id, loop_type, iteration_count, current_value, line, ast_node_id) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :loop_iteration,
          %{
            loop_type: loop_type,
            iteration_count: iteration_count,
            current_value: current_value,
            line: line,
            correlation_id: correlation_id,
            ast_node_id: ast_node_id,
            source: :ast,
            ast_correlation: true
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
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

  # AST Correlation Helper Functions

  @doc """
  Gets AST correlation metadata for the current context.
  
  Returns metadata that can be used to correlate runtime events with AST nodes.
  Used internally by AST correlation functions.
  """
  @spec get_ast_correlation_metadata() :: map()
  def get_ast_correlation_metadata do
    %{
      process_id: self(),
      correlation_id: current_correlation_id(),
      timestamp_mono: System.monotonic_time(:nanosecond),
      timestamp_system: System.system_time(:nanosecond),
      enabled: enabled?()
    }
  end

  @doc """
  Validates AST node ID format for correlation.
  
  Ensures AST node IDs follow the expected format for the hybrid architecture.
  Returns {:ok, node_id} or {:error, reason}.
  """
  @spec validate_ast_node_id(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def validate_ast_node_id(ast_node_id) when is_binary(ast_node_id) do
    # AST node IDs should follow format: "module:function:line:node_type"
    case String.split(ast_node_id, ":") do
      [_module, _function, _line, _node_type] -> {:ok, ast_node_id}
      _ -> {:error, :invalid_format}
    end
  end
  def validate_ast_node_id(_), do: {:error, :not_string}

  @doc """
  Reports AST correlation performance metrics.
  
  Used to track the performance impact of AST correlation features.
  Helps ensure <5ms correlation latency target is met.
  """
  @spec report_ast_correlation_performance(correlation_id(), String.t(), non_neg_integer()) :: :ok
  def report_ast_correlation_performance(correlation_id, operation, duration_ns) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_generic_event(
          buffer,
          :ast_correlation_performance,
          %{
            operation: operation,
            duration_ns: duration_ns,
            correlation_id: correlation_id,
            source: :ast_correlation,
            performance_metric: true
          },
          self(),
          correlation_id,
          System.monotonic_time(:nanosecond),
          System.system_time(:nanosecond)
        )
        
      _ ->
        :ok
    end
  end

  # Phoenix Integration Functions

  @doc """
  Reports Phoenix request start.
  """
  @spec report_phoenix_request_start(correlation_id(), String.t(), String.t(), map(), tuple()) :: :ok
  def report_phoenix_request_start(correlation_id, method, path, params, remote_ip) do
    case get_context() do
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
    case get_context() do
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
    case get_context() do
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
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_controller_exit(buffer, correlation_id, controller, action, result)
      _ -> :ok
    end
  end

  # LiveView Integration Functions

  @doc """
  Reports LiveView mount start.
  """
  @spec report_liveview_mount_start(correlation_id(), module(), map(), map()) :: :ok
  def report_liveview_mount_start(correlation_id, module, params, session) do
    case get_context() do
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
    case get_context() do
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
    case get_context() do
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
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_liveview_handle_event_complete(buffer, correlation_id, event, params, before_assigns, result)
      _ -> :ok
    end
  end

  # Phoenix Channel Functions

  @doc """
  Reports Phoenix channel join start.
  """
  @spec report_phoenix_channel_join_start(correlation_id(), String.t(), map(), map()) :: :ok
  def report_phoenix_channel_join_start(correlation_id, topic, payload, socket) do
    case get_context() do
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
    case get_context() do
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
    case get_context() do
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
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_phoenix_channel_message_complete(buffer, correlation_id, event, payload, result)
      _ -> :ok
    end
  end

  # Ecto Integration Functions

  @doc """
  Reports Ecto query start.
  """
  @spec report_ecto_query_start(correlation_id(), String.t(), list(), map(), atom()) :: :ok
  def report_ecto_query_start(correlation_id, query, params, metadata, repo) do
    case get_context() do
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
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_ecto_query_complete(buffer, correlation_id, query, params, result, duration_us)
      _ -> :ok
    end
  end

  # GenServer Integration Functions

  @doc """
  Reports GenServer callback start.
  """
  @spec report_genserver_callback_start(atom(), pid(), boolean()) :: :ok
  def report_genserver_callback_start(callback_name, pid, capture_state) do
    case get_context() do
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
    case get_context() do
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
    case get_context() do
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
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_genserver_callback_complete(buffer, callback_name, pid, capture_state)
      _ -> :ok
    end
  end

  # Additional helper functions for InjectorHelpers

  @doc """
  Reports Phoenix action parameters.
  """
  @spec report_phoenix_action_params(atom(), map(), map(), boolean()) :: :ok
  def report_phoenix_action_params(action_name, conn, params, should_capture) do
    case get_context() do
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
    case get_context() do
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
    case get_context() do
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
    case get_context() do
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
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) and should_capture_response ->
        Ingestor.ingest_phoenix_action_complete(buffer, action_name, conn)
      _ -> :ok
    end
  end

  @doc """
  Reports LiveView assigns.
  """
  @spec report_liveview_assigns(atom(), map(), boolean()) :: :ok
  def report_liveview_assigns(callback_name, socket, should_capture) do
    case get_context() do
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
    case get_context() do
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
    case get_context() do
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
    case get_context() do
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
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_liveview_callback_error(buffer, callback_name, socket, kind, reason)
      _ -> :ok
    end
  end

  # Distributed/Node Functions

  @doc """
  Reports node events.
  """
  @spec report_node_event(atom(), atom(), map()) :: :ok
  def report_node_event(event_type, node_name, metadata) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_node_event(buffer, event_type, node_name, metadata)
      _ -> :ok
    end
  end

  @doc """
  Reports partition detection.
  """
  @spec report_partition_detected(list(atom()), map()) :: :ok
  def report_partition_detected(partitioned_nodes, metadata) do
    case get_context() do
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        Ingestor.ingest_partition_detected(buffer, partitioned_nodes, metadata)
      _ -> :ok
    end
  end

  # Additional function overloads to match InjectorHelpers usage

  @doc """
  Reports function entry (4-arity version).
  """
  @spec report_function_entry(atom(), integer(), boolean(), term()) :: correlation_id() | nil
  def report_function_entry(function_name, _arity, capture_args, correlation_id) do
    case get_context() do
      %{enabled: false} -> 
        nil
        
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        # Push to call stack for nested tracking
        push_call_stack(correlation_id)
        
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
  Reports function exit (5-arity version).
  """
  @spec report_function_exit(atom(), integer(), atom(), term(), term()) :: :ok
  def report_function_exit(_function_name, _arity, _exit_type, return_value, correlation_id) do
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
          0,  # Duration not available in this context
          correlation_id
        )
        
      _ ->
        :ok
    end
  end
end 