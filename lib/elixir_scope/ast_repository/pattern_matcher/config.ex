defmodule ElixirScope.ASTRepository.PatternMatcher.Config do
  @moduledoc """
  Configuration management for the Pattern Matcher system.
  """
  
  @default_config %{
    pattern_match_timeout: 500,
    function_analysis_timeout: 10,
    max_memory_usage_mb: 100,
    default_confidence_threshold: 0.7,
    high_confidence_threshold: 0.9,
    enable_pattern_cache: true,
    cache_ttl_minutes: 30,
    load_default_patterns: true,
    custom_pattern_paths: [],
    enable_ast_analysis: true,
    enable_behavioral_analysis: true,
    enable_anti_pattern_analysis: true,
    context_sensitive_matching: false,
    log_level: :info,
    enable_performance_metrics: false
  }
  
  @spec get(atom()) :: any()
  def get(key) do
    case Application.get_env(:elixir_scope, :pattern_matcher) do
      nil -> Map.get(@default_config, key)
      config when is_list(config) -> 
        Keyword.get(config, key, Map.get(@default_config, key))
      config when is_map(config) ->
        Map.get(config, key, Map.get(@default_config, key))
    end
  end
  
  @spec get_all() :: map()
  def get_all do
    case Application.get_env(:elixir_scope, :pattern_matcher) do
      nil -> @default_config
      config when is_list(config) -> 
        Map.merge(@default_config, Enum.into(config, %{}))
      config when is_map(config) ->
        Map.merge(@default_config, config)
    end
  end
  
  @spec validate_config(map()) :: :ok | {:error, term()}
  def validate_config(config) do
    required_keys = [:pattern_match_timeout, :default_confidence_threshold]
    
    case Enum.find(required_keys, fn key -> not Map.has_key?(config, key) end) do
      nil -> validate_values(config)
      missing_key -> {:error, {:missing_config_key, missing_key}}
    end
  end
  
  defp validate_values(config) do
    with :ok <- validate_timeout(config.pattern_match_timeout),
         :ok <- validate_confidence(config.default_confidence_threshold) do
      :ok
    end
  end
  
  defp validate_timeout(timeout) when is_integer(timeout) and timeout > 0, do: :ok
  defp validate_timeout(_), do: {:error, :invalid_timeout}
  
  defp validate_confidence(confidence) when is_number(confidence) and confidence >= 0.0 and confidence <= 1.0, do: :ok
  defp validate_confidence(_), do: {:error, :invalid_confidence_threshold}
end
