defmodule ElixirScope.CompileTime.Orchestrator do
  @moduledoc """
  Orchestrates compile-time AST instrumentation by generating detailed plans
  based on user requests and AI analysis.
  
  This module:
  - Takes high-level instrumentation requests
  - Analyzes target modules using AI.CodeAnalyzer
  - Generates detailed AST transformation plans
  - Coordinates with the unified tracing system
  """

  alias ElixirScope.AI.CodeAnalyzer
  alias ElixirScope.Utils

  @doc """
  Generates an AST instrumentation plan for the given target and options.
  
  ## Examples
  
      # Basic function instrumentation
      plan = generate_plan(MyModule, %{functions: [:my_func]})
      
      # Granular variable capture
      plan = generate_plan(MyModule, %{
        functions: [:complex_calc],
        capture_locals: [:temp1, :temp2, :result],
        after_line: 42
      })
      
      # Expression tracing
      plan = generate_plan(MyModule, %{
        functions: [:algorithm],
        trace_expressions: [:process_item, :calculate_result]
      })
  """
  def generate_plan(target, opts \\ %{}) do
    with {:ok, analysis} <- analyze_target(target, opts),
         {:ok, base_plan} <- create_base_plan(target, opts, analysis),
         {:ok, enhanced_plan} <- enhance_plan_with_ai(base_plan, analysis, opts) do
      {:ok, finalize_plan(enhanced_plan, opts)}
    else
      error -> error
    end
  end

  @doc """
  Generates a plan for on-demand instrumentation of a specific function.
  """
  def generate_function_plan(module, function, arity, opts \\ %{}) do
    target = {module, function, arity}
    
    enhanced_opts = Map.merge(opts, %{
      functions: [function],
      granularity: Map.get(opts, :granularity, :function_boundaries),
      on_demand: true
    })
    
    generate_plan(target, enhanced_opts)
  end



  # Private functions

  defp analyze_target(target, opts) do
    case target do
      module when is_atom(module) ->
        analyze_module(module, opts)
      
      {module, function, arity} ->
        analyze_function(module, function, arity, opts)
      
      _ ->
        {:error, {:invalid_target, target}}
    end
  end

  defp analyze_module(module, _opts) do
    if Code.ensure_loaded?(module) do
      # Use existing AI analyzer method that takes module code
      try do
        # Get module source if available, otherwise use basic analysis
        case get_module_source(module) do
          {:ok, source} ->
            case CodeAnalyzer.analyze_code(source) do
              {:ok, analysis} -> {:ok, analysis}
              {:error, _reason} -> {:ok, create_basic_module_analysis(module)}
            end
          {:error, _} ->
            {:ok, create_basic_module_analysis(module)}
        end
      rescue
        _ -> {:ok, create_basic_module_analysis(module)}
      end
    else
      {:error, {:module_not_loaded, module}}
    end
  end

  defp analyze_function(module, function, arity, _opts) do
    if Code.ensure_loaded?(module) and function_exported?(module, function, arity) do
      # For now, always use basic analysis since function source extraction is complex
      {:ok, create_basic_function_analysis(module, function, arity)}
    else
      {:error, {:function_not_found, {module, function, arity}}}
    end
  end

  defp create_base_plan(target, opts, analysis) do
    plan = %{
      target: target,
      type: :compile_time,
      granularity: Map.get(opts, :granularity, :function_boundaries),
      functions: extract_target_functions(target, opts),
      capture_locals: Map.get(opts, :capture_locals, []),
      trace_expressions: Map.get(opts, :trace_expressions, []),
      custom_injections: Map.get(opts, :custom_injections, []),

      analysis: analysis,
      created_at: System.monotonic_time(:nanosecond)
    }
    
    {:ok, plan}
  end

  defp enhance_plan_with_ai(base_plan, analysis, opts) do
    # Use AI analysis to enhance the instrumentation plan
    enhanced_plan = case Map.get(opts, :granularity) do
      :locals ->
        enhance_for_local_variable_capture(base_plan, analysis)
      
      :expressions ->
        enhance_for_expression_tracing(base_plan, analysis)
      
      :lines ->
        enhance_for_line_level_tracing(base_plan, analysis)
      
      _ ->
        base_plan
    end
    
    {:ok, enhanced_plan}
  end

  defp enhance_for_local_variable_capture(plan, analysis) do
    # AI suggests which local variables are most interesting to capture
    suggested_locals = case analysis do
      %{local_variables: vars} when is_list(vars) ->
        # Filter to most relevant variables based on AI analysis
        Enum.filter(vars, fn var ->
          var.complexity > 1 or var.mutation_count > 0
        end)
        |> Enum.map(& &1.name)
      
      _ -> plan.capture_locals
    end
    
    Map.put(plan, :capture_locals, suggested_locals ++ plan.capture_locals)
  end

  defp enhance_for_expression_tracing(plan, analysis) do
    # AI suggests which expressions are worth tracing
    suggested_expressions = case analysis do
      %{complex_expressions: exprs} when is_list(exprs) ->
        Enum.map(exprs, & &1.name)
      
      _ -> plan.trace_expressions
    end
    
    Map.put(plan, :trace_expressions, suggested_expressions ++ plan.trace_expressions)
  end

  defp enhance_for_line_level_tracing(plan, analysis) do
    # AI suggests specific lines that are worth instrumenting
    suggested_lines = case analysis do
      %{critical_lines: lines} when is_list(lines) ->
        Enum.map(lines, fn line ->
          {line.number, :after, create_line_instrumentation(line)}
        end)
      
      _ -> []
    end
    
    Map.put(plan, :custom_injections, suggested_lines ++ plan.custom_injections)
  end

  defp finalize_plan(plan, _opts) do
    # Add final metadata and validation
    Map.merge(plan, %{
      plan_id: Utils.generate_correlation_id(),
      environment: Mix.env(),
      elixir_scope_version: Application.spec(:elixir_scope, :vsn),
      finalized_at: System.monotonic_time(:nanosecond),
      storage_path: get_plan_storage_path(plan),
      invalidation_triggers: create_invalidation_triggers(plan)
    })
  end

  defp extract_target_functions(target, opts) do
    case target do
      module when is_atom(module) ->
        # Get all public functions or those specified in opts
        Map.get(opts, :functions, get_module_functions(module))
      
      {_module, function, _arity} ->
        [function]
      
      _ -> []
    end
  end

  defp get_module_functions(module) do
    if Code.ensure_loaded?(module) do
      module.__info__(:functions)
      |> Enum.map(fn {name, _arity} -> name end)
      |> Enum.uniq()
    else
      []
    end
  end

  defp get_module_source(module) do
    # Try to get source from module info or fallback to basic analysis
    try do
      case module.module_info(:compile) do
        compile_info when is_list(compile_info) ->
          case Keyword.get(compile_info, :source) do
            source_file when is_binary(source_file) ->
              case File.read(source_file) do
                {:ok, content} -> {:ok, content}
                {:error, _} -> {:error, :source_not_available}
              end
            _ -> {:error, :source_not_available}
          end
        _ -> {:error, :source_not_available}
      end
    rescue
      _ -> {:error, :source_not_available}
    end
  end





  defp create_basic_module_analysis(module) do
    %{
      module: module,
      complexity: :medium,
      function_count: length(module.__info__(:functions)),
      local_variables: [],
      complex_expressions: [],
      critical_lines: [],
      analysis_type: :basic_fallback
    }
  end

  defp create_basic_function_analysis(module, function, arity) do
    %{
      module: module,
      function: function,
      arity: arity,
      complexity: :medium,
      local_variables: [],
      complex_expressions: [],
      critical_lines: [],
      analysis_type: :basic_fallback
    }
  end

  defp create_line_instrumentation(line) do
    quote do
      ElixirScope.Capture.InstrumentationRuntime.report_line_execution(
        ElixirScope.Utils.generate_correlation_id(),
        unquote(line.number),
        unquote(line.context || %{}),
        :ast
      )
    end
  end

  defp get_plan_storage_path(plan) do
    base_path = Application.get_env(:elixir_scope, :compile_time_tracing, [])
                |> Keyword.get(:plan_storage_path, "_build/elixir_scope/ast_plans")
    
    plan_file = "#{plan.plan_id}.plan"
    Path.join(base_path, plan_file)
  end

  defp create_invalidation_triggers(plan) do
    # Define what should invalidate this plan
    %{
      source_file_changes: get_source_files_for_target(plan.target),
      config_changes: [:elixir_scope],
      dependency_changes: [:elixir_scope],
      ttl: Application.get_env(:elixir_scope, :compile_time_tracing, [])
           |> Keyword.get(:plan_cache_ttl, 3600)
    }
  end

  defp get_source_files_for_target(target) do
    case target do
      module when is_atom(module) ->
        case :code.which(module) do
          path when is_list(path) -> [List.to_string(path)]
          _ -> []
        end
      
      {module, _, _} -> get_source_files_for_target(module)
      _ -> []
    end
  end
end 