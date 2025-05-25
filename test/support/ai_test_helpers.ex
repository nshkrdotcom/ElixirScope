defmodule ElixirScope.AITestHelpers do
  @moduledoc """
  Test helpers for AI-specific testing patterns including probabilistic validation,
  mock data generation, and accuracy assessment.
  """

  @doc """
  Creates mock execution data for testing predictive models.
  """
  def create_mock_execution_data(opts \\ []) do
    %{
      function_name: opts[:function] || :test_function,
      module: opts[:module] || TestModule,
      args: opts[:args] || [1, 2, 3],
      execution_time: opts[:time] || 100,
      memory_usage: opts[:memory] || 1024,
      cpu_usage: opts[:cpu] || 0.5,
      timestamp: opts[:timestamp] || DateTime.utc_now(),
      correlation_id: opts[:correlation_id] || generate_correlation_id()
    }
  end

  @doc """
  Creates a historical dataset for training and testing predictive models.
  """
  def create_historical_dataset(size \\ 1000) do
    for _ <- 1..size do
      create_mock_execution_data([
        time: :rand.uniform(1000),
        memory: :rand.uniform(10000),
        cpu: :rand.uniform() * 100
      ])
    end
  end

  @doc """
  Asserts that a prediction is within acceptable tolerance of the actual value.
  """
  def assert_prediction_quality(prediction, actual, tolerance \\ 0.2) do
    error_rate = abs(prediction - actual) / actual
    ExUnit.Assertions.assert error_rate <= tolerance,
           "Prediction error too high: #{error_rate * 100}% (tolerance: #{tolerance * 100}%)"
  end

  @doc """
  Asserts that a probability value is within valid range [0, 1].
  """
  def assert_probability_range(actual, expected, tolerance \\ 0.1) do
    ExUnit.Assertions.assert abs(actual - expected) <= tolerance,
           "Expected #{expected} ± #{tolerance}, got #{actual}"
  end

  @doc """
  Asserts that a confidence score is valid (between 0 and 1).
  """
  def assert_confidence_score(score) do
    ExUnit.Assertions.assert score >= 0.0 and score <= 1.0,
           "Confidence score must be between 0 and 1, got #{score}"
  end

  @doc """
  Calculates accuracy between predictions and actual values.
  """
  def calculate_accuracy(predictions, actuals) when is_list(predictions) and is_list(actuals) do
    if length(predictions) != length(actuals) do
      raise ArgumentError, "Predictions and actuals must have same length"
    end

    correct_predictions = 
      Enum.zip(predictions, actuals)
      |> Enum.count(fn {pred, actual} -> 
        error_rate = abs(pred - actual) / actual
        error_rate <= 0.2  # 20% tolerance
      end)

    correct_predictions / length(predictions)
  end

  def calculate_accuracy(prediction, actual) when is_number(prediction) and is_number(actual) do
    error_rate = abs(prediction - actual) / actual
    if error_rate <= 0.2, do: 1.0, else: 0.0
  end

  @doc """
  Creates mock training data with specific patterns for testing learning algorithms.
  """
  def create_pattern_data(pattern_type, size \\ 100) do
    case pattern_type do
      :linear ->
        for i <- 1..size do
          %{
            input: i,
            output: i * 2 + :rand.normal(0, 1),
            pattern: :linear
          }
        end

      :exponential ->
        for i <- 1..size do
          %{
            input: i,
            output: :math.pow(2, i/10) + :rand.normal(0, 0.5),
            pattern: :exponential
          }
        end

      :cyclical ->
        for i <- 1..size do
          %{
            input: i,
            output: :math.sin(i * :math.pi() / 10) + :rand.normal(0, 0.1),
            pattern: :cyclical
          }
        end

      :random ->
        for _ <- 1..size do
          %{
            input: :rand.uniform(100),
            output: :rand.uniform(100),
            pattern: :random
          }
        end
    end
  end

  @doc """
  Simulates execution context for testing.
  """
  def create_execution_context(opts \\ []) do
    %{
      function: opts[:function] || :test_function,
      module: opts[:module] || TestModule,
      input_size: opts[:input_size] || 100,
      concurrency_level: opts[:concurrency] || 1,
      system_load: opts[:load] || 0.5,
      available_memory: opts[:memory] || 1_000_000,
      historical_data: opts[:history] || create_historical_dataset(50)
    }
  end

  @doc """
  Creates mock failure scenarios for testing failure prediction.
  """
  def create_failure_scenarios(scenario_type, count \\ 10) do
    case scenario_type do
      :timeout ->
        for _ <- 1..count do
          %{
            error_type: :timeout,
            context: %{execution_time: 5000 + :rand.uniform(5000)},
            frequency: :rand.uniform(10),
            severity: :high
          }
        end

      :memory ->
        for _ <- 1..count do
          %{
            error_type: :out_of_memory,
            context: %{memory_usage: 1_000_000 + :rand.uniform(1_000_000)},
            frequency: :rand.uniform(5),
            severity: :critical
          }
        end

      :network ->
        for _ <- 1..count do
          %{
            error_type: :network_error,
            context: %{network_latency: 1000 + :rand.uniform(2000)},
            frequency: :rand.uniform(15),
            severity: :medium
          }
        end

      :cascade ->
        for _ <- 1..count do
          %{
            error_type: :cascade_failure,
            context: %{
              initial_failure: Enum.random([:timeout, :memory, :network]),
              propagation_depth: :rand.uniform(5)
            },
            frequency: :rand.uniform(3),
            severity: :critical
          }
        end
    end
  end

  @doc """
  Validates that AI model outputs conform to expected structure.
  """
  def assert_ai_response_structure(response, expected_keys) do
    ExUnit.Assertions.assert is_map(response), "Response must be a map"
    
    for key <- expected_keys do
      ExUnit.Assertions.assert Map.has_key?(response, key), 
             "Response missing required key: #{key}"
    end
  end

  @doc """
  Measures execution time of a function for performance testing.
  """
  def measure_execution_time(fun) when is_function(fun, 0) do
    {time_microseconds, result} = :timer.tc(fun)
    {time_microseconds / 1000, result}  # Return time in milliseconds
  end

  @doc """
  Creates a batch of test requests for load testing.
  """
  def create_test_batch(size, request_generator) when is_function(request_generator, 0) do
    for _ <- 1..size, do: request_generator.()
  end

  @doc """
  Simulates concurrent AI requests for load testing.
  """
  def simulate_concurrent_requests(request_count, request_fun) when is_function(request_fun, 0) do
    tasks = for _ <- 1..request_count do
      Task.async(fn ->
        start_time = System.monotonic_time(:millisecond)
        result = request_fun.()
        end_time = System.monotonic_time(:millisecond)
        
        %{
          result: result,
          response_time: end_time - start_time,
          success: match?({:ok, _}, result)
        }
      end)
    end

    Task.await_many(tasks, 10_000)
  end

  @doc """
  Calculates performance metrics from concurrent request results.
  """
  def calculate_performance_metrics(results) do
    total_requests = length(results)
    successful_requests = Enum.count(results, & &1.success)
    response_times = Enum.map(results, & &1.response_time)

    %{
      total_requests: total_requests,
      successful_requests: successful_requests,
      success_rate: successful_requests / total_requests,
      avg_response_time: Enum.sum(response_times) / length(response_times),
      min_response_time: Enum.min(response_times),
      max_response_time: Enum.max(response_times),
      p95_response_time: percentile(response_times, 0.95),
      p99_response_time: percentile(response_times, 0.99)
    }
  end

  # Private helper functions

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp percentile(list, p) when p >= 0 and p <= 1 do
    sorted = Enum.sort(list)
    index = round(p * (length(sorted) - 1))
    Enum.at(sorted, index)
  end
end 