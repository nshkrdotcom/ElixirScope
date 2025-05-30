defmodule ElixirScope.ASTRepository.Enhanced.ProjectPopulator.PerformanceMetrics do
  @moduledoc """
  Calculates performance metrics for project analysis.

  Provides functionality to:
  - Calculate processing times
  - Measure throughput
  - Analyze resource utilization
  - Generate performance reports
  """

  @doc """
  Calculates comprehensive performance metrics.
  """
  def calculate_performance_metrics(parsed_files, analyzed_modules, total_duration) do
    file_count = length(parsed_files)
    module_count = map_size(analyzed_modules)
    duration_seconds = total_duration / 1_000_000

    %{
      total_duration_ms: total_duration / 1000,
      avg_parse_time_ms: if(file_count > 0, do: (Enum.sum(Enum.map(parsed_files, & &1.parse_time)) / file_count) / 1000, else: 0.0),
      files_per_second: if(duration_seconds > 0, do: file_count / duration_seconds, else: 0.0),
      modules_per_second: if(duration_seconds > 0, do: module_count / duration_seconds, else: 0.0),
      total_file_size: Enum.sum(Enum.map(parsed_files, & &1.file_size)),
      total_lines: Enum.sum(Enum.map(parsed_files, & &1.line_count))
    }
  end
end
