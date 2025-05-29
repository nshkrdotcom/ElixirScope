defmodule ElixirScope.ASTRepository.PatternMatcher.Stats do
  @moduledoc """
  Statistical analysis functions for pattern matching results.
  """
  
  alias ElixirScope.ASTRepository.PatternMatcher.Types
  
  @spec calculate_pattern_stats(list(Types.pattern_match())) :: map()
  def calculate_pattern_stats(matches) do
    %{
      total_matches: length(matches),
      by_severity: group_by_severity(matches),
      by_confidence: group_by_confidence(matches),
      avg_confidence: calculate_avg_confidence(matches)
    }
  end
  
  defp group_by_severity(matches) do
    Enum.group_by(matches, & &1.severity)
    |> Enum.map(fn {severity, matches} -> {severity, length(matches)} end)
    |> Enum.into(%{})
  end
  
  defp group_by_confidence(matches) do
    ranges = [
      {0.9, 1.0, :high},
      {0.7, 0.9, :medium},
      {0.5, 0.7, :low},
      {0.0, 0.5, :very_low}
    ]
    
    Enum.reduce(ranges, %{}, fn {min, max, label}, acc ->
      count = Enum.count(matches, fn match ->
        match.confidence >= min and match.confidence < max
      end)
      Map.put(acc, label, count)
    end)
  end
  
  defp calculate_avg_confidence([]), do: 0.0
  defp calculate_avg_confidence(matches) do
    total_confidence = Enum.reduce(matches, 0.0, & &1.confidence + &2)
    total_confidence / length(matches)
  end
end
