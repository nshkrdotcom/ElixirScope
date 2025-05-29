# defmodule ElixirScope.ASTRepository.EnhancedRepositoryIntegrationTest do
#   use ExUnit.Case, async: true

#   alias ElixirScope.ASTRepository.EnhancedRepository
#   alias ElixirScope.TestHelpers

#   describe "Repository Integration for CPGs" do
#     setup do
#       :ok = TestHelpers.ensure_config_available()

#       # Start a fresh EnhancedRepository for each test
#       {:ok, repo} = EnhancedRepository.start_link([])

#       on_exit(fn ->
#         if Process.alive?(repo) do
#           GenServer.stop(repo)
#         end
#       end)

#       %{repo: repo}
#     end

#     test "store_enhanced_module triggers CPG generation and stores CPGData correctly", %{repo: _repo} do
#       # Given: A sample module AST
#       module_ast = quote do
#         defmodule TestModule do
#           def simple_function(x) do
#             if x > 0 do
#               :positive
#             else
#               :negative
#             end
#           end

#           def another_function(y) do
#             case y do
#               :a -> :first
#               :b -> :second
#               _ -> :default
#             end
#           end
#         end
#       end

#       # When: We store the enhanced module
#       result = EnhancedRepository.store_enhanced_module(TestModule, module_ast)

#       # Then: Storage succeeds and returns enhanced module data
#       assert {:ok, enhanced_data} = result
#       assert enhanced_data.module_name == TestModule
#       assert enhanced_data.ast == module_ast

#       # And: Functions are extracted and stored
#       assert map_size(enhanced_data.functions) >= 2
#       assert Map.has_key?(enhanced_data.functions, {:simple_function, 1})
#       assert Map.has_key?(enhanced_data.functions, {:another_function, 1})

#       # And: Module can be retrieved
#       {:ok, retrieved_data} = EnhancedRepository.get_enhanced_module(TestModule)
#       assert retrieved_data.module_name == TestModule
#       assert retrieved_data.ast == module_ast

#       # And: CPG data can be generated for functions
#       {:ok, simple_cpg} = EnhancedRepository.get_cpg(TestModule, :simple_function, 1)
#       assert simple_cpg != nil
#       assert simple_cpg.nodes != nil
#       assert simple_cpg.edges != nil

#       {:ok, another_cpg} = EnhancedRepository.get_cpg(TestModule, :another_function, 1)
#       assert another_cpg != nil
#       assert another_cpg.nodes != nil
#       assert another_cpg.edges != nil
#     end

#     test "get_cpg/3 retrieves the previously generated and stored CPGData", %{repo: _repo} do
#       # Given: A module with a function stored in the repository
#       module_ast = quote do
#         defmodule RetrievalTestModule do
#           def test_function(input) do
#             result = process(input)
#             validate(result)
#           end
#         end
#       end

#       # Store the module
#       {:ok, _enhanced_data} = EnhancedRepository.store_enhanced_module(RetrievalTestModule, module_ast)

#       # When: We request CPG for the first time (triggers generation)
#       {:ok, first_cpg} = EnhancedRepository.get_cpg(RetrievalTestModule, :test_function, 1)

#       # Then: CPG is generated and returned
#       assert first_cpg != nil
#       assert first_cpg.nodes != nil
#       assert first_cpg.edges != nil

#       # When: We request the same CPG again (should retrieve cached)
#       {:ok, second_cpg} = EnhancedRepository.get_cpg(RetrievalTestModule, :test_function, 1)

#       # Then: Same CPG is returned (cached)
#       assert second_cpg == first_cpg
#     end

#     test "get_cpg/3 triggers on-demand CPG generation if CPGData is not already stored, then stores and returns it", %{repo: _repo} do
#       # Given: A module stored without pre-generated CPG
#       module_ast = quote do
#         defmodule OnDemandTestModule do
#           def on_demand_function(data) do
#             with {:ok, validated} <- validate(data),
#                  {:ok, processed} <- process(validated) do
#               {:success, processed}
#             else
#               error -> {:failure, error}
#             end
#           end
#         end
#       end

#       # Store module (without triggering CPG generation)
#       {:ok, _enhanced_data} = EnhancedRepository.store_enhanced_module(OnDemandTestModule, module_ast)

#       # When: We request CPG (should trigger on-demand generation)
#       {:ok, cpg} = EnhancedRepository.get_cpg(OnDemandTestModule, :on_demand_function, 1)

#       # Then: CPG is generated and returned
#       assert cpg != nil
#       assert cpg.nodes != nil
#       assert cpg.edges != nil

#       # And: CPG contains expected structure for with statement
#       # Note: Specific validation depends on CPG implementation
#       assert map_size(cpg.nodes) > 0
#       assert length(cpg.edges) > 0

#       # And: Subsequent requests return the cached CPG
#       {:ok, cached_cpg} = EnhancedRepository.get_cpg(OnDemandTestModule, :on_demand_function, 1)
#       assert cached_cpg == cpg
#     end

#     test "updating a module (AST change) invalidates or triggers update of its associated CPGs", %{repo: _repo} do
#       # Given: A module with initial AST
#       original_ast = quote do
#         defmodule UpdatableTestModule do
#           def changeable_function(x) do
#             x + 1
#           end
#         end
#       end

#       # Store initial version
#       {:ok, _original_data} = EnhancedRepository.store_enhanced_module(UpdatableTestModule, original_ast)

#       # Generate initial CPG
#       {:ok, original_cpg} = EnhancedRepository.get_cpg(UpdatableTestModule, :changeable_function, 1)

