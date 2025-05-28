defmodule ElixirScope.ASTRepository.Enhanced.ComplexityMetrics do
  @moduledoc """
  Comprehensive complexity metrics for AST analysis.
  
  This structure provides various complexity measurements including:
  - Cyclomatic complexity (control flow complexity)
  - Cognitive complexity (human readability complexity)
  - Halstead metrics (software science metrics)
  - Maintainability index
  - Custom complexity scoring
  
  ## Usage
  
      iex> metrics = ComplexityMetrics.new(ast)
      iex> metrics.cyclomatic
      5
  """
  
  @type t :: %__MODULE__{
    # Overall complexity score (0.0 to 100.0+)
    score: float(),
    
    # Cyclomatic complexity (number of linearly independent paths)
    cyclomatic: non_neg_integer(),
    
    # Cognitive complexity (human readability complexity)
    cognitive: non_neg_integer(),
    
    # Halstead software science metrics
    halstead: %{
      vocabulary: non_neg_integer(),      # n = n1 + n2
      length: non_neg_integer(),          # N = N1 + N2
      calculated_length: float(),         # N^ = n1 * log2(n1) + n2 * log2(n2)
      volume: float(),                    # V = N * log2(n)
      difficulty: float(),                # D = (n1/2) * (N2/n2)
      effort: float(),                    # E = D * V
      time: float(),                      # T = E / 18 seconds
      bugs: float()                       # B = V / 3000
    },
    
    # Maintainability index (0-100, higher is better)
    maintainability_index: float(),
    
    # Additional metrics
    nesting_depth: non_neg_integer(),
    lines_of_code: non_neg_integer(),
    comment_ratio: float(),
    
    # Metadata
    calculated_at: DateTime.t(),
    metadata: map()
  }
  
  defstruct [
    :score,
    :cyclomatic,
    :cognitive,
    :halstead,
    :maintainability_index,
    :nesting_depth,
    :lines_of_code,
    :comment_ratio,
    :calculated_at,
    :metadata
  ]
  
  @doc """
  Creates a new ComplexityMetrics structure from AST analysis.
  
  ## Parameters
  - `ast` - The AST to analyze
  - `opts` - Optional parameters for analysis configuration
  
  ## Examples
  
      iex> ast = quote do: def complex_function(x), do: if x > 0, do: x * 2, else: 0
      iex> metrics = ComplexityMetrics.new(ast)
      iex> metrics.cyclomatic >= 2
      true
  """
  @spec new(Macro.t(), keyword()) :: t()
  def new(ast, opts \\ []) do
    now = DateTime.utc_now()
    
    cyclomatic = calculate_cyclomatic_complexity(ast)
    cognitive = calculate_cognitive_complexity(ast)
    halstead = calculate_halstead_metrics(ast)
    nesting_depth = calculate_nesting_depth(ast)
    lines_of_code = calculate_lines_of_code(ast)
    comment_ratio = calculate_comment_ratio(ast, opts)
    
    maintainability_index = calculate_maintainability_index(
      halstead.volume,
      cyclomatic,
      lines_of_code,
      comment_ratio
    )
    
    overall_score = calculate_overall_score(
      cyclomatic,
      cognitive,
      maintainability_index,
      nesting_depth
    )
    
    %__MODULE__{
      score: overall_score,
      cyclomatic: cyclomatic,
      cognitive: cognitive,
      halstead: halstead,
      maintainability_index: maintainability_index,
      nesting_depth: nesting_depth,
      lines_of_code: lines_of_code,
      comment_ratio: comment_ratio,
      calculated_at: now,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
  
  @doc """
  Validates the complexity metrics structure.
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = metrics) do
    with :ok <- validate_score_ranges(metrics),
         :ok <- validate_halstead_metrics(metrics),
         :ok <- validate_timestamps(metrics) do
      :ok
    end
  end
  
  @doc """
  Combines multiple complexity metrics (e.g., for module-level aggregation).
  """
  @spec combine([t()]) :: t()
  def combine([]), do: %__MODULE__{score: 0.0, cyclomatic: 0, cognitive: 0, halstead: %{}, maintainability_index: 100.0, nesting_depth: 0, lines_of_code: 0, comment_ratio: 0.0, calculated_at: DateTime.utc_now(), metadata: %{}}
  def combine([single]), do: single
  def combine(metrics_list) when is_list(metrics_list) do
    total_cyclomatic = Enum.sum(Enum.map(metrics_list, & &1.cyclomatic))
    total_cognitive = Enum.sum(Enum.map(metrics_list, & &1.cognitive))
    total_lines = Enum.sum(Enum.map(metrics_list, & &1.lines_of_code))
    max_nesting = Enum.max(Enum.map(metrics_list, & &1.nesting_depth), fn -> 0 end)
    avg_maintainability = Enum.sum(Enum.map(metrics_list, & &1.maintainability_index)) / length(metrics_list)
    avg_comment_ratio = Enum.sum(Enum.map(metrics_list, & &1.comment_ratio)) / length(metrics_list)
    
    combined_halstead = combine_halstead_metrics(Enum.map(metrics_list, & &1.halstead))
    
    overall_score = calculate_overall_score(
      total_cyclomatic,
      total_cognitive,
      avg_maintainability,
      max_nesting
    )
    
    %__MODULE__{
      score: overall_score,
      cyclomatic: total_cyclomatic,
      cognitive: total_cognitive,
      halstead: combined_halstead,
      maintainability_index: avg_maintainability,
      nesting_depth: max_nesting,
      lines_of_code: total_lines,
      comment_ratio: avg_comment_ratio,
      calculated_at: DateTime.utc_now(),
      metadata: %{combined_from: length(metrics_list)}
    }
  end
  
  @doc """
  Gets a human-readable complexity rating.
  """
  @spec get_complexity_rating(t()) :: :low | :moderate | :high | :very_high
  def get_complexity_rating(%__MODULE__{} = metrics) do
    cond do
      metrics.score <= 10.0 -> :low
      metrics.score <= 20.0 -> :moderate
      metrics.score <= 40.0 -> :high
      true -> :very_high
    end
  end
  
  @doc """
  Gets complexity warnings based on thresholds.
  """
  @spec get_warnings(t()) :: [String.t()]
  def get_warnings(%__MODULE__{} = metrics) do
    warnings = []
    
    warnings = if metrics.cyclomatic > 10, do: ["High cyclomatic complexity (#{metrics.cyclomatic})" | warnings], else: warnings
    warnings = if metrics.cognitive > 15, do: ["High cognitive complexity (#{metrics.cognitive})" | warnings], else: warnings
    warnings = if metrics.nesting_depth > 4, do: ["Deep nesting (#{metrics.nesting_depth} levels)" | warnings], else: warnings
    warnings = if metrics.maintainability_index < 20, do: ["Low maintainability index (#{Float.round(metrics.maintainability_index, 1)})" | warnings], else: warnings
    warnings = if metrics.lines_of_code > 50, do: ["Long function (#{metrics.lines_of_code} lines)" | warnings], else: warnings
    
    Enum.reverse(warnings)
  end
  
  # Private helper functions
  
  defp calculate_cyclomatic_complexity(ast) do
    # Count decision points: if, case, cond, try, &&, ||, etc.
    ast
    |> Macro.prewalk(1, fn  # Start with 1 for the base path
      {:if, _, _}, acc -> {nil, acc + 1}
      {:case, _, _}, acc -> {nil, acc + 1}
      {:cond, _, _}, acc -> {nil, acc + 1}
      {:try, _, _}, acc -> {nil, acc + 1}
      {:&&, _, _}, acc -> {nil, acc + 1}
      {:||, _, _}, acc -> {nil, acc + 1}
      {:and, _, _}, acc -> {nil, acc + 1}
      {:or, _, _}, acc -> {nil, acc + 1}
      {:when, _, _}, acc -> {nil, acc + 1}
      {:->, _, [guards, _]}, acc when is_list(guards) -> {nil, acc + length(guards)}
      node, acc -> {node, acc}
    end)
    |> elem(1)
  end
  
  defp calculate_cognitive_complexity(ast) do
    # Cognitive complexity considers nesting and certain constructs
    {_, complexity} = calculate_cognitive_recursive(ast, 0, 0)
    complexity
  end
  
  defp calculate_cognitive_recursive(ast, nesting_level, complexity) do
    case ast do
      {:if, _, [_condition, [do: do_block] ++ rest]} ->
        # +1 for if, +nesting for being nested
        new_complexity = complexity + 1 + nesting_level
        {_, do_complexity} = calculate_cognitive_recursive(do_block, nesting_level + 1, 0)
        
        else_complexity = case Keyword.get(rest, :else) do
          nil -> 0
          else_block -> 
            {_, complexity} = calculate_cognitive_recursive(else_block, nesting_level + 1, 0)
            complexity
        end
        
        {ast, new_complexity + do_complexity + else_complexity}
      
      {:case, _, [_expr, [do: clauses]]} ->
        # +1 for case, +nesting for being nested
        new_complexity = complexity + 1 + nesting_level
        clauses_complexity = Enum.reduce(clauses, 0, fn {:->, _, [_pattern, body]}, acc ->
          {_, body_complexity} = calculate_cognitive_recursive(body, nesting_level + 1, 0)
          acc + body_complexity
        end)
        
        {ast, new_complexity + clauses_complexity}
      
      {:cond, _, [do: clauses]} ->
        # +1 for cond, +nesting for being nested
        new_complexity = complexity + 1 + nesting_level
        clauses_complexity = Enum.reduce(clauses, 0, fn {:->, _, [_condition, body]}, acc ->
          {_, body_complexity} = calculate_cognitive_recursive(body, nesting_level + 1, 0)
          acc + body_complexity
        end)
        
        {ast, new_complexity + clauses_complexity}
      
      {:&&, _, [left, right]} ->
        # +1 for logical operator
        {_, left_complexity} = calculate_cognitive_recursive(left, nesting_level, 0)
        {_, right_complexity} = calculate_cognitive_recursive(right, nesting_level, 0)
        {ast, complexity + 1 + left_complexity + right_complexity}
      
      {:||, _, [left, right]} ->
        # +1 for logical operator
        {_, left_complexity} = calculate_cognitive_recursive(left, nesting_level, 0)
        {_, right_complexity} = calculate_cognitive_recursive(right, nesting_level, 0)
        {ast, complexity + 1 + left_complexity + right_complexity}
      
      {_, _, children} when is_list(children) ->
        # Recursively process children
        children_complexity = Enum.reduce(children, 0, fn child, acc ->
          {_, child_complexity} = calculate_cognitive_recursive(child, nesting_level, 0)
          acc + child_complexity
        end)
        {ast, complexity + children_complexity}
      
      _ ->
        {ast, complexity}
    end
  end
  
  defp calculate_halstead_metrics(ast) do
    # Extract operators and operands
    {operators, operands} = extract_operators_and_operands(ast)
    
    n1 = length(Enum.uniq(operators))  # Unique operators
    n2 = length(Enum.uniq(operands))   # Unique operands
    n = n1 + n2                        # Vocabulary
    
    big_n1 = length(operators)         # Total operators
    big_n2 = length(operands)          # Total operands
    big_n = big_n1 + big_n2           # Length
    
    # Calculated metrics
    calculated_length = if n1 > 0 and n2 > 0 do
      n1 * :math.log2(n1) + n2 * :math.log2(n2)
    else
      0.0
    end
    
    volume = if n > 0, do: big_n * :math.log2(n), else: 0.0
    
    difficulty = if n2 > 0, do: (n1 / 2) * (big_n2 / n2), else: 0.0
    
    effort = difficulty * volume
    time = effort / 18  # Seconds
    bugs = volume / 3000
    
    %{
      vocabulary: n,
      length: big_n,
      calculated_length: calculated_length,
      volume: volume,
      difficulty: difficulty,
      effort: effort,
      time: time,
      bugs: bugs
    }
  end
  
  defp extract_operators_and_operands(ast) do
    operators = []
    operands = []
    
    {_final_ast, {operators, operands}} = Macro.prewalk(ast, {operators, operands}, fn
      # Operators
      {op, _, _} = node, acc when op in [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=, :&&, :||, :and, :or, :not, :=, :|>, :., :++, :--, :in] ->
        {node, {[op | elem(acc, 0)], elem(acc, 1)}}
      
      # Function calls are operators
      {func, _, args} = node, acc when is_atom(func) and is_list(args) ->
        {node, {[func | elem(acc, 0)], elem(acc, 1)}}
      
      # Variables and literals are operands
      {var, _, nil} = node, acc when is_atom(var) ->
        {node, {elem(acc, 0), [var | elem(acc, 1)]}}
      
      # Literals
      literal, acc when is_number(literal) or is_binary(literal) or is_atom(literal) ->
        {literal, {elem(acc, 0), [literal | elem(acc, 1)]}}
      
      node, acc ->
        {node, acc}
    end)
    
    {operators, operands}
  end
  
  defp calculate_nesting_depth(ast) do
    ast
    |> Macro.prewalk(0, fn
      {:if, _, _}, depth -> {{}, depth + 1}
      {:case, _, _}, depth -> {{}, depth + 1}
      {:cond, _, _}, depth -> {{}, depth + 1}
      {:try, _, _}, depth -> {{}, depth + 1}
      {:fn, _, _}, depth -> {{}, depth + 1}
      {:for, _, _}, depth -> {{}, depth + 1}
      {:with, _, _}, depth -> {{}, depth + 1}
      node, depth -> {node, depth}
    end)
    |> elem(1)
  end
  
  defp calculate_lines_of_code(ast) do
    # Simplified LOC calculation based on AST nodes
    ast
    |> Macro.prewalk(0, fn node, acc -> {node, acc + 1} end)
    |> elem(1)
    |> div(3)  # Rough approximation
  end
  
  defp calculate_comment_ratio(_ast, _opts) do
    # TODO: Implement comment ratio calculation
    # This would require access to the original source code
    0.0
  end
  
  defp calculate_maintainability_index(volume, cyclomatic, lines_of_code, comment_ratio) do
    # Microsoft's maintainability index formula (simplified)
    # MI = 171 - 5.2 * ln(V) - 0.23 * G - 16.2 * ln(LOC) + 50 * sin(sqrt(2.4 * C))
    # Where V = Halstead volume, G = cyclomatic complexity, LOC = lines of code, C = comment ratio
    
    volume_term = if volume > 0, do: 5.2 * :math.log(volume), else: 0
    complexity_term = 0.23 * cyclomatic
    loc_term = if lines_of_code > 0, do: 16.2 * :math.log(lines_of_code), else: 0
    comment_term = 50 * :math.sin(:math.sqrt(2.4 * comment_ratio))
    
    mi = 171 - volume_term - complexity_term - loc_term + comment_term
    
    # Clamp to 0-100 range
    max(0.0, min(100.0, mi))
  end
  
  defp calculate_overall_score(cyclomatic, cognitive, maintainability_index, nesting_depth) do
    # Custom scoring algorithm that combines multiple metrics
    # Lower maintainability index is worse, so invert it
    maintainability_penalty = (100 - maintainability_index) / 10
    
    cyclomatic * 2.0 + cognitive * 1.5 + maintainability_penalty + nesting_depth * 3.0
  end
  
  defp combine_halstead_metrics(halstead_list) do
    if Enum.empty?(halstead_list) do
      %{}
    else
      total_vocabulary = Enum.sum(Enum.map(halstead_list, &Map.get(&1, :vocabulary, 0)))
      total_length = Enum.sum(Enum.map(halstead_list, &Map.get(&1, :length, 0)))
      avg_volume = Enum.sum(Enum.map(halstead_list, &Map.get(&1, :volume, 0.0))) / length(halstead_list)
      avg_difficulty = Enum.sum(Enum.map(halstead_list, &Map.get(&1, :difficulty, 0.0))) / length(halstead_list)
      total_effort = Enum.sum(Enum.map(halstead_list, &Map.get(&1, :effort, 0.0)))
      total_time = Enum.sum(Enum.map(halstead_list, &Map.get(&1, :time, 0.0)))
      total_bugs = Enum.sum(Enum.map(halstead_list, &Map.get(&1, :bugs, 0.0)))
      
      %{
        vocabulary: total_vocabulary,
        length: total_length,
        calculated_length: 0.0,  # Not meaningful when combined
        volume: avg_volume,
        difficulty: avg_difficulty,
        effort: total_effort,
        time: total_time,
        bugs: total_bugs
      }
    end
  end
  
  defp validate_score_ranges(%__MODULE__{score: score}) when score < 0, do: {:error, :invalid_score}
  defp validate_score_ranges(%__MODULE__{cyclomatic: cyclomatic}) when cyclomatic < 0, do: {:error, :invalid_cyclomatic}
  defp validate_score_ranges(%__MODULE__{cognitive: cognitive}) when cognitive < 0, do: {:error, :invalid_cognitive}
  defp validate_score_ranges(%__MODULE__{maintainability_index: mi}) when mi < 0 or mi > 100, do: {:error, :invalid_maintainability_index}
  defp validate_score_ranges(_), do: :ok
  
  defp validate_halstead_metrics(%__MODULE__{halstead: halstead}) when is_map(halstead) do
    required_keys = [:vocabulary, :length, :volume, :difficulty, :effort, :time, :bugs]
    if Enum.all?(required_keys, &Map.has_key?(halstead, &1)) do
      :ok
    else
      {:error, :incomplete_halstead_metrics}
    end
  end
  defp validate_halstead_metrics(_), do: {:error, :invalid_halstead_metrics}
  
  defp validate_timestamps(%__MODULE__{calculated_at: nil}), do: {:error, :missing_calculated_at}
  defp validate_timestamps(_), do: :ok
end 