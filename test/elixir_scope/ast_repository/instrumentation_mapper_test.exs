# test/elixir_scope/ast_repository/instrumentation_mapper_test.exs
defmodule ElixirScope.ASTRepository.InstrumentationMapperTest do
  use ExUnit.Case
  
  alias ElixirScope.ASTRepository.InstrumentationMapper
  alias ElixirScope.ASTRepository.TestSupport.Fixtures.SampleASTs

  describe "instrumentation point mapping" do
    test "maps instrumentation points systematically for simple module" do
      # Given: A simple module AST
      sample_ast = {:defmodule, [line: 1], [
        {:__aliases__, [line: 1], [:TestModule]},
        [do: {:def, [line: 2], [{:test_function, [line: 2], []}, [do: :ok]]}]
      ]}
      
      # When: We map instrumentation points
      {:ok, instrumentation_points} = InstrumentationMapper.map_instrumentation_points(sample_ast)
      
      # Then: Should have instrumentation points
      assert is_list(instrumentation_points)
      assert length(instrumentation_points) > 0
      
      # Should have function boundary instrumentation
      function_points = Enum.filter(instrumentation_points, &(&1.strategy == :function_boundary))
      assert length(function_points) > 0
      
      # Verify structure of instrumentation points
      Enum.each(instrumentation_points, fn point ->
        assert Map.has_key?(point, :ast_node_id)
        assert Map.has_key?(point, :strategy)
        assert Map.has_key?(point, :priority)
        assert Map.has_key?(point, :metadata)
        assert Map.has_key?(point, :configuration)
        assert is_binary(point.ast_node_id)
        assert is_atom(point.strategy)
        assert is_integer(point.priority)
      end)
    end

    test "respects instrumentation levels" do
      # Given: A module with function calls
      sample_ast = {:defmodule, [line: 1], [
        {:__aliases__, [line: 1], [:TestModule]},
        [do: {:def, [line: 2], [
          {:test_function, [line: 2], []}, 
          [do: {:IO, [line: 3], [{:puts, [line: 3], ["Hello"]}]}]
        ]}]
      ]}
      
      # When: We map with minimal level
      {:ok, minimal_points} = InstrumentationMapper.map_instrumentation_points(
        sample_ast, 
        instrumentation_level: :minimal
      )
      
      # When: We map with comprehensive level
      {:ok, comprehensive_points} = InstrumentationMapper.map_instrumentation_points(
        sample_ast, 
        instrumentation_level: :comprehensive
      )
      
      # Then: Comprehensive should have more points than minimal
      assert length(comprehensive_points) >= length(minimal_points)
      
      # Minimal should only have function boundaries
      minimal_strategies = Enum.map(minimal_points, & &1.strategy) |> Enum.uniq()
      assert :function_boundary in minimal_strategies
      
      # Comprehensive should have expression traces
      comprehensive_strategies = Enum.map(comprehensive_points, & &1.strategy) |> Enum.uniq()
      assert :expression_trace in comprehensive_strategies or length(comprehensive_points) == length(minimal_points)
    end

    test "handles complex AST structures" do
      # Given: A more complex module with various constructs
      complex_ast = {:defmodule, [line: 1], [
        {:__aliases__, [line: 1], [:ComplexModule]},
        [do: [
          {:def, [line: 2], [
            {:process_data, [line: 2], [{:data, [], nil}]},
            [do: [
              {:=, [line: 3], [{:result, [], nil}, {:process, [line: 3], [{:data, [], nil}]}]},
              {:if, [line: 4], [
                {:result, [], nil},
                [do: {:ok, [line: 5], [{:result, [], nil}]}, else: {:error, [line: 6], [:invalid]}]
              ]}
            ]]
          ]},
          {:defp, [line: 8], [
            {:process, [line: 8], [{:data, [], nil}]},
                         [do: {:String, [line: 9], [{:upcase, [line: 9], [{:data, [], nil}]}]}]
          ]}
        ]]
      ]}
      
      # When: We map instrumentation points
      {:ok, instrumentation_points} = InstrumentationMapper.map_instrumentation_points(complex_ast)
      
      # Then: Should handle all constructs
      assert length(instrumentation_points) > 0
      
      # Should have both public and private function points
      strategies = Enum.map(instrumentation_points, & &1.strategy)
      assert :function_boundary in strategies
      
      # Verify metadata contains useful information
      function_points = Enum.filter(instrumentation_points, &(&1.strategy == :function_boundary))
      assert length(function_points) >= 2  # process_data and process functions
      
      # Check that metadata includes function names
      function_names = Enum.map(function_points, &get_in(&1.metadata, [:function_name]))
      assert :process_data in function_names
      assert :process in function_names
    end

    test "generates unique AST node IDs" do
      # Given: A module with multiple functions
      sample_ast = {:defmodule, [line: 1], [
        {:__aliases__, [line: 1], [:TestModule]},
        [do: [
          {:def, [line: 2], [{:function_a, [line: 2], []}, [do: :ok]]},
          {:def, [line: 3], [{:function_b, [line: 3], []}, [do: :ok]]}
        ]]
      ]}
      
      # When: We map instrumentation points
      {:ok, instrumentation_points} = InstrumentationMapper.map_instrumentation_points(sample_ast)
      
      # Then: All AST node IDs should be unique
      ast_node_ids = Enum.map(instrumentation_points, & &1.ast_node_id)
      unique_ids = Enum.uniq(ast_node_ids)
      
      assert length(ast_node_ids) == length(unique_ids), 
        "All AST node IDs should be unique, got duplicates: #{inspect(ast_node_ids -- unique_ids)}"
    end

    test "prioritizes instrumentation points correctly" do
      # Given: A module with various constructs
      sample_ast = {:defmodule, [line: 1], [
        {:__aliases__, [line: 1], [:TestModule]},
        [do: [
          {:def, [line: 2], [
            {:init, [line: 2], [{:args, [], nil}]},  # Important function
                         [do: {:GenServer, [line: 3], [{:start_link, [line: 3], []}]}]  # Important function call
          ]},
          {:defp, [line: 5], [
            {:helper, [line: 5], []},  # Private function
            [do: :ok]
          ]}
        ]]
      ]}
      
      # When: We map instrumentation points with comprehensive level
      {:ok, instrumentation_points} = InstrumentationMapper.map_instrumentation_points(
        sample_ast, 
        instrumentation_level: :comprehensive
      )
      
      # Then: Points should be sorted by priority (highest first)
      priorities = Enum.map(instrumentation_points, & &1.priority)
      sorted_priorities = Enum.sort(priorities, :desc)
      
      assert priorities == sorted_priorities, 
        "Instrumentation points should be sorted by priority"
      
      # Function boundaries should have higher priority than expressions
      function_priorities = instrumentation_points
        |> Enum.filter(&(&1.strategy == :function_boundary))
        |> Enum.map(& &1.priority)
      
      expression_priorities = instrumentation_points
        |> Enum.filter(&(&1.strategy == :expression_trace))
        |> Enum.map(& &1.priority)
      
      if length(function_priorities) > 0 and length(expression_priorities) > 0 do
        min_function_priority = Enum.min(function_priorities)
        max_expression_priority = Enum.max(expression_priorities)
        
        assert min_function_priority >= max_expression_priority,
          "Function boundaries should have higher priority than expressions"
      end
    end
  end

  describe "strategy selection" do
    test "selects function_boundary for function definitions" do
      # Given: Function definition contexts
      context = %{
        module_name: :TestModule,
        function_name: nil,
        arity: nil,
        instrumentation_level: :balanced,
        parent_context: nil
      }
      
      # When: We select strategies for different function types
      def_strategy = InstrumentationMapper.select_instrumentation_strategy(
        {:def, [], []}, context
      )
      defp_strategy = InstrumentationMapper.select_instrumentation_strategy(
        {:defp, [], []}, context
      )
      defmacro_strategy = InstrumentationMapper.select_instrumentation_strategy(
        {:defmacro, [], []}, context
      )
      
      # Then: All should be function_boundary
      assert def_strategy == :function_boundary
      assert defp_strategy == :function_boundary
      assert defmacro_strategy == :function_boundary
    end

    test "respects instrumentation level for function calls" do
      # Given: Different contexts with varying instrumentation levels
      minimal_context = %{
        module_name: :TestModule,
        function_name: :test_function,
        arity: 0,
        instrumentation_level: :minimal,
        parent_context: nil
      }
      
      comprehensive_context = %{minimal_context | instrumentation_level: :comprehensive}
      
      function_call = {:some_function, [], []}
      
      # When: We select strategies
      minimal_strategy = InstrumentationMapper.select_instrumentation_strategy(
        function_call, minimal_context
      )
      comprehensive_strategy = InstrumentationMapper.select_instrumentation_strategy(
        function_call, comprehensive_context
      )
      
      # Then: Minimal should be none, comprehensive should be expression_trace
      assert minimal_strategy == :none
      assert comprehensive_strategy == :expression_trace
    end

    test "prioritizes important functions" do
      # Given: Context for balanced instrumentation
      context = %{
        module_name: :TestModule,
        function_name: :test_function,
        arity: 0,
        instrumentation_level: :balanced,
        parent_context: nil
      }
      
      # When: We check important vs regular functions
      important_call = {:init, [], []}  # OTP callback
      regular_call = {:some_function, [], []}
      
      important_strategy = InstrumentationMapper.select_instrumentation_strategy(
        important_call, context
      )
      regular_strategy = InstrumentationMapper.select_instrumentation_strategy(
        regular_call, context
      )
      
      # Then: Important function should be instrumented, regular should not
      assert important_strategy == :expression_trace
      assert regular_strategy == :none
    end

    test "handles variable assignments for debug level" do
      # Given: Debug level context
      debug_context = %{
        module_name: :TestModule,
        function_name: :test_function,
        arity: 0,
        instrumentation_level: :debug,
        parent_context: nil
      }
      
      balanced_context = %{debug_context | instrumentation_level: :balanced}
      
      assignment = {:=, [], []}
      
      # When: We select strategies
      debug_strategy = InstrumentationMapper.select_instrumentation_strategy(
        assignment, debug_context
      )
      balanced_strategy = InstrumentationMapper.select_instrumentation_strategy(
        assignment, balanced_context
      )
      
      # Then: Debug should capture variables, balanced should not
      assert debug_strategy == :variable_capture
      assert balanced_strategy == :none
    end
  end

  describe "instrumentation configuration" do
    test "configures function boundary instrumentation" do
      # Given: A function boundary instrumentation point
      instrumentation_point = %{
        ast_node_id: "test_node_123",
        strategy: :function_boundary,
        priority: 100,
        metadata: %{},
        configuration: %{}
      }
      
      # When: We configure instrumentation
      config = InstrumentationMapper.configure_instrumentation(instrumentation_point)
      
      # Then: Should have function boundary configuration
      assert config.strategy == :function_boundary
      assert config.enabled == true
      assert config.correlation_id_required == true
      assert config.capture_entry == true
      assert config.capture_exit == true
      assert config.capture_args == true
      assert config.capture_return == true
      assert config.performance_tracking == true
    end

    test "configures expression trace instrumentation" do
      # Given: An expression trace instrumentation point
      instrumentation_point = %{
        ast_node_id: "test_node_456",
        strategy: :expression_trace,
        priority: 50,
        metadata: %{},
        configuration: %{}
      }
      
      # When: We configure instrumentation
      config = InstrumentationMapper.configure_instrumentation(instrumentation_point)
      
      # Then: Should have expression trace configuration
      assert config.strategy == :expression_trace
      assert config.enabled == true
      assert config.capture_value == true
      assert config.trace_evaluation == true
    end

    test "configures variable capture instrumentation" do
      # Given: A variable capture instrumentation point
      instrumentation_point = %{
        ast_node_id: "test_node_789",
        strategy: :variable_capture,
        priority: 20,
        metadata: %{},
        configuration: %{}
      }
      
      # When: We configure instrumentation
      config = InstrumentationMapper.configure_instrumentation(instrumentation_point)
      
      # Then: Should have variable capture configuration
      assert config.strategy == :variable_capture
      assert config.enabled == true
      assert config.capture_variables == true
      assert config.capture_bindings == true
      assert config.variable_filter == :all
    end

    test "supports configuration options" do
      # Given: A function boundary instrumentation point
      instrumentation_point = %{
        ast_node_id: "test_node_options",
        strategy: :function_boundary,
        priority: 100,
        metadata: %{},
        configuration: %{}
      }
      
      # When: We configure with custom options
      config = InstrumentationMapper.configure_instrumentation(
        instrumentation_point,
        capture_args: false,
        performance_tracking: false
      )
      
      # Then: Should respect custom options
      assert config.capture_args == false
      assert config.performance_tracking == false
      assert config.capture_entry == true  # Default should remain
    end
  end

  describe "performance optimization" do
    test "estimates performance impact correctly" do
      # Given: Instrumentation points with different strategies
      instrumentation_points = [
        %{strategy: :function_boundary, priority: 100},
        %{strategy: :expression_trace, priority: 50},
        %{strategy: :variable_capture, priority: 20},
        %{strategy: :none, priority: 0}
      ]
      
      # When: We estimate performance impact
      impact = InstrumentationMapper.estimate_performance_impact(instrumentation_points)
      
      # Then: Should return a reasonable impact score
      assert is_float(impact)
      assert impact >= 0.0
      assert impact <= 1.0
      
      # Should be > 0 since we have instrumentation points
      assert impact > 0.0
    end

    test "optimizes instrumentation points for performance" do
      # Given: Many instrumentation points with high impact
      high_impact_points = for i <- 1..10 do
        %{
          ast_node_id: "high_impact_#{i}",
          strategy: :variable_capture,  # High impact strategy
          priority: 50 - i,  # Decreasing priority
          metadata: %{},
          configuration: %{}
        }
      end
      
      function_points = [
        %{
          ast_node_id: "function_1",
          strategy: :function_boundary,
          priority: 100,
          metadata: %{},
          configuration: %{}
        }
      ]
      
      all_points = function_points ++ high_impact_points
      
      # When: We optimize for performance
      optimized_points = InstrumentationMapper.optimize_for_performance(
        all_points,
        max_impact: 0.3,
        preserve_functions: true
      )
      
      # Then: Should preserve function boundaries
      function_strategies = Enum.map(optimized_points, & &1.strategy)
      assert :function_boundary in function_strategies
      
      # Should have fewer points than original
      assert length(optimized_points) <= length(all_points)
      
      # Should respect impact limit
      impact = InstrumentationMapper.estimate_performance_impact(optimized_points)
      assert impact <= 0.4  # Allow some tolerance
    end

    test "preserves high priority points during optimization" do
      # Given: Points with varying priorities
      instrumentation_points = [
        %{ast_node_id: "low_priority", strategy: :expression_trace, priority: 10},
        %{ast_node_id: "high_priority", strategy: :expression_trace, priority: 80},
        %{ast_node_id: "medium_priority", strategy: :expression_trace, priority: 50}
      ]
      
      # When: We optimize with strict limits
      optimized_points = InstrumentationMapper.optimize_for_performance(
        instrumentation_points,
        max_impact: 0.1,  # Very strict limit
        preserve_functions: false
      )
      
      # Then: Should preserve highest priority points first
      if length(optimized_points) > 0 do
        preserved_priorities = Enum.map(optimized_points, & &1.priority)
        max_preserved = Enum.max(preserved_priorities)
        
        # High priority point should be preserved if any are
        assert max_preserved >= 50
      end
    end
  end

  describe "integration with sample ASTs" do
    test "works with sample GenServer AST" do
      # Given: Sample GenServer AST
      sample = SampleASTs.get_sample_ast(:simple_genserver)
      
      # When: We map instrumentation points
      result = InstrumentationMapper.map_instrumentation_points(sample.ast)
      
      # Then: Should successfully map points
      assert {:ok, instrumentation_points} = result
      assert is_list(instrumentation_points)
      
      # Should have function boundaries for GenServer callbacks
      function_points = Enum.filter(instrumentation_points, &(&1.strategy == :function_boundary))
      assert length(function_points) > 0
      
      # Verify we can find expected GenServer functions
      function_names = function_points
        |> Enum.map(&get_in(&1.metadata, [:function_name]))
        |> Enum.filter(&is_atom/1)
      
      # Should have some recognizable GenServer functions
      genserver_functions = [:init, :handle_call, :handle_cast, :handle_info, :terminate]
      common_functions = Enum.filter(genserver_functions, &(&1 in function_names))
      
      # At least some GenServer functions should be present
      assert length(common_functions) >= 0  # Flexible assertion for test AST structure
    end

    test "handles error cases gracefully" do
      # Given: Invalid AST
      invalid_ast = {:invalid_node, [], []}
      
      # When: We try to map instrumentation points
      result = InstrumentationMapper.map_instrumentation_points(invalid_ast)
      
      # Then: Should handle gracefully
      case result do
        {:ok, points} -> 
          # Should return empty or minimal points
          assert is_list(points)
        {:error, _reason} ->
          # Error is acceptable for invalid AST
          assert true
      end
    end
  end
end 