# test/elixir_scope/performance/hybrid_benchmarks_test.exs
defmodule ElixirScope.Performance.HybridBenchmarksTest do
  use ExUnit.Case

  @moduletag :performance

  describe "hybrid system performance benchmarks" do
    test "AST repository operations meet performance targets" do
      benchmarks = %{
        ast_storage: benchmark_ast_storage(),
        correlation_lookup: benchmark_correlation_lookup(),
        runtime_update: benchmark_runtime_update(),
        context_building: benchmark_context_building(),
        temporal_query: benchmark_temporal_query()
      }

      # Performance targets
      targets = %{
        ast_storage: 10,      # ms
        correlation_lookup: 1, # ms
        runtime_update: 5,     # ms
        context_building: 100, # ms
        temporal_query: 50     # ms
      }

      for {operation, actual_time} <- benchmarks do
        target_time = targets[operation]
        assert actual_time <= target_time,
          "#{operation} took #{actual_time}ms, expected <= #{target_time}ms"
      end
    end

    test "memory usage scales linearly with data size" do
      data_sizes = [100, 500, 1000, 5000]
      memory_usage = Enum.map(data_sizes, fn size ->
        {size, measure_memory_usage_for_repository_size(size)}
      end)

      # Check linear scaling
      correlation = calculate_linear_correlation(memory_usage)
      assert correlation >= 0.95, "Memory scaling correlation: #{correlation}, expected >= 0.95"
    end
  end
end
