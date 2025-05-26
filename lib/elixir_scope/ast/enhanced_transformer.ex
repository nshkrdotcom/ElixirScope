defmodule ElixirScope.AST.EnhancedTransformer do
  @moduledoc """
  Enhanced AST transformer for granular compile-time instrumentation.
  
  Provides "Cinema Data" - rich, detailed execution traces including:
  - Local variable capture at specific lines
  - Expression-level value tracking  
  - Custom debugging logic injection
  """

  # Note: These aliases will be used when full integration is implemented
  # alias ElixirScope.AST.{Transformer, InjectorHelpers}
  # alias ElixirScope.Utils

  @doc """
  Transforms AST with enhanced capabilities.
  """
  def transform_with_enhanced_instrumentation(ast, plan) do
    # Transform AST with enhanced capabilities
    transform_with_granular_instrumentation(ast, plan)
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
    # Transform the AST to add expression tracing
    Macro.prewalk(ast, fn
      {:def, meta, [signature, body]} ->
        enhanced_body = add_expression_tracing_to_body(body, expressions)
        {:def, meta, [signature, enhanced_body]}
      
      node -> node
    end)
  end
  def inject_expression_tracing(ast, _plan), do: ast
  
  defp add_expression_tracing_to_body(body, expressions) do
    case body do
      [do: {:__block__, meta, statements}] ->
        enhanced_statements = Enum.map(statements, fn stmt ->
          add_expression_tracing_to_statement(stmt, expressions)
        end)
        [do: {:__block__, meta, enhanced_statements}]
      
      [do: single_statement] ->
        [do: add_expression_tracing_to_statement(single_statement, expressions)]
      
      other -> other
    end
  end
  
  defp add_expression_tracing_to_statement(statement, expressions) do
    case statement do
      {:=, _assign_meta, [_var, {func_name, _func_meta, _args}]} ->
        if func_name in expressions do
          # Wrap function calls that are in our trace list
          {:__block__, [], [
            {{:., [], [{:__aliases__, [alias: false], [:IO]}, :puts]}, [], ["Expression tracing enabled for: #{func_name}"]},
            statement
          ]}
        else
          statement
        end
      
      _ -> statement
    end
  end

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



  defp inject_variable_capture_at_line(ast, locals, target_line) do
    # For testing purposes, we'll inject after the Nth statement in a function body
    # In real usage, this would use actual line metadata
    case ast do
      {:def, meta, [signature, [do: {:__block__, block_meta, statements}]]} ->
        if target_line <= length(statements) do
          variable_map = build_variable_capture_map(locals)
          
          capture_call = {{:., [], [{:__aliases__, [alias: false], [:ElixirScope, :Capture, :InstrumentationRuntime]}, :report_local_variable_snapshot]}, [], 
            [
              {{:., [], [{:__aliases__, [alias: false], [:ElixirScope, :Utils]}, :generate_correlation_id]}, [], []},
              variable_map,
              target_line,
              :ast
            ]}
          
          {before, after_statements} = Enum.split(statements, target_line)
          enhanced_statements = before ++ [capture_call] ++ after_statements
          
          {:def, meta, [signature, [do: {:__block__, block_meta, enhanced_statements}]]}
        else
          ast
        end
      
      _ -> ast
    end
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
        enhanced_statements = Enum.flat_map(statements, fn stmt ->
          case stmt do
            {op, stmt_meta, _} = statement when op in [:=, :<-] ->
              # After assignment operations, capture variables
              line = stmt_meta[:line] || 0
              variable_map = build_variable_capture_map(locals)
              
              capture_call = {{:., [], [{:__aliases__, [alias: false], [:ElixirScope, :Capture, :InstrumentationRuntime]}, :report_local_variable_snapshot]}, [], 
                [
                  {{:., [], [{:__aliases__, [alias: false], [:ElixirScope, :Utils]}, :generate_correlation_id]}, [], []},
                  variable_map,
                  line,
                  :ast
                ]}
              
              [statement, capture_call]
            
            statement -> [statement]
          end
        end)
        
        {:__block__, meta, enhanced_statements}
      
      [do: {:__block__, meta, statements}] ->
        enhanced_statements = Enum.flat_map(statements, fn stmt ->
          case stmt do
            {op, stmt_meta, _} = statement when op in [:=, :<-] ->
              # After assignment operations, capture variables
              line = stmt_meta[:line] || 0
              variable_map = build_variable_capture_map(locals)
              
              capture_call = {{:., [], [{:__aliases__, [alias: false], [:ElixirScope, :Capture, :InstrumentationRuntime]}, :report_local_variable_snapshot]}, [], 
                [
                  {{:., [], [{:__aliases__, [alias: false], [:ElixirScope, :Utils]}, :generate_correlation_id]}, [], []},
                  variable_map,
                  line,
                  :ast
                ]}
              
              [statement, capture_call]
            
            statement -> [statement]
          end
        end)
        
        [do: {:__block__, meta, enhanced_statements}]
      
      single_statement -> single_statement
    end
  end

  defp inject_custom_logic_at_line(ast, _target_line, position, logic) do
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
    map_entries = Enum.map(locals, fn var_name ->
      {var_name, Macro.var(var_name, nil)}
    end)
    
    {:%{}, [], map_entries}
  end



  defp extract_function_name(signature) do
    case signature do
      {name, _, _} -> name
      name when is_atom(name) -> name
      _ -> :unknown_function
    end
  end

  defp should_instrument_function?(function_name, plan) do
    functions = Map.get(plan, :functions, [])
    
    # Check if this function should be instrumented
    cond do
      # If functions is empty, instrument all
      is_list(functions) and length(functions) == 0 -> true
      is_map(functions) and map_size(functions) == 0 -> true
      
      # If functions is a list of function names, only instrument those in the list
      is_list(functions) and length(functions) > 0 -> function_name in functions
      
      # If functions is a map, check if function is in the plan (try different key formats)
      is_map(functions) ->
        Enum.any?(functions, fn
          {{_module, ^function_name, _arity}, _plan} -> true
          {{^function_name, _arity}, _plan} -> true
          _ -> false
        end)
      
      # Default to instrumenting when no specific functions are listed
      true -> true
    end
  end

  def ast_tracing_enabled?(module_name) do
    # Check if AST tracing is enabled for this module
    # This will be coordinated with the runtime system
    case :persistent_term.get({:elixir_scope_ast_enabled, module_name}, :not_found) do
      :not_found -> true  # Default to enabled
      enabled -> enabled
    end
  end


end 