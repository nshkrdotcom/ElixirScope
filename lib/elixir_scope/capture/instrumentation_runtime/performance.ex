defmodule ElixirScope.Capture.InstrumentationRuntime.Performance do
  @moduledoc """
  Performance monitoring and measurement functionality.

  Provides tools to measure the overhead of instrumentation calls
  and validate performance targets.
  """

  alias ElixirScope.Capture.InstrumentationRuntime.{Context, CoreReporting}

  @doc """
  Measures the overhead of instrumentation calls.

  Returns timing statistics for performance validation.
  """
  @spec measure_overhead(pos_integer()) :: %{
    entry_avg_ns: float(),
    exit_avg_ns: float(),
    disabled_avg_ns: float()
  }
  def measure_overhead(iterations \\ 10000) do
    # Initialize context for testing
    Context.initialize_context()

    # Measure function entry overhead
    entry_times = for _ <- 1..iterations do
      start = System.monotonic_time(:nanosecond)
      correlation_id = CoreReporting.report_function_entry(TestModule, :test_function, [])
      duration = System.monotonic_time(:nanosecond) - start

      # Clean up
      if correlation_id, do: CoreReporting.report_function_exit(correlation_id, :ok, 0)

      duration
    end

    # Measure function exit overhead
    exit_times = for _ <- 1..iterations do
      correlation_id = CoreReporting.report_function_entry(TestModule, :test_function, [])

      start = System.monotonic_time(:nanosecond)
      CoreReporting.report_function_exit(correlation_id, :ok, 0)
      duration = System.monotonic_time(:nanosecond) - start

      duration
    end

    # Measure disabled overhead
    Context.clear_context()
    disabled_times = for _ <- 1..iterations do
      start = System.monotonic_time(:nanosecond)
      CoreReporting.report_function_entry(TestModule, :test_function, [])
      System.monotonic_time(:nanosecond) - start
    end

    %{
      entry_avg_ns: Enum.sum(entry_times) / length(entry_times),
      exit_avg_ns: Enum.sum(exit_times) / length(exit_times),
      disabled_avg_ns: Enum.sum(disabled_times) / length(disabled_times)
    }
  end
end
