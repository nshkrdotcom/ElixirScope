defmodule ElixirScope.AI.ComplexityAnalyzer do
  @moduledoc """
  Analyzes code complexity for Elixir modules and functions.
  
  Provides rule-based complexity analysis to inform instrumentation decisions.
  Initially implemented with heuristics, designed to be enhanced with ML models.
  """

  # Callback names for OTP behaviors and Phoenix components
  @callback_names [:init, :handle_call, :handle_cast, :handle_info, :terminate, :code_change,
                   :mount, :handle_event, :handle_params]

  defstruct [
    :score,
    :nesting_depth,
    :cyclomatic_complexity,
    :state_complexity,
    :performance_critical,
    :function_count,
    :callback_count,
    :pattern_match_complexity
  ]

  @doc """
  Calculates complexity for a single AST node (function or expression).
  """
  def calculate_complexity(ast) do
    %{
      score: calculate_complexity_score(ast),
      nesting_depth: calculate_nesting_depth(ast),
      cyclomatic_complexity: calculate_cyclomatic_complexity(ast),
      pattern_match_complexity: calculate_pattern_match_complexity(ast),
      performance_indicators: analyze_performance_patterns(ast)
    }
  end

  @doc """
  Analyzes complexity for an entire module.
  """
  def analyze_module(ast) do
    functions = extract_functions(ast)
    callbacks = extract_callbacks(ast)
    
    function_complexities = Enum.map(functions, &calculate_complexity/1)
    avg_complexity = calculate_average_complexity(function_complexities)
    max_complexity = calculate_max_complexity(function_complexities)
    
    state_complexity = analyze_state_complexity(ast)
    performance_critical = determine_performance_critical(function_complexities)

    %__MODULE__{
      score: avg_complexity,
      nesting_depth: max_complexity,
      cyclomatic_complexity: Enum.sum(Enum.map(function_complexities, & &1.cyclomatic_complexity)),
      state_complexity: state_complexity,
      performance_critical: performance_critical,
      function_count: length(functions),
      callback_count: length(callbacks),
      pattern_match_complexity: calculate_total_pattern_complexity(function_complexities)
    }
  end

  @doc """
  Determines if a module or function is performance critical.
  """
  def is_performance_critical?(ast) do
    has_loops?(ast) or
    has_recursive_calls?(ast) or
    has_heavy_computation?(ast) or
    has_large_data_structures?(ast)
  end

  @doc """
  Analyzes state complexity for stateful modules (GenServer, Agent, etc.).
  """
  def analyze_state_complexity(ast) do
    state_operations = count_state_operations(ast)
    _state_types = analyze_state_types(ast)
    state_mutations = count_state_mutations(ast)

    cond do
      state_operations > 8 or state_mutations > 4 -> :high
      state_operations > 2 or state_mutations > 1 -> :medium
      state_operations > 0 -> :low
      true -> :none
    end
  end

  # Private implementation functions

  defp calculate_complexity_score(ast) do
    base_score = 1
    nesting_bonus = calculate_nesting_depth(ast) * 2  # Increase weight
    branching_bonus = calculate_cyclomatic_complexity(ast)
    pattern_bonus = calculate_pattern_match_complexity(ast)
    pipe_bonus = count_pipe_operations(ast)  # Add pipe operation penalty
    enum_bonus = count_enum_operations(ast)  # Add enum operation penalty
    
    base_score + nesting_bonus + branching_bonus + pattern_bonus + pipe_bonus + enum_bonus
  end

  defp calculate_nesting_depth(ast) do
    max_depth(ast, 0)
  end

  defp max_depth(ast, current_depth) do
    Macro.prewalk(ast, current_depth, fn
      # Control flow structures add nesting
      {:case, _, clauses}, max_so_far ->
        clause_max = case clauses do
          clauses_list when is_list(clauses_list) ->
            Enum.reduce(clauses_list, current_depth + 1, fn clause, acc ->
              case clause do
                {:->, _, [_patterns, body]} ->
                  max(acc, max_depth(body, current_depth + 1))
                _ ->
                  acc
              end
            end)
          _ ->
            current_depth + 1
        end
        {nil, max(max_so_far, clause_max)}
      
      {:if, _, [_condition, keyword_list]}, max_so_far ->
        do_block = Keyword.get(keyword_list, :do)
        else_block = Keyword.get(keyword_list, :else)
        
        do_max = if do_block, do: max_depth(do_block, current_depth + 1), else: current_depth + 1
        else_max = if else_block, do: max_depth(else_block, current_depth + 1), else: current_depth + 1
        
        {nil, max(max_so_far, max(do_max, else_max))}
      
      {:cond, _, clauses}, max_so_far ->
        clause_max = case clauses do
          clauses_list when is_list(clauses_list) ->
            Enum.reduce(clauses_list, current_depth + 1, fn clause, acc ->
              case clause do
                {:->, _, [_condition, body]} ->
                  max(acc, max_depth(body, current_depth + 1))
                _ ->
                  acc
              end
            end)
          _ ->
            current_depth + 1
        end
        {nil, max(max_so_far, clause_max)}
      
      # Anonymous functions also add nesting  
      {:fn, _, clauses}, max_so_far ->
        clause_max = case clauses do
          clauses_list when is_list(clauses_list) ->
            Enum.reduce(clauses_list, current_depth + 1, fn clause, acc ->
              case clause do
                {:->, _, [_patterns, body]} ->
                  max(acc, max_depth(body, current_depth + 1))
                _ ->
                  acc
              end
            end)
          _ ->
            current_depth + 1
        end
        {nil, max(max_so_far, clause_max)}
      
      # Pipe operations add some complexity
      {:|>, _, [left, right]}, max_so_far ->
        left_max = max_depth(left, current_depth)
        right_max = max_depth(right, current_depth + 1)  # Pipes add one level
        {nil, max(max_so_far, max(left_max, right_max))}
      
      # Function calls can add depth in some cases
      {{:., _, _}, _, args}, max_so_far when is_list(args) ->
        args_max = case args do
          args_list when is_list(args_list) ->
            Enum.reduce(args_list, current_depth, fn arg, acc ->
              max(acc, max_depth(arg, current_depth))
            end)
          _ ->
            current_depth
        end
        {nil, max(max_so_far, args_max)}
      
      node, max_so_far -> 
        {node, max_so_far}
    end) |> elem(1)
  end

  defp calculate_cyclomatic_complexity(ast) do
    Macro.prewalk(ast, 1, fn
      {:case, _, _}, complexity -> {true, complexity + 1}
      {:if, _, _}, complexity -> {true, complexity + 1}
      {:cond, _, clauses}, complexity -> 
        clause_count = case clauses do
          clauses_list when is_list(clauses_list) -> length(clauses_list)
          _ -> 1
        end
        {true, complexity + clause_count}
      {:with, _, _}, complexity -> {true, complexity + 1}
      {:try, _, _}, complexity -> {true, complexity + 1}
      {:and, _, _}, complexity -> {true, complexity + 1}
      {:or, _, _}, complexity -> {true, complexity + 1}
      node, complexity -> {node, complexity}
    end) |> elem(1)
  end

  defp calculate_pattern_match_complexity(ast) do
    Macro.prewalk(ast, 0, fn
      {:->, _, [patterns, _]}, complexity ->
        pattern_complexity = case patterns do
          patterns_list when is_list(patterns_list) ->
            Enum.sum(Enum.map(patterns_list, &count_pattern_elements/1))
          single_pattern ->
            count_pattern_elements(single_pattern)
        end
        {true, complexity + pattern_complexity}
      {:=, _, [pattern, _]}, complexity ->
        pattern_complexity = count_pattern_elements(pattern)
        {true, complexity + pattern_complexity}
      node, complexity -> {node, complexity}
    end) |> elem(1)
  end

  defp count_pattern_elements(pattern) do
    case pattern do
      {:{}, _, elements} -> length(elements)
      {_, _} -> 2
      [_ | _] -> 2  # List patterns
      %{} -> 1     # Map patterns
      _ when is_atom(pattern) -> 1
      _ -> 1
    end
  end

  defp analyze_performance_patterns(ast) do
    %{
      has_loops: has_loops?(ast),
      has_recursion: has_recursive_calls?(ast),
      has_heavy_computation: has_heavy_computation?(ast),
      has_large_data: has_large_data_structures?(ast),
      enum_operations: count_enum_operations(ast),
      database_calls: count_database_calls(ast)
    }
  end

  defp extract_functions(ast) do
    Macro.prewalk(ast, [], fn
      {:def, _, [_signature, body]}, acc -> {body, [body | acc]}
      {:defp, _, [_signature, body]}, acc -> {body, [body | acc]}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp extract_callbacks(ast) do
    Macro.prewalk(ast, [], fn
      {:def, _, [{name, _, _}, body]}, acc when name in @callback_names ->
        {body, [body | acc]}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp calculate_average_complexity(complexities) do
    if length(complexities) > 0 do
      Enum.sum(Enum.map(complexities, & &1.score)) / length(complexities)
    else
      0
    end
  end

  defp calculate_max_complexity(complexities) do
    if length(complexities) > 0 do
      Enum.max(Enum.map(complexities, & &1.nesting_depth))
    else
      0
    end
  end

  defp calculate_total_pattern_complexity(complexities) do
    Enum.sum(Enum.map(complexities, & &1.pattern_match_complexity))
  end

  defp determine_performance_critical(complexities) do
    Enum.any?(complexities, fn complexity ->
      complexity.performance_indicators.has_loops or
      complexity.performance_indicators.has_recursion or
      complexity.performance_indicators.enum_operations > 3
    end)
  end

  defp has_loops?(ast) do
    ast_contains_pattern?(ast, {:for, :_, :_}) or
    ast_contains_pattern?(ast, {:while, :_, :_})
  end

  defp has_recursive_calls?(ast) do
    # Simple heuristic: look for function calls that might be recursive
    function_name = extract_function_name(ast)
    
    if function_name do
      ast_contains_function_call?(ast, function_name)
    else
      false
    end
  end

  defp has_heavy_computation?(ast) do
    count_mathematical_operations(ast) > 10 or
    ast_contains_pattern?(ast, {:crypto, :_, :_}) or
    ast_contains_pattern?(ast, {:math, :_, :_})
  end

  defp has_large_data_structures?(ast) do
    count_data_structure_operations(ast) > 5
  end

  defp count_enum_operations(ast) do
    Macro.prewalk(ast, 0, fn
      {{:., _, [{:__aliases__, _, [:Enum]}, _]}, _, _}, count ->
        {true, count + 1}
      node, count -> {node, count}
    end) |> elem(1)
  end

  defp count_database_calls(ast) do
    Macro.prewalk(ast, 0, fn
      {{:., _, [{:__aliases__, _, [:Repo]}, _]}, _, _}, count ->
        {true, count + 1}
      {{:., _, [{:__aliases__, _, [:Ecto]}, _]}, _, _}, count ->
        {true, count + 1}
      node, count -> {node, count}
    end) |> elem(1)
  end

  defp count_state_operations(ast) do
    Macro.prewalk(ast, 0, fn
      {{:., _, [{:__aliases__, _, [:GenServer]}, _]}, _, _}, count ->
        {true, count + 1}
      {:handle_call, _, _}, count -> {true, count + 1}
      {:handle_cast, _, _}, count -> {true, count + 1}
      {:handle_info, _, _}, count -> {true, count + 1}
      {:init, _, _}, count -> {true, count + 1}
      {:start_link, _, _}, count -> {true, count + 1}
      # State access patterns
      {{:., _, [:Map, :get]}, _, [_state | _]}, count -> {true, count + 1}
      {:reply, _, [_, _state]}, count -> {true, count + 1}
      {:noreply, _, [_state]}, count -> {true, count + 1}
      {:stop, _, [_, _state]}, count -> {true, count + 1}
      node, count -> {node, count}
    end) |> elem(1)
  end

  defp analyze_state_types(ast) do
    Macro.prewalk(ast, [], fn
      {:def, _, [{:init, _, _}, _]}, acc -> {true, [:state_init | acc]}
      {:=, _, [{:state, _, _}, _]}, acc -> {true, [:state_assignment | acc]}
      node, acc -> {node, acc}
    end) |> elem(1) |> Enum.uniq()
  end

  defp count_state_mutations(ast) do
    Macro.prewalk(ast, 0, fn
      {:put_in, _, _}, count -> {true, count + 1}
      {:update_in, _, _}, count -> {true, count + 1}
      {:Map, :put, _}, count -> {true, count + 1}
      {:Map, :update, _}, count -> {true, count + 1}
      node, count -> {node, count}
    end) |> elem(1)
  end

  defp count_mathematical_operations(ast) do
    Macro.prewalk(ast, 0, fn
      {:+, _, _}, count -> {true, count + 1}
      {:-, _, _}, count -> {true, count + 1}
      {:*, _, _}, count -> {true, count + 1}
      {:/, _, _}, count -> {true, count + 1}
      {:div, _, _}, count -> {true, count + 1}
      {:rem, _, _}, count -> {true, count + 1}
      node, count -> {node, count}
    end) |> elem(1)
  end

  defp count_pipe_operations(ast) do
    Macro.prewalk(ast, 0, fn
      {:|>, _, _}, count -> {true, count + 1}
      node, count -> {node, count}
    end) |> elem(1)
  end

  defp count_data_structure_operations(ast) do
    Macro.prewalk(ast, 0, fn
      {{:., _, [{:__aliases__, _, [:Map]}, _]}, _, _}, count ->
        {true, count + 1}
      {{:., _, [{:__aliases__, _, [:List]}, _]}, _, _}, count ->
        {true, count + 1}
      node, count -> {node, count}
    end) |> elem(1)
  end

  defp ast_contains_pattern?(ast, pattern) do
    Macro.prewalk(ast, false, fn
      ^pattern, _acc -> {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp ast_contains_function_call?(ast, function_name) do
    Macro.prewalk(ast, false, fn
      {^function_name, _, _}, _acc -> {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp extract_function_name(ast) do
    case ast do
      {:def, _, [{name, _, _}, _]} -> name
      {:defp, _, [{name, _, _}, _]} -> name
      _ -> nil
    end
  end
end 