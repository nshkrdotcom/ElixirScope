# test/elixir_scope/ast_repository/repository_test.exs
defmodule ElixirScope.ASTRepository.RepositoryTest do
  use ExUnit.Case
  use ExUnitProperties

  alias ElixirScope.ASTRepository.Repository
  alias ElixirScope.TestSupport.{Fixtures, Generators}

  describe "core repository operations" do
    test "stores and retrieves AST modules with instrumentation points" do
      # Given: A sample module AST with known instrumentation points
      {module_ast, expected_points} = Fixtures.SampleASTs.genserver_with_callbacks()

      # When: We store it in the repository
      {:ok, repo} = Repository.new()
      :ok = Repository.store_module(repo, module_ast)

      # Then: We can retrieve it with instrumentation points mapped
      {:ok, stored_module} = Repository.get_module(repo, TestModule)
      assert stored_module.instrumentation_points == expected_points
      assert stored_module.ast == module_ast
    end

    test "maintains correlation index integrity" do
      # Given: Multiple modules with overlapping correlation IDs
      modules = Fixtures.SampleASTs.multiple_modules_with_correlations()

      # When: We store them
      {:ok, repo} = Repository.new()
      Enum.each(modules, &Repository.store_module(repo, &1))

      # Then: Correlation index maintains referential integrity
      correlation_index = Repository.get_correlation_index(repo)

      for {correlation_id, ast_node_id} <- correlation_index do
        assert Repository.ast_node_exists?(repo, ast_node_id)
        assert Repository.correlation_id_valid?(repo, correlation_id)
      end
    end
  end

  describe "performance requirements" do
    test "AST storage completes under 10ms for medium modules" do
      module_ast = Fixtures.SampleASTs.medium_complexity_module()
      {:ok, repo} = Repository.new()

      {time_us, _result} = :timer.tc(fn ->
        Repository.store_module(repo, module_ast)
      end)

      time_ms = time_us / 1000
      assert time_ms < 10, "AST storage took #{time_ms}ms, expected < 10ms"
    end

    test "correlation lookup completes under 1ms" do
      # Setup: Repository with 1000 correlations
      {:ok, repo} = setup_repo_with_correlations(1000)
      correlation_id = Fixtures.random_correlation_id()

      {time_us, _result} = :timer.tc(fn ->
        Repository.get_ast_node_by_correlation(repo, correlation_id)
      end)

      time_ms = time_us / 1000
      assert time_ms < 1, "Correlation lookup took #{time_ms}ms, expected < 1ms"
    end
  end

  property "repository maintains AST integrity across operations" do
    check all module_ast <- Generators.valid_module_ast(),
              operations <- Generators.repository_operations() do

      {:ok, repo} = Repository.new()
      :ok = Repository.store_module(repo, module_ast)

      # Apply random operations
      final_repo = apply_operations(repo, operations)

      # Invariant: Original AST should still be retrievable and unchanged
      {:ok, retrieved} = Repository.get_module(final_repo, extract_module_name(module_ast))
      assert retrieved.ast == module_ast
    end
  end
end