#       # When: We update the module with changed AST
#       updated_ast = quote do
#         defmodule UpdatableTestModule do
#           def changeable_function(x) do
#             if x > 0 do
#               x * 2
#             else
#               x - 1
#             end
#           end
#         end
#       end

#       {:ok, _updated_data} = EnhancedRepository.store_enhanced_module(UpdatableTestModule, updated_ast)

#       # Then: New CPG should be different (indicating regeneration)
#       {:ok, updated_cpg} = EnhancedRepository.get_cpg(UpdatableTestModule, :changeable_function, 1)

#       # CPG should be regenerated and different
#       assert updated_cpg != original_cpg

#       # Updated CPG should reflect the new conditional structure
#       assert map_size(updated_cpg.nodes) >= map_size(original_cpg.nodes)
#     end

#     test "handles complex modules with multiple functions and generates CPGs for each", %{repo: _repo} do
#       # Given: A complex module with multiple functions
#       complex_ast = quote do
#         defmodule ComplexTestModule do
#           def function_one(input) do
#             case input do
#               {:ok, data} -> process_data(data)
#               {:error, reason} -> handle_error(reason)
#               _ -> :unknown
#             end
#           end

#           def function_two(list) do
#             for item <- list, item > 0 do
#               item * 2
#             end
#           end

#           def function_three(x, y) do
#             try do
#               x / y
#             rescue
#               ArithmeticError -> :division_by_zero
#             end
#           end

#           defp private_helper(data) do
#             String.upcase(data)
#           end
#         end
#       end

#       # When: We store the complex module
#       {:ok, _enhanced_data} = EnhancedRepository.store_enhanced_module(ComplexTestModule, complex_ast)

#       # Then: CPGs can be generated for all functions
#       {:ok, cpg1} = EnhancedRepository.get_cpg(ComplexTestModule, :function_one, 1)
#       {:ok, cpg2} = EnhancedRepository.get_cpg(ComplexTestModule, :function_two, 1)
#       {:ok, cpg3} = EnhancedRepository.get_cpg(ComplexTestModule, :function_three, 2)
#       {:ok, cpg4} = EnhancedRepository.get_cpg(ComplexTestModule, :private_helper, 1)

#       # All CPGs should be valid and distinct
#       cpgs = [cpg1, cpg2, cpg3, cpg4]

#       Enum.each(cpgs, fn cpg ->
#         assert cpg != nil
#         assert cpg.nodes != nil
#         assert cpg.edges != nil
#         assert map_size(cpg.nodes) > 0
#       end)

#       # Each CPG should be unique (different functions have different structures)
#       assert cpg1 != cpg2
#       assert cpg2 != cpg3
#       assert cpg3 != cpg4
#     end

#     test "preserves CPG data across repository restarts", %{repo: _repo} do
#       # Given: A module with generated CPG
#       module_ast = quote do
#         defmodule PersistentTestModule do
#           def persistent_function(data) do
#             data
#             |> validate()
#             |> transform()
#             |> save()
#           end
#         end
#       end

#       # Store module and generate CPG
#       {:ok, _enhanced_data} = EnhancedRepository.store_enhanced_module(PersistentTestModule, module_ast)
#       {:ok, original_cpg} = EnhancedRepository.get_cpg(PersistentTestModule, :persistent_function, 1)

#       # When: We restart the repository
#       GenServer.stop(_repo)
#       {:ok, repo2} = EnhancedRepository.start_link([])

#       # Store the module again (simulating restart with persistence)
#       {:ok, _restored_data} = EnhancedRepository.store_enhanced_module(PersistentTestModule, module_ast)

#       # Then: CPG can be regenerated and should be equivalent
#       {:ok, restored_cpg} = EnhancedRepository.get_cpg(PersistentTestModule, :persistent_function, 1)

#       # CPG structure should be equivalent (may not be identical due to ID generation)
#       assert map_size(restored_cpg.nodes) == map_size(original_cpg.nodes)
#       assert length(restored_cpg.edges) == length(original_cpg.edges)

#       # Clean up
#       GenServer.stop(repo2)
#     end

#     test "handles CPG generation errors gracefully and provides meaningful error messages", %{repo: _repo} do
#       # Given: A problematic AST that might cause CPG generation issues
#       problematic_ast = quote do
#         defmodule ProblematicModule do
#           def problematic_function do
#             # This might cause issues in CPG generation
#             very_complex_nested_structure = fn ->
#               fn ->
#                 fn ->
#                   :deeply_nested
#                 end
#               end
#             end

#             very_complex_nested_structure.().().()
#           end
#         end
#       end

#       # When: We store the module
#       result = EnhancedRepository.store_enhanced_module(ProblematicModule, problematic_ast)

#       # Then: Storage should succeed even if CPG generation might have issues
#       case result do
#         {:ok, _enhanced_data} ->
#           # Storage succeeded, now try CPG generation
#           case EnhancedRepository.get_cpg(ProblematicModule, :problematic_function, 0) do
#             {:ok, cpg} ->
#               # CPG generation succeeded
#               assert cpg != nil

#             {:error, reason} ->
#               # CPG generation failed gracefully
#               assert is_atom(reason) or is_binary(reason) or is_tuple(reason)
#               IO.puts("CPG generation failed gracefully: #{inspect(reason)}")
#           end

#         {:error, reason} ->
#           # Storage failed, which is also acceptable for problematic AST
#           assert is_atom(reason) or is_binary(reason) or is_tuple(reason)
#           IO.puts("Module storage failed gracefully: #{inspect(reason)}")
#       end
#     end
#   end
# end
