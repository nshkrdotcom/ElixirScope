defmodule ElixirScope.ASTRepository.PatternMatcher.Core do
  @moduledoc """
  Core pattern matching logic and analysis functions.
  """
  
  alias ElixirScope.ASTRepository.PatternMatcher.{Types, Validators, Analyzers, Stats}
  
  @spec match_ast_pattern_with_timing(pid() | atom(), map()) :: {:ok, Types.pattern_result()} | {:error, term()}
  def match_ast_pattern_with_timing(repo, pattern_spec) do
    start_time = System.monotonic_time(:millisecond)
    
    case match_ast_pattern_internal(repo, pattern_spec) do
      {:ok, result} ->
        end_time = System.monotonic_time(:millisecond)
        analysis_time = end_time - start_time
        
        result_with_metadata = Map.put(result, :analysis_time_ms, analysis_time)
        {:ok, result_with_metadata}
      
      error ->
        error
    end
  end
  
  @spec match_behavioral_pattern_with_timing(pid() | atom(), map(), atom()) :: {:ok, Types.pattern_result()} | {:error, term()}
  def match_behavioral_pattern_with_timing(repo, pattern_spec, pattern_library) do
    start_time = System.monotonic_time(:millisecond)
    
    case match_behavioral_pattern_internal(repo, pattern_spec, pattern_library) do
      {:ok, result} ->
        end_time = System.monotonic_time(:millisecond)
        analysis_time = end_time - start_time
        
        result_with_metadata = Map.put(result, :analysis_time_ms, analysis_time)
        {:ok, result_with_metadata}
      
      error ->
        error
    end
  end
  
  @spec match_anti_pattern_with_timing(pid() | atom(), map(), atom()) :: {:ok, Types.pattern_result()} | {:error, term()}
  def match_anti_pattern_with_timing(repo, pattern_spec, pattern_library) do
    start_time = System.monotonic_time(:millisecond)
    
    case match_anti_pattern_internal(repo, pattern_spec, pattern_library) do
      {:ok, result} ->
        end_time = System.monotonic_time(:millisecond)
        analysis_time = end_time - start_time
        
        result_with_metadata = Map.put(result, :analysis_time_ms, analysis_time)
        {:ok, result_with_metadata}
      
      error ->
        error
    end
  end
  
  # Private functions
  
  defp match_ast_pattern_internal(repo, pattern_spec) do
    with {:ok, normalized_spec} <- Validators.normalize_pattern_spec(pattern_spec),
         {:ok, functions} <- get_all_functions_for_analysis(repo),
         {:ok, matches} <- Analyzers.analyze_ast_patterns(functions, normalized_spec) do
      
      result = %{
        matches: matches,
        total_analyzed: length(functions),
        pattern_stats: Stats.calculate_pattern_stats(matches)
      }
      
      {:ok, result}
    end
  end
  
  defp match_behavioral_pattern_internal(repo, pattern_spec, pattern_library) do
    with {:ok, normalized_spec} <- Validators.normalize_pattern_spec(pattern_spec),
         {:ok, pattern_def} <- get_behavioral_pattern_definition(normalized_spec.pattern_type, pattern_library),
         {:ok, modules} <- get_all_modules_for_analysis(repo),
         {:ok, matches} <- Analyzers.analyze_behavioral_patterns(modules, pattern_def, normalized_spec) do
      
      result = %{
        matches: matches,
        total_analyzed: length(modules),
        pattern_stats: Stats.calculate_pattern_stats(matches)
      }
      
      {:ok, result}
    end
  end
  
  defp match_anti_pattern_internal(repo, pattern_spec, pattern_library) do
    with {:ok, normalized_spec} <- Validators.normalize_pattern_spec(pattern_spec),
         {:ok, pattern_def} <- get_anti_pattern_definition(normalized_spec.pattern_type, pattern_library),
         {:ok, functions} <- get_all_functions_for_analysis(repo),
         {:ok, matches} <- Analyzers.analyze_anti_patterns(functions, pattern_def, normalized_spec) do
      
      result = %{
        matches: matches,
        total_analyzed: length(functions),
        pattern_stats: Stats.calculate_pattern_stats(matches)
      }
      
      {:ok, result}
    end
  end
  
  defp get_all_functions_for_analysis(repo) do
    case Validators.validate_repository(repo) do
      :ok ->
        # This would integrate with the Enhanced Repository
        # For now, return placeholder data since repo integration isn't implemented
        {:ok, []}
      
      error -> error
    end
  end
  
  defp get_all_modules_for_analysis(repo) do
    case Validators.validate_repository(repo) do
      :ok ->
        # This would integrate with the Enhanced Repository
        # For now, return placeholder data since repo integration isn't implemented
        {:ok, []}
      
      error -> error
    end
  end
  
  defp get_behavioral_pattern_definition(pattern_type, pattern_library) do
    case :ets.lookup(pattern_library, {:behavioral, pattern_type}) do
      [{_, pattern_def}] -> {:ok, pattern_def}
      [] -> {:error, :pattern_not_found}
    end
  end
  
  defp get_anti_pattern_definition(pattern_type, pattern_library) do
    case :ets.lookup(pattern_library, {:anti_pattern, pattern_type}) do
      [{_, pattern_def}] -> {:ok, pattern_def}
      [] -> {:error, :pattern_not_found}
    end
  end
end
