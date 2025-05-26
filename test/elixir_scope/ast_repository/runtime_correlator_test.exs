# test/elixir_scope/ast_repository/runtime_correlator_test.exs
defmodule ElixirScope.ASTRepository.RuntimeCorrelatorTest do
  use ExUnit.Case

  alias ElixirScope.ASTRepository.RuntimeCorrelator
  alias ElixirScope.TestSupport.{Fixtures, EventSimulator}

  describe "AST-Runtime correlation accuracy" do
    test "correlates function entry events to AST nodes with 99%+ accuracy" do
      # Given: Repository with known AST structure
      {:ok, repo} = setup_test_repository()
      {:ok, correlator} = RuntimeCorrelator.start_link(repository: repo)

      # When: We simulate runtime events with correlation IDs
      simulated_events = EventSimulator.generate_function_entry_events(1000)

      correlation_results = for event <- simulated_events do
        case RuntimeCorrelator.correlate_event(correlator, event) do
          {:ok, ast_node_id} -> {:success, event.correlation_id, ast_node_id}
          {:error, reason} -> {:error, event.correlation_id, reason}
        end
      end

      # Then: Correlation accuracy should be 99%+
      success_count = Enum.count(correlation_results, &match?({:success, _, _}, &1))
      accuracy = success_count / length(simulated_events)

      assert accuracy >= 0.99, "Correlation accuracy: #{accuracy}, expected >= 0.99"
    end

    test "correlation latency under 5ms for single events" do
      {:ok, repo} = setup_test_repository()
      {:ok, correlator} = RuntimeCorrelator.start_link(repository: repo)

      event = Fixtures.RuntimeEvents.function_call_event()

      {time_us, _result} = :timer.tc(fn ->
        RuntimeCorrelator.correlate_event(correlator, event)
      end)

      time_ms = time_us / 1000
      assert time_ms < 5, "Correlation took #{time_ms}ms, expected < 5ms"
    end

    test "handles correlation failures gracefully" do
      {:ok, repo} = setup_test_repository()
      {:ok, correlator} = RuntimeCorrelator.start_link(repository: repo)

      # Event with invalid correlation ID
      invalid_event = %{
        correlation_id: "invalid-correlation-id",
        event_type: :function_entry,
        data: %{}
      }

      # Should not crash and should return meaningful error
      assert {:error, {:correlation_not_found, _}} =
        RuntimeCorrelator.correlate_event(correlator, invalid_event)

      # Correlator should still be responsive
      assert Process.alive?(correlator)
    end
  end

  describe "repository update accuracy" do
    test "updates AST nodes with runtime insights" do
      {:ok, repo} = setup_test_repository()
      {:ok, correlator} = RuntimeCorrelator.start_link(repository: repo)

      # Given: Function call with performance data
      performance_event = Fixtures.RuntimeEvents.function_call_with_performance()

      # When: We correlate and update
      {:ok, ast_node_id} = RuntimeCorrelator.correlate_event(correlator, performance_event)
      :ok = RuntimeCorrelator.update_ast_with_runtime_data(correlator, ast_node_id, performance_event)

      # Then: AST node should have runtime insights
      {:ok, updated_node} = Repository.get_ast_node(repo, ast_node_id)

      assert updated_node.runtime_insights != nil
      assert updated_node.runtime_insights.call_count >= 1
      assert updated_node.runtime_insights.avg_duration_ms > 0
    end
  end
end
