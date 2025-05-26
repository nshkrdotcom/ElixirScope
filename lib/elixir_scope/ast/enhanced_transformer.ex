defmodule ElixirScope.AST.EnhancedTransformer do
  @moduledoc """
  Enhanced AST transformer with runtime integration and granular instrumentation.
  
  Provides "Cinema Data" - rich, detailed execution traces including:
  - Local variable capture at specific lines
  - Expression-level value tracking  
  - Custom debugging logic injection
  - Runtime system coordination
  """

  alias ElixirScope.AST.{Transformer, InjectorHelpers}
  alias ElixirScope.Utils

  @doc """
  Transforms AST with runtime bridge and enhanced capabilities.
  """
  def transform_with_runtime_bridge(ast, plan) do
    # Transform AST with enhanced capabilities
    transformed = transform_with_granular_instrumentation(ast, plan)
    
    # Inject runtime coordination calls
    inject_runtime_coordination(transformed, plan)
  end

  @doc """
  Transforms AST with granular instrumentation capabilities.
  """
  def transform_with_granular_instrumentation(ast, plan) do
    ast
    |> inject_local_variable_capture(plan)
    |> inject_expression_tracing(plan)
    |> inject_custom_debugging_logic(plan)
    # Note: Base transformer integration will be added once compatibility is resolved
  end

  @doc """
  Injects local variable capture at specified lines or after specific expressions.
  """
  def inject_local_variable_capture(ast, %{capture_locals: locals} = plan) when is_list(locals) do
    line = Map.get(plan, :after_line, nil)
    
    if line do
      inject_variable_capture_at_line(ast, locals, line)
    else
      inject_variable_capture_in_functions(ast, locals, plan)
    end
  end
  def inject_local_variable_capture(ast, _plan), do: ast

  @doc """
  Injects expression tracing for specified expressions.
  """
  def inject_expression_tracing(ast, %{trace_expressions: expressions}) when is_list(expressions) do
    # For now, just mark that expression tracing was requested
    # Full implementation will be added once base transformer integration is resolved
    case ast do
      {:def, meta, [signature, body]} ->
        # Add a comment to indicate expression tracing was applied
        enhanced_body = quote do
          # Expression tracing enabled for: unquote(expressions)
          unquote(body)
        end
        {:def, meta, [signature, enhanced_body]}
      
      other -> 
        # For non-function AST, wrap with comment block
        quote do
          # Expression tracing enabled for: unquote(expressions)
          unquote(other)
        end
    end
  end
  def inject_expression_tracing(ast, _plan), do: ast

  @doc """
  Injects custom debugging logic at specified points.
  """
  def inject_custom_debugging_logic(ast, %{custom_injections: injections}) when is_list(injections) do
    Enum.reduce(injections, ast, fn {line, position, logic}, acc_ast ->
      inject_custom_logic_at_line(acc_ast, line, position, logic)
    end)
  end
  def inject_custom_debugging_logic(ast, _plan), do: ast

  # Private helper functions

  defp inject_runtime_coordination(ast, plan) do
    module_name = extract_module_name(ast)
    
    quote do
      # Register this module with runtime system for hybrid coordination
      if Code.ensure_loaded?(ElixirScope.Runtime) do
        ElixirScope.Runtime.register_instrumented_module(unquote(module_name), unquote(Macro.escape(plan)))
      end
      
      # Check runtime flags before executing AST instrumentation
      if ast_tracing_enabled?(unquote(module_name)) do
        unquote(ast)
      else
        # AST instrumentation disabled at runtime - execute original code
        unquote(strip_instrumentation(ast))
      end
    end
  end

  defp inject_variable_capture_at_line(ast, locals, target_line) do
    Macro.prewalk(ast, fn
      {form, meta, args} = node when is_list(meta) ->
        line = meta[:line]
        
        if line == target_line do
          # Inject variable capture after this line
          variable_map = build_variable_capture_map(locals)
          
          quote do
            unquote(node)
            ElixirScope.Capture.InstrumentationRuntime.report_local_variable_snapshot(
              ElixirScope.Utils.generate_correlation_id(),
              unquote(variable_map),
              unquote(target_line),
              :ast
            )
          end
        else
          node
        end
      
      node -> node
    end)
  end

  defp inject_variable_capture_in_functions(ast, locals, plan) do
    Macro.prewalk(ast, fn
      {:def, meta, [signature, body]} = node ->
        function_name = extract_function_name(signature)
        
        if should_instrument_function?(function_name, plan) do
          enhanced_body = inject_variable_captures_in_body(body, locals)
          {:def, meta, [signature, enhanced_body]}
        else
          node
        end
      
      {:defp, meta, [signature, body]} = node ->
        function_name = extract_function_name(signature)
        
        if should_instrument_function?(function_name, plan) do
          enhanced_body = inject_variable_captures_in_body(body, locals)
          {:defp, meta, [signature, enhanced_body]}
        else
          node
        end
      
      node -> node
    end)
  end

  defp inject_variable_captures_in_body(body, locals) do
    # Inject variable captures at strategic points in function body
    case body do
      {:__block__, meta, statements} ->
        enhanced_statements = Enum.map(statements, fn stmt ->
          case stmt do
            {op, stmt_meta, _} = statement when op in [:=, :<-] ->
              # After assignment operations, capture variables
              line = stmt_meta[:line] || 0
              variable_map = build_variable_capture_map(locals)
              
              quote do
                unquote(statement)
                ElixirScope.Capture.InstrumentationRuntime.report_local_variable_snapshot(
                  ElixirScope.Utils.generate_correlation_id(),
                  unquote(variable_map),
                  unquote(line),
                  :ast
                )
              end
            
            statement -> statement
          end
        end)
        
        {:__block__, meta, enhanced_statements}
      
      single_statement -> single_statement
    end
  end

  defp inject_custom_logic_at_line(ast, target_line, position, logic) do
    # For now, inject at the beginning of the function body since line matching is complex
    case ast do
      {:def, meta, [signature, body]} ->
        enhanced_body = case position do
          :before ->
            quote do
              unquote(logic)
              unquote(body)
            end
          
          :after ->
            quote do
              unquote(body)
              unquote(logic)
            end
          
          :replace ->
            logic
        end
        
        {:def, meta, [signature, enhanced_body]}
      
      other -> other
    end
  end

  defp build_variable_capture_map(locals) do
    # Build a map of variable names to their values for capture
    Enum.reduce(locals, %{}, fn var_name, acc ->
      quote do
        Map.put(unquote(acc), unquote(var_name), unquote(Macro.var(var_name, nil)))
      end
    end)
  end

  defp extract_module_name(ast) do
    case ast do
      {:defmodule, _, [module_name, _]} -> module_name
      _ -> :unknown_module
    end
  end

  defp extract_function_name(signature) do
    case signature do
      {name, _, _} -> name
      name when is_atom(name) -> name
      _ -> :unknown_function
    end
  end

  defp should_instrument_function?(function_name, plan) do
    functions = Map.get(plan, :functions, %{})
    
    # Check if this function should be instrumented
    cond do
      # If functions is empty, instrument all
      map_size(functions) == 0 -> true
      
      # Check if function is in the plan (try different key formats)
      Enum.any?(functions, fn
        {{_module, ^function_name, _arity}, _plan} -> true
        {{^function_name, _arity}, _plan} -> true
        _ -> false
      end) -> true
      
      # Default to not instrumenting
      true -> false
    end
  end

  defp ast_tracing_enabled?(module_name) do
    # Check if AST tracing is enabled for this module
    # This will be coordinated with the runtime system
    case :persistent_term.get({:elixir_scope_ast_enabled, module_name}, :not_found) do
      :not_found -> true  # Default to enabled
      enabled -> enabled
    end
  end

  defp strip_instrumentation(ast) do
    # Remove all ElixirScope instrumentation calls from AST
    # This is a simplified version - in practice, we'd need to track
    # what was added and remove only those parts
    Macro.prewalk(ast, fn
      {{:., _, [{:__aliases__, _, [:ElixirScope | _]}, _]}, _, _} ->
        # Remove ElixirScope calls
        quote do: :ok
      
      node -> node
    end)
  end
end 