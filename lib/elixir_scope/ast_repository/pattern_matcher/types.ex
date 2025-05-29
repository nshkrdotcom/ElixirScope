defmodule ElixirScope.ASTRepository.PatternMatcher.Types do
  @moduledoc """
  Type definitions for the Pattern Matcher system.
  """
  
  defstruct [
    :pattern_type,
    :pattern_ast,
    :confidence_threshold,
    :match_variables,
    :context_sensitive,
    :custom_rules,
    :metadata
  ]
  
  @type pattern_spec :: %__MODULE__{
    pattern_type: atom(),
    pattern_ast: Macro.t() | nil,
    confidence_threshold: float(),
    match_variables: boolean(),
    context_sensitive: boolean(),
    custom_rules: list(function()) | nil,
    metadata: map()
  }
  
  @type pattern_match :: %{
    module: atom(),
    function: atom(),
    arity: non_neg_integer(),
    pattern_type: atom(),
    confidence: float(),
    location: %{
      file: String.t(),
      line_start: pos_integer(),
      line_end: pos_integer()
    },
    description: String.t(),
    severity: :info | :warning | :error | :critical,
    suggestions: list(String.t()),
    metadata: map()
  }
  
  @type pattern_result :: %{
    matches: list(pattern_match()),
    total_analyzed: non_neg_integer(),
    analysis_time_ms: non_neg_integer(),
    pattern_stats: map()
  }
  
  @default_confidence_threshold 0.7
  
  def default_confidence_threshold, do: @default_confidence_threshold
end
