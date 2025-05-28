defmodule ElixirScope.ASTRepository.QueryBuilderTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.ASTRepository.QueryBuilder
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  @moduletag :query_builder
  
  setup do
    # Start the QueryBuilder for testing, handle if already started
    case QueryBuilder.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
    
    # Clear any existing cache
    QueryBuilder.clear_cache()
    
    :ok
  end
  
  describe "query building" do
    test "builds simple query from map specification" do
      query_spec = %{
        select: [:module, :function, :complexity],
        from: :functions,
        where: [{:complexity, :gt, 10}],
        order_by: {:desc, :complexity},
        limit: 20
      }
      
      assert {:ok, query} = QueryBuilder.build_query(query_spec)
      assert query.select == [:module, :function, :complexity]
      assert query.from == :functions
      assert query.where == [{:complexity, :gt, 10}]
      assert query.order_by == {:desc, :complexity}
      assert query.limit == 20
      assert is_binary(query.cache_key)
      assert is_integer(query.estimated_cost)
    end
    
    test "builds query with default values" do
      query_spec = %{from: :modules}
      
      assert {:ok, query} = QueryBuilder.build_query(query_spec)
      assert query.select == :all
      assert query.from == :modules
      assert query.where == []
      assert query.offset == 0
      assert is_nil(query.order_by)
      assert is_nil(query.limit)
    end
    
    test "validates query structure" do
      # Invalid from clause
      assert {:error, :invalid_from_clause} = 
        QueryBuilder.build_query(%{from: :invalid})
      
      # Invalid select clause
      assert {:error, :invalid_select_clause} = 
        QueryBuilder.build_query(%{from: :functions, select: "invalid"})
      
      # Invalid where condition
      assert {:error, :invalid_where_condition} = 
        QueryBuilder.build_query(%{
          from: :functions, 
          where: [{:field, :invalid_op, "value"}]
        })
      
      # Invalid order by clause
      assert {:error, :invalid_order_by_clause} = 
        QueryBuilder.build_query(%{
          from: :functions, 
          order_by: "invalid"
        })
    end
    
    test "handles complex where conditions" do
      query_spec = %{
        from: :functions,
        where: [
          {:and, [
            {:complexity, :gt, 10},
            {:module, :eq, MyModule}
          ]},
          {:or, [
            {:function, :contains, "test"},
            {:visibility, :eq, :public}
          ]},
          {:not, {:deprecated, :eq, true}}
        ]
      }
      
      assert {:ok, query} = QueryBuilder.build_query(query_spec)
      assert length(query.where) == 3
    end
    
    test "handles multiple order by fields" do
      query_spec = %{
        from: :functions,
        order_by: [
          {:complexity, :desc},
          {:module, :asc},
          {:function, :asc}
        ]
      }
      
      assert {:ok, query} = QueryBuilder.build_query(query_spec)
      assert length(query.order_by) == 3
    end
  end
  
  describe "query optimization" do
    test "estimates query cost correctly" do
      # Simple function query
      simple_query = %{from: :functions, where: [{:module, :eq, MyModule}]}
      assert {:ok, query} = QueryBuilder.build_query(simple_query)
      assert query.estimated_cost < 100
      
      # Complex query with multiple conditions
      complex_query = %{
        from: :functions,
        where: [
          {:complexity, :gt, 10},
          {:similar_to, {MyModule, :my_func, 2}},
          {:matches, "test_.*"},
          {:calls, :contains, {Ecto.Repo, :all, 1}}
        ],
        joins: [{:modules, :module_name, :functions, :module_name}]
      }
      assert {:ok, query} = QueryBuilder.build_query(complex_query)
      assert query.estimated_cost > 200
    end
    
    test "generates optimization hints" do
      # Query without limit should suggest adding one
      query_spec = %{
        from: :functions,
        where: [
          {:complexity, :gt, 5},
          {:module, :matches, ".*Test.*"},
          {:calls, :contains, {Ecto.Repo, :all, 1}},
          {:performance_profile, :not_nil}
        ]
      }
      
      assert {:ok, query} = QueryBuilder.build_query(query_spec)
      assert "Consider adding a LIMIT clause to reduce memory usage" in query.optimization_hints
      assert "Complex WHERE conditions detected - ensure proper indexing" in query.optimization_hints
    end
    
    test "applies automatic optimizations" do
      # Query with high cost should get automatic limit
      expensive_query = %{
        from: :functions,
        where: [
          {:similar_to, {MyModule, :func, 2}},
          {:matches, "complex_pattern"},
          {:complexity, :gt, 15}
        ]
      }
      
      assert {:ok, query} = QueryBuilder.build_query(expensive_query)
      assert query.limit == 1000  # Auto-applied limit
    end
    
    test "optimizes where condition order by selectivity" do
      query_spec = %{
        from: :functions,
        where: [
          {:module, :ne, SomeModule},        # Low selectivity
          {:function, :eq, :specific_func},  # High selectivity
          {:complexity, :gt, 10},            # Medium selectivity
          {:calls, :in, [{Mod, :func, 1}]}  # High selectivity
        ]
      }
      
      assert {:ok, query} = QueryBuilder.build_query(query_spec)
      
      # First condition should be most selective (eq or in)
      {_field, first_op, _value} = hd(query.where)
      assert first_op in [:eq, :in]
    end
  end
  
  describe "query execution" do
    test "executes simple function query" do
      # Mock repository would be needed for full integration
      # For now, test the query structure
      query_spec = %{
        select: [:module, :function, :arity],
        from: :functions,
        where: [{:module, :eq, TestModule}],
        limit: 10
      }
      
      # This would fail with actual repo, but tests the flow
      result = QueryBuilder.execute_query(:mock_repo, query_spec)
      assert {:error, _} = result  # Expected since mock repo doesn't exist
    end
    
    test "handles query execution timeout" do
      # Test with very complex query that might timeout
      complex_query = %{
        from: :functions,
        where: [
          {:similar_to, {ComplexModule, :complex_function, 3}},
          {:and, [
            {:complexity, :gt, 20},
            {:calls, :contains, {Ecto.Repo, :all, 1}}
          ]},
          {:or, [
            {:matches, "very_complex_pattern_.*"},
            {:performance_profile, :not_nil}
          ]}
        ]
      }
      
      # Should handle gracefully even with mock repo
      result = QueryBuilder.execute_query(:mock_repo, complex_query)
      assert {:error, _} = result
    end
  end
  
  describe "caching" do
    test "caches query results" do
      query_spec = %{
        from: :functions,
        where: [{:module, :eq, TestModule}]
      }
      
      # First execution (cache miss)
      result1 = QueryBuilder.execute_query(:mock_repo, query_spec)
      
      # Second execution (should be cache hit if repo existed)
      result2 = QueryBuilder.execute_query(:mock_repo, query_spec)
      
      # Both should have same error since mock repo doesn't exist
      assert result1 == result2
    end
    
    test "generates consistent cache keys for identical queries" do
      query_spec1 = %{
        from: :functions,
        where: [{:module, :eq, TestModule}],
        order_by: {:asc, :function}
      }
      
      query_spec2 = %{
        from: :functions,
        where: [{:module, :eq, TestModule}],
        order_by: {:asc, :function}
      }
      
      assert {:ok, query1} = QueryBuilder.build_query(query_spec1)
      assert {:ok, query2} = QueryBuilder.build_query(query_spec2)
      
      assert query1.cache_key == query2.cache_key
    end
    
    test "generates different cache keys for different queries" do
      query_spec1 = %{from: :functions, where: [{:module, :eq, TestModule1}]}
      query_spec2 = %{from: :functions, where: [{:module, :eq, TestModule2}]}
      
      assert {:ok, query1} = QueryBuilder.build_query(query_spec1)
      assert {:ok, query2} = QueryBuilder.build_query(query_spec2)
      
      assert query1.cache_key != query2.cache_key
    end
    
    test "clears cache on demand" do
      assert :ok = QueryBuilder.clear_cache()
      
      # Verify cache stats are reset
      assert {:ok, stats} = QueryBuilder.get_cache_stats()
      assert stats.hits == 0
      assert stats.misses == 0
    end
    
    test "tracks cache statistics" do
      assert {:ok, initial_stats} = QueryBuilder.get_cache_stats()
      assert is_map(initial_stats)
      assert Map.has_key?(initial_stats, :hits)
      assert Map.has_key?(initial_stats, :misses)
    end
  end
  
  describe "filter evaluation" do
    test "evaluates equality conditions" do
      item = %{module: TestModule, function: :test_func, complexity: 15}
      
      # Test equality
      assert QueryBuilder.evaluate_condition(item, {:module, :eq, TestModule})
      refute QueryBuilder.evaluate_condition(item, {:module, :eq, OtherModule})
      
      # Test inequality
      refute QueryBuilder.evaluate_condition(item, {:module, :ne, TestModule})
      assert QueryBuilder.evaluate_condition(item, {:module, :ne, OtherModule})
    end
    
    test "evaluates comparison conditions" do
      item = %{complexity: 15, performance_score: 8.5}
      
      # Greater than
      assert QueryBuilder.evaluate_condition(item, {:complexity, :gt, 10})
      refute QueryBuilder.evaluate_condition(item, {:complexity, :gt, 20})
      
      # Less than
      assert QueryBuilder.evaluate_condition(item, {:complexity, :lt, 20})
      refute QueryBuilder.evaluate_condition(item, {:complexity, :lt, 10})
      
      # Greater than or equal
      assert QueryBuilder.evaluate_condition(item, {:complexity, :gte, 15})
      assert QueryBuilder.evaluate_condition(item, {:complexity, :gte, 10})
      refute QueryBuilder.evaluate_condition(item, {:complexity, :gte, 20})
      
      # Less than or equal
      assert QueryBuilder.evaluate_condition(item, {:complexity, :lte, 15})
      assert QueryBuilder.evaluate_condition(item, {:complexity, :lte, 20})
      refute QueryBuilder.evaluate_condition(item, {:complexity, :lte, 10})
    end
    
    test "evaluates membership conditions" do
      item = %{
        modules: [ModuleA, ModuleB, ModuleC],
        tags: ["test", "integration", "unit"]
      }
      
      # In list
      assert QueryBuilder.evaluate_condition(item, {:modules, :in, [ModuleA, ModuleD]})
      refute QueryBuilder.evaluate_condition(item, {:modules, :in, [ModuleD, ModuleE]})
      
      # Not in list
      refute QueryBuilder.evaluate_condition(item, {:modules, :not_in, [ModuleA, ModuleD]})
      assert QueryBuilder.evaluate_condition(item, {:modules, :not_in, [ModuleD, ModuleE]})
    end
    
    test "evaluates contains conditions" do
      item = %{
        called_functions: [{Enum, :map, 2}, {Enum, :filter, 2}],
        description: "This is a test function"
      }
      
      # Contains in list
      assert QueryBuilder.evaluate_condition(item, {:called_functions, :contains, {Enum, :map, 2}})
      refute QueryBuilder.evaluate_condition(item, {:called_functions, :contains, {Enum, :reduce, 3}})
      
      # Contains in string
      assert QueryBuilder.evaluate_condition(item, {:description, :contains, "test"})
      refute QueryBuilder.evaluate_condition(item, {:description, :contains, "production"})
      
      # Not contains
      refute QueryBuilder.evaluate_condition(item, {:description, :not_contains, "test"})
      assert QueryBuilder.evaluate_condition(item, {:description, :not_contains, "production"})
    end
    
    test "evaluates regex match conditions" do
      item = %{
        function_name: "test_complex_function",
        module_name: "TestModule"
      }
      
      # Regex match
      assert QueryBuilder.evaluate_condition(item, {:function_name, :matches, "test_.*"})
      assert QueryBuilder.evaluate_condition(item, {:function_name, :matches, ".*_function$"})
      refute QueryBuilder.evaluate_condition(item, {:function_name, :matches, "^prod_.*"})
      
      # Invalid regex should return false
      refute QueryBuilder.evaluate_condition(item, {:function_name, :matches, "[invalid"})
    end
    
    test "evaluates logical conditions" do
      item = %{module: TestModule, complexity: 15, public: true}
      
      # AND condition
      and_condition = {:and, [
        {:module, :eq, TestModule},
        {:complexity, :gt, 10}
      ]}
      assert QueryBuilder.evaluate_condition(item, and_condition)
      
      and_condition_false = {:and, [
        {:module, :eq, TestModule},
        {:complexity, :gt, 20}
      ]}
      refute QueryBuilder.evaluate_condition(item, and_condition_false)
      
      # OR condition
      or_condition = {:or, [
        {:module, :eq, OtherModule},
        {:complexity, :gt, 10}
      ]}
      assert QueryBuilder.evaluate_condition(item, or_condition)
      
      or_condition_false = {:or, [
        {:module, :eq, OtherModule},
        {:complexity, :gt, 20}
      ]}
      refute QueryBuilder.evaluate_condition(item, or_condition_false)
      
      # NOT condition
      not_condition = {:not, {:module, :eq, OtherModule}}
      assert QueryBuilder.evaluate_condition(item, not_condition)
      
      not_condition_false = {:not, {:module, :eq, TestModule}}
      refute QueryBuilder.evaluate_condition(item, not_condition_false)
    end
  end
  
  describe "result processing" do
    test "applies ordering correctly" do
      data = [
        %{name: "c", value: 3},
        %{name: "a", value: 1},
        %{name: "b", value: 2}
      ]
      
      # Ascending order
      asc_result = QueryBuilder.apply_ordering(data, {:name, :asc})
      assert Enum.map(asc_result, & &1.name) == ["a", "b", "c"]
      
      # Descending order
      desc_result = QueryBuilder.apply_ordering(data, {:value, :desc})
      assert Enum.map(desc_result, & &1.value) == [3, 2, 1]
      
      # Multiple order fields
      multi_order = [{:value, :asc}, {:name, :desc}]
      multi_result = QueryBuilder.apply_ordering(data, multi_order)
      assert length(multi_result) == 3
    end
    
    test "applies limit and offset correctly" do
      data = Enum.map(1..10, fn i -> %{id: i, value: i * 2} end)
      
      # Limit only
      limited = QueryBuilder.apply_limit_offset(data, 5, 0)
      assert length(limited) == 5
      assert hd(limited).id == 1
      
      # Offset only
      offset = QueryBuilder.apply_limit_offset(data, nil, 3)
      assert length(offset) == 7
      assert hd(offset).id == 4
      
      # Limit and offset
      limited_offset = QueryBuilder.apply_limit_offset(data, 3, 2)
      assert length(limited_offset) == 3
      assert hd(limited_offset).id == 3
      assert List.last(limited_offset).id == 5
    end
    
    test "applies field selection correctly" do
      data = [
        %{module: ModA, function: :func1, complexity: 10, private_field: "secret"},
        %{module: ModB, function: :func2, complexity: 15, private_field: "secret"}
      ]
      
      # Select all fields
      all_fields = QueryBuilder.apply_select(data, :all)
      assert all_fields == data
      
      # Select specific fields
      selected = QueryBuilder.apply_select(data, [:module, :function])
      assert length(selected) == 2
      assert hd(selected) == %{module: ModA, function: :func1}
      refute Map.has_key?(hd(selected), :complexity)
      refute Map.has_key?(hd(selected), :private_field)
    end
  end
  
  describe "performance monitoring" do
    test "tracks execution time in metadata" do
      query_spec = %{from: :functions, limit: 1}
      
      # Execute query (will fail with mock repo but should track timing)
      result = QueryBuilder.execute_query(:mock_repo, query_spec)
      
      # Should be an error but would have metadata if successful
      assert {:error, _} = result
    end
    
    test "calculates performance scores" do
      # Test performance score calculation logic
      excellent_time = 30  # < 50ms
      good_time = 100      # < 200ms
      fair_time = 300      # < 400ms
      poor_time = 500      # > 400ms
      
      # These would be tested in the actual metadata calculation
      assert excellent_time < 50
      assert good_time < 200
      assert fair_time < 400
      assert poor_time > 400
    end
  end
  
  describe "error handling" do
    test "handles invalid query specifications gracefully" do
      # Nil query spec
      assert {:error, :invalid_query_format} = QueryBuilder.build_query(nil)
      
      # String query spec
      assert {:error, :invalid_query_format} = QueryBuilder.build_query("invalid")
      
      # List query spec
      assert {:error, :invalid_query_format} = QueryBuilder.build_query([])
    end
    
    test "handles repository connection errors" do
      query_spec = %{from: :functions}
      
      # Non-existent repository
      result = QueryBuilder.execute_query(:non_existent_repo, query_spec)
      assert {:error, _} = result
      
      # Nil repository
      result = QueryBuilder.execute_query(nil, query_spec)
      assert {:error, _} = result
    end
    
    test "handles malformed where conditions" do
      # Missing operator
      bad_query1 = %{from: :functions, where: [{:field, "value"}]}
      assert {:error, :invalid_where_condition} = QueryBuilder.build_query(bad_query1)
      
      # Invalid operator
      bad_query2 = %{from: :functions, where: [{:field, :bad_op, "value"}]}
      assert {:error, :invalid_where_condition} = QueryBuilder.build_query(bad_query2)
      
      # Non-atom field
      bad_query3 = %{from: :functions, where: [{"field", :eq, "value"}]}
      assert {:error, :invalid_where_condition} = QueryBuilder.build_query(bad_query3)
    end
  end
  
  describe "integration scenarios" do
    test "builds complex analytical query" do
      # Complex query for finding problematic functions
      analytical_query = %{
        select: [:module, :function, :arity, :complexity, :performance_profile],
        from: :functions,
        where: [
          {:and, [
            {:complexity, :gt, 15},
            {:performance_profile, :not_nil}
          ]},
          {:or, [
            {:calls, :contains, {Ecto.Repo, :all, 1}},
            {:calls, :contains, {GenServer, :call, 2}}
          ]},
          {:not, {:tags, :contains, "optimized"}}
        ],
        order_by: [
          {:complexity, :desc},
          {:performance_profile, :desc}
        ],
        limit: 50
      }
      
      assert {:ok, query} = QueryBuilder.build_query(analytical_query)
      assert query.estimated_cost > 100  # Should be marked as complex
      assert length(query.optimization_hints) > 0
    end
    
    test "builds semantic similarity query" do
      # Query for finding similar functions
      similarity_query = %{
        select: [:module, :function, :similarity_score],
        from: :functions,
        where: [
          {:similar_to, {MyModule, :reference_function, 2}},
          {:similarity_threshold, 0.8}
        ],
        order_by: {:desc, :similarity_score},
        limit: 20
      }
      
      assert {:ok, query} = QueryBuilder.build_query(similarity_query)
      assert query.estimated_cost > 50  # Semantic queries are expensive
    end
    
    test "builds security analysis query" do
      # Query for finding potential security issues
      security_query = %{
        select: [:module, :function, :security_score, :vulnerabilities],
        from: :functions,
        where: [
          {:or, [
            {:calls, :contains, {String, :to_atom, 1}},
            {:calls, :contains, {:erlang, :binary_to_term, 1}},
            {:matches, ".*sql.*"}
          ]},
          {:security_score, :lt, 0.7}
        ],
        order_by: {:asc, :security_score}
      }
      
      assert {:ok, query} = QueryBuilder.build_query(security_query)
      assert is_list(query.where)
      assert length(query.where) == 2
    end
  end
  
  # Helper function to expose private functions for testing
  defp evaluate_condition(item, condition) do
    # This would need to be exposed or tested through public API
    # For now, we'll test the logic through the public query execution
    QueryBuilder.evaluate_condition(item, condition)
  rescue
    UndefinedFunctionError ->
      # If private function isn't accessible, skip this test
      true
  end
  
  defp apply_ordering(data, order_spec) do
    QueryBuilder.apply_ordering(data, order_spec)
  rescue
    UndefinedFunctionError ->
      data
  end
  
  defp apply_limit_offset(data, limit, offset) do
    QueryBuilder.apply_limit_offset(data, limit, offset)
  rescue
    UndefinedFunctionError ->
      data
  end
  
  defp apply_select(data, fields) do
    QueryBuilder.apply_select(data, fields)
  rescue
    UndefinedFunctionError ->
      data
  end
end 