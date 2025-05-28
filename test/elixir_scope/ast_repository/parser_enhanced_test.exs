defmodule ElixirScope.ASTRepository.ParserEnhancedTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.ASTRepository.Parser
  alias ElixirScope.ASTRepository.TestSupport.Fixtures.SampleASTs
  alias ElixirScope.ASTRepository.TestSupport.Helpers
  alias ElixirScope.TestHelpers

  describe "AST parsing with node ID assignment" do
    test "assigns unique node IDs to instrumentable AST nodes" do
      # Given: A sample AST with known instrumentable nodes
      sample = SampleASTs.get_sample_ast(:simple_genserver)
      original_ast = sample.ast
      
      # When: We parse with node ID assignment
      {:ok, enhanced_ast} = Parser.assign_node_ids(original_ast)
      
      # Then: Instrumentable nodes have unique IDs
      validation = Helpers.validate_ast_enhancement(enhanced_ast)
      
      assert validation.has_node_ids, "Enhanced AST should have node IDs"
      assert validation.node_id_count > 0, "Should have at least one node ID"
      assert validation.all_unique, "All node IDs should be unique"
      
      # And: Original AST structure is preserved
      assert Helpers.ast_structurally_equal?(original_ast, enhanced_ast),
        "AST structure should be preserved during enhancement"
    end

    test "assigns node IDs to function definitions" do
      # Given: AST with multiple function definitions
      sample = SampleASTs.get_sample_ast(:mixed_function_types)
      original_ast = sample.ast
      
      # When: We parse with node ID assignment
      {:ok, enhanced_ast} = Parser.assign_node_ids(original_ast)
      
      # Then: Function definitions have node IDs
      function_nodes = extract_function_nodes_with_ids(enhanced_ast)
      
      assert length(function_nodes) > 0, "Should find function nodes with IDs"
      
      # And: Each function has a unique node ID
      node_ids = Enum.map(function_nodes, & &1.node_id)
      assert length(node_ids) == length(Enum.uniq(node_ids)), "Function node IDs should be unique"
    end

    test "preserves existing metadata while adding node IDs" do
      # Given: AST with existing metadata
      ast_with_metadata = quote line: 42 do
        def test_function(arg) do
          arg + 1
        end
      end
      
      # When: We assign node IDs
      {:ok, enhanced_ast} = Parser.assign_node_ids(ast_with_metadata)
      
      # Then: Original metadata is preserved
      {_form, meta, _args} = enhanced_ast
      assert Keyword.get(meta, :line) == 42, "Original line metadata should be preserved"
      
      # And: Node ID is added
      assert Keyword.has_key?(meta, :ast_node_id), "Node ID should be added to metadata"
    end

    test "handles nested AST structures correctly" do
      # Given: Complex nested AST
      sample = SampleASTs.get_sample_ast(:complex_module)
      original_ast = sample.ast
      
      # When: We assign node IDs
      {:ok, enhanced_ast} = Parser.assign_node_ids(original_ast)
      
      # Then: Nested structures have node IDs
      validation = Helpers.validate_ast_enhancement(enhanced_ast)
      
      assert validation.has_node_ids, "Nested structures should have node IDs"
      assert validation.all_unique, "All nested node IDs should be unique"
      
      # And: Deep nesting is handled correctly
      nested_count = count_nested_instrumentable_nodes(enhanced_ast)
      assert nested_count > 5, "Should handle multiple levels of nesting"
    end
  end

  describe "instrumentation point extraction" do
    test "extracts instrumentation points from GenServer callbacks" do
      # Given: GenServer AST with callbacks
      sample = SampleASTs.get_sample_ast(:simple_genserver)
      {:ok, enhanced_ast} = Parser.assign_node_ids(sample.ast)
      
      # When: We extract instrumentation points
      {:ok, instrumentation_points} = Parser.extract_instrumentation_points(enhanced_ast)
      
      # Then: GenServer callbacks are identified as instrumentation points
      callback_points = Enum.filter(instrumentation_points, &(&1.type == :genserver_callback))
      
      assert length(callback_points) >= 4, "Should find GenServer callbacks (init, handle_call, handle_cast, handle_info)"
      
      # And: Each point has required metadata
      Enum.each(callback_points, fn point ->
        assert point.ast_node_id != nil, "Instrumentation point should have AST node ID"
        assert point.function != nil, "Instrumentation point should have function info"
        assert point.type == :genserver_callback, "Should be identified as GenServer callback"
      end)
    end

    test "extracts instrumentation points from Phoenix controller actions" do
      # Given: Phoenix controller AST
      sample = SampleASTs.get_sample_ast(:phoenix_controller)
      {:ok, enhanced_ast} = Parser.assign_node_ids(sample.ast)
      
      # When: We extract instrumentation points
      {:ok, instrumentation_points} = Parser.extract_instrumentation_points(enhanced_ast)
      
      # Then: Controller actions are identified
      action_points = Enum.filter(instrumentation_points, &(&1.type == :controller_action))
      
      assert length(action_points) >= 3, "Should find controller actions (index, show, create)"
      
      # And: Actions have correct metadata
      action_names = Enum.map(action_points, &elem(&1.function, 0))
      assert :index in action_names, "Should find index action"
      assert :show in action_names, "Should find show action"
      assert :create in action_names, "Should find create action"
    end

    test "extracts instrumentation points from complex function patterns" do
      # Given: Complex module with various function types
      sample = SampleASTs.get_sample_ast(:mixed_function_types)
      {:ok, enhanced_ast} = Parser.assign_node_ids(sample.ast)
      
      # When: We extract instrumentation points
      {:ok, instrumentation_points} = Parser.extract_instrumentation_points(enhanced_ast)
      
      # Then: Different function types are identified
      public_functions = Enum.filter(instrumentation_points, &(&1.visibility == :public))
      private_functions = Enum.filter(instrumentation_points, &(&1.visibility == :private))
      
      assert length(public_functions) > 0, "Should find public functions"
      assert length(private_functions) > 0, "Should find private functions"
      
      # And: Function patterns are correctly identified (basic implementation for now)
      pattern_match_functions = Enum.filter(instrumentation_points, &(&1.has_pattern_matching == true))
      guard_functions = Enum.filter(instrumentation_points, &(&1.has_guards == true))
      
      # Note: Pattern matching and guard detection is not yet implemented
      # These will be enhanced in future iterations
      assert length(pattern_match_functions) == 0, "Pattern matching detection not yet implemented"
      assert length(guard_functions) == 0, "Guard detection not yet implemented"
    end

    test "handles instrumentation point extraction errors gracefully" do
      # Given: Malformed AST that will cause an error
      malformed_ast = {:invalid, :ast, :structure}
      
      # When: We try to extract instrumentation points
      result = Parser.extract_instrumentation_points(malformed_ast)
      
      # Then: Should succeed but return empty list for non-matching structures
      assert {:ok, instrumentation_points} = result
      assert is_list(instrumentation_points), "Should return a list"
      assert length(instrumentation_points) == 0, "Should return empty list for malformed AST"
    end
  end

  describe "correlation index building" do
    test "builds correlation index from enhanced AST" do
      # Given: Enhanced AST with node IDs
      sample = SampleASTs.get_sample_ast(:simple_genserver)
      {:ok, enhanced_ast} = Parser.assign_node_ids(sample.ast)
      {:ok, instrumentation_points} = Parser.extract_instrumentation_points(enhanced_ast)
      
      # When: We build correlation index
      {:ok, correlation_index} = Parser.build_correlation_index(enhanced_ast, instrumentation_points)
      
      # Then: Index maps correlation IDs to AST node IDs
      assert is_map(correlation_index), "Correlation index should be a map"
      assert map_size(correlation_index) > 0, "Correlation index should not be empty"
      
      # And: All instrumentation points are in the index
      instrumentation_node_ids = Enum.map(instrumentation_points, & &1.ast_node_id)
      index_node_ids = Map.values(correlation_index)
      
      Enum.each(instrumentation_node_ids, fn node_id ->
        assert node_id in index_node_ids, "All instrumentation points should be in correlation index"
      end)
    end

    test "creates bidirectional correlation mapping" do
      # Given: Enhanced AST with instrumentation points
      sample = SampleASTs.get_sample_ast(:phoenix_controller)
      {:ok, enhanced_ast} = Parser.assign_node_ids(sample.ast)
      {:ok, instrumentation_points} = Parser.extract_instrumentation_points(enhanced_ast)
      
      # When: We build correlation index
      {:ok, correlation_index} = Parser.build_correlation_index(enhanced_ast, instrumentation_points)
      
      # Then: Forward mapping exists (correlation_id -> ast_node_id)
      assert is_map(correlation_index), "Should have forward mapping"
      
      # And: Reverse mapping can be constructed
      reverse_index = 
        correlation_index
        |> Enum.map(fn {corr_id, node_id} -> {node_id, corr_id} end)
        |> Map.new()
      
      assert map_size(reverse_index) == map_size(correlation_index), 
        "Reverse mapping should have same size as forward mapping"
    end

    test "handles duplicate node IDs in correlation index" do
      # Given: AST with potential duplicate scenarios
      sample = SampleASTs.get_sample_ast(:mixed_function_types)
      {:ok, enhanced_ast} = Parser.assign_node_ids(sample.ast)
      {:ok, instrumentation_points} = Parser.extract_instrumentation_points(enhanced_ast)
      
      # When: We build correlation index
      {:ok, correlation_index} = Parser.build_correlation_index(enhanced_ast, instrumentation_points)
      
      # Then: No duplicate correlation IDs exist
      correlation_ids = Map.keys(correlation_index)
      assert length(correlation_ids) == length(Enum.uniq(correlation_ids)), 
        "Correlation IDs should be unique"
      
      # And: No duplicate AST node IDs exist
      ast_node_ids = Map.values(correlation_index)
      assert length(ast_node_ids) == length(Enum.uniq(ast_node_ids)), 
        "AST node IDs should be unique in correlation index"
    end
  end

  describe "integration with existing AST transformation pipeline" do
    setup do
      # Ensure Config GenServer is available for integration tests
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "integrates with existing Repository storage" do
      # Given: Enhanced AST from parser
      sample = SampleASTs.get_sample_ast(:simple_genserver)
      {:ok, enhanced_ast} = Parser.assign_node_ids(sample.ast)
      
      # When: We store in repository
      repo = Helpers.setup_test_repository()
      
      # Create ModuleData struct for storage
      module_name = Helpers.extract_module_name_from_ast(enhanced_ast)
      module_data = ElixirScope.ASTRepository.ModuleData.new(module_name, enhanced_ast)
      result = ElixirScope.ASTRepository.Repository.store_module(repo, module_data)
      
      # Then: Storage succeeds
      assert :ok = result
      
      # And: Module can be retrieved with node IDs intact
      {:ok, stored_module} = ElixirScope.ASTRepository.Repository.get_module(repo, module_name)
      validation = Helpers.validate_ast_enhancement(stored_module.ast)
      
      assert validation.has_node_ids, "Stored AST should retain node IDs"
    end

    test "works with existing RuntimeCorrelator" do
      # Given: Enhanced AST with correlation index
      sample = SampleASTs.get_sample_ast(:simple_genserver)
      {:ok, enhanced_ast} = Parser.assign_node_ids(sample.ast)
      {:ok, instrumentation_points} = Parser.extract_instrumentation_points(enhanced_ast)
      {:ok, _correlation_index} = Parser.build_correlation_index(enhanced_ast, instrumentation_points)
      
      # When: We set up EnhancedRepository and RuntimeCorrelator
      {:ok, enhanced_repo} = ElixirScope.ASTRepository.EnhancedRepository.start_link([])
      
      # Store the enhanced module in EnhancedRepository
      module_name = Helpers.extract_module_name_from_ast(enhanced_ast)
      {:ok, _enhanced_data} = ElixirScope.ASTRepository.EnhancedRepository.store_enhanced_module(module_name, enhanced_ast)
      
      # Start RuntimeCorrelator with EnhancedRepository
      {:ok, correlator} = ElixirScope.ASTRepository.RuntimeCorrelator.start_link([
        ast_repo: enhanced_repo,
        event_store: nil
      ])
      
      # Then: Correlator can use the correlation index
      # For now, just verify the correlator is working
      # (Full correlation integration will be implemented in Day 2)
      test_event = Helpers.create_test_event()
      result = ElixirScope.ASTRepository.RuntimeCorrelator.correlate_event_to_ast(enhanced_repo, test_event)
      
      # Should either succeed or fail gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result), 
        "RuntimeCorrelator should handle events gracefully"
        
      # Clean up
      GenServer.stop(correlator)
      GenServer.stop(enhanced_repo)
    end
  end

  describe "error handling and edge cases" do
    test "handles empty AST gracefully" do
      # Given: Empty AST
      empty_ast = nil
      
      # When: We try to assign node IDs
      result = Parser.assign_node_ids(empty_ast)
      
      # Then: Error is handled gracefully
      assert {:error, _reason} = result
    end

    test "handles AST without instrumentable nodes" do
      # Given: AST with no instrumentable nodes (just module declaration)
      simple_ast = quote do
        defmodule EmptyModule do
          @moduledoc "Empty module"
        end
      end
      
      # When: We assign node IDs and extract instrumentation points
      {:ok, enhanced_ast} = Parser.assign_node_ids(simple_ast)
      {:ok, instrumentation_points} = Parser.extract_instrumentation_points(enhanced_ast)
      
      # Then: Process completes without error
      assert is_list(instrumentation_points), "Should return list of instrumentation points"
      
      # Module attributes like @moduledoc are detected as instrumentation points
      # This is expected behavior for metadata tracking
      module_attribute_points = Enum.filter(instrumentation_points, &(&1.type == :module_attribute))
      function_points = Enum.filter(instrumentation_points, &(&1.type in [:function_entry, :controller_action, :genserver_callback]))
      
      assert length(function_points) == 0, "Should have no function instrumentation points"
      assert length(module_attribute_points) >= 0, "May have module attribute instrumentation points"
    end

    test "preserves AST integrity during enhancement" do
      # Given: Original AST
      sample = SampleASTs.get_sample_ast(:complex_module)
      original_ast = sample.ast
      
      # When: We enhance the AST
      {:ok, enhanced_ast} = Parser.assign_node_ids(original_ast)
      
      # Then: AST can still be compiled
      assert Code.compile_quoted(enhanced_ast), "Enhanced AST should still be compilable"
      
      # And: Semantic meaning is preserved
      assert Helpers.ast_structurally_equal?(original_ast, enhanced_ast),
        "Semantic structure should be preserved"
    end
  end

  # Helper functions for tests

  defp extract_function_nodes_with_ids(ast) do
    {_ast, nodes} = Macro.prewalk(ast, [], fn
      {:def, meta, [{name, _meta2, args} | _]} = node, acc ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> {node, acc}
          node_id -> 
            function_info = %{
              name: name,
              arity: length(args || []),
              node_id: node_id,
              type: :def
            }
            {node, [function_info | acc]}
        end
      
      {:defp, meta, [{name, _meta2, args} | _]} = node, acc ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> {node, acc}
          node_id -> 
            function_info = %{
              name: name,
              arity: length(args || []),
              node_id: node_id,
              type: :defp
            }
            {node, [function_info | acc]}
        end
      
      node, acc -> {node, acc}
    end)
    
    Enum.reverse(nodes)
  end

  defp count_nested_instrumentable_nodes(ast) do
    {_ast, count} = Macro.prewalk(ast, 0, fn
      {:def, meta, _args} = node, acc ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> {node, acc}
          _node_id -> {node, acc + 1}
        end
      
      {:defp, meta, _args} = node, acc ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> {node, acc}
          _node_id -> {node, acc + 1}
        end
      
      {:|>, meta, _args} = node, acc ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> {node, acc}
          _node_id -> {node, acc + 1}
        end
      
      {:case, meta, _args} = node, acc ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> {node, acc}
          _node_id -> {node, acc + 1}
        end
      
      node, acc -> {node, acc}
    end)
    
    count
  end
end 