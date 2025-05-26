# test/elixir_scope/integration/end_to_end_hybrid_test.exs
defmodule ElixirScope.Integration.EndToEndHybridTest do
  use ExUnit.Case

  @moduletag :integration

  describe "complete hybrid workflow" do
    test "end-to-end: AST analysis → instrumentation → runtime correlation → AI analysis" do
      # Step 1: Parse and store AST
      source_code = Fixtures.RealWorldCode.complex_genserver()
      {:ok, parsed} = ElixirScope.ASTRepository.Parser.parse_with_instrumentation_mapping(source_code)

      {:ok, repo} = ElixirScope.ASTRepository.Repository.new()
      :ok = ElixirScope.ASTRepository.Repository.store_module(repo, parsed)

      # Step 2: Generate instrumentation plan
      {:ok, plan} = ElixirScope.CompileTime.Orchestrator.generate_plan(TestModule, %{
        granularity: :function_boundaries,
        capture_locals: [:state, :result]
      })

      # Step 3: Transform AST with instrumentation
      instrumented_ast = ElixirScope.AST.EnhancedTransformer.transform_with_enhanced_instrumentation(
        parsed.ast, plan
      )

      # Step 4: Compile and execute instrumented code
      {module, _bytecode} = Code.eval_quoted(instrumented_ast)

      # Step 5: Execute code and capture events
      {:ok, correlator} = ElixirScope.ASTRepository.RuntimeCorrelator.start_link(repository: repo)

      # Simulate execution
      events = capture_events_during_execution(fn ->
        {:ok, pid} = module.start_link()
        :ok = GenServer.call(pid, {:process_data, [1, 2, 3]})
        GenServer.stop(pid)
      end)

      # Step 6: Verify correlation accuracy
      correlated_events = correlate_events_with_ast(events, correlator)
      correlation_accuracy = calculate_correlation_accuracy(correlated_events)

      assert correlation_accuracy >= 0.95, "Expected 95%+ correlation, got #{correlation_accuracy}"

      # Step 7: Build hybrid context and analyze with AI
      query = %{type: :performance_analysis, target_module: module}
      hybrid_context = ElixirScope.LLM.ContextBuilder.build_hybrid_context(query, repository: repo)

      {:ok, ai_analysis} = ElixirScope.LLM.HybridAnalyzer.analyze_with_context(hybrid_context)

      # Step 8: Verify AI analysis includes both static and runtime insights
      assert ai_analysis.static_insights != []
      assert ai_analysis.runtime_insights != []
      assert ai_analysis.hybrid_insights != []

      # Performance requirement: Entire workflow under 30s
      # (This would be measured by wrapping the entire test in :timer.tc)
    end
  end

  describe "scalability validation" do
    test "handles large project with 100+ modules efficiently" do
      # Setup: Large project repository
      {:ok, repo} = setup_large_project_repository(module_count: 100)

      # Test: Various operations at scale
      query_time = benchmark(fn ->
        ElixirScope.ASTRepository.Repository.query_modules(repo, %{
          pattern: :genserver,
          with_runtime_data: true
        })
      end)

      context_build_time = benchmark(fn ->
        ElixirScope.LLM.ContextBuilder.build_hybrid_context(%{
          type: :project_overview,
          include_all_modules: true
        }, repository: repo)
      end)

      # Performance requirements for large projects
      assert query_time < 500, "Query took #{query_time}ms, expected < 500ms"
      assert context_build_time < 2000, "Context building took #{context_build_time}ms, expected < 2s"
    end
  end
end
