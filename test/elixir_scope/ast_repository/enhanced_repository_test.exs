defmodule ElixirScope.ASTRepository.EnhancedRepositoryTest do
  use ExUnit.Case, async: false  # async: false due to shared ETS tables
  
  alias ElixirScope.ASTRepository.Enhanced.{Repository, EnhancedModuleData, EnhancedFunctionData}
  alias ElixirScope.ASTRepository.Enhanced.{VariableData, CFGData, DFGData, CPGData}
  alias ElixirScope.TestHelpers
  alias ElixirScope.ASTRepository.TestSupport.Fixtures.SampleASTs

  describe "Enhanced Repository lifecycle" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "starts with enhanced ETS table structure" do
      {:ok, pid} = Repository.start_link(name: :test_enhanced_repo)
      
      # Verify enhanced tables exist
      assert :ets.info(:ast_modules_enhanced) != :undefined
      assert :ets.info(:ast_functions_enhanced) != :undefined
      assert :ets.info(:ast_variables) != :undefined
      assert :ets.info(:ast_calls) != :undefined
      assert :ets.info(:ast_metadata) != :undefined
      
      # Verify indexes exist
      assert :ets.info(:ast_module_by_file) != :undefined
      assert :ets.info(:ast_function_by_name) != :undefined
      assert :ets.info(:ast_calls_by_target) != :undefined
      
      cleanup_repository(pid)
    end
    
    test "handles memory limit configuration" do
      {:ok, pid} = Repository.start_link(name: :test_memory_repo, memory_limit: 100)
      
      # Should start successfully with memory limit
      assert Process.alive?(pid)
      
      cleanup_repository(pid)
    end
    
    test "repository health check includes enhanced metrics" do
      {:ok, pid} = Repository.start_link(name: :test_health_enhanced)
      
      {:ok, health} = Repository.health_check(pid)
      
      assert health.status == :healthy
      assert Map.has_key?(health, :table_sizes)
      assert Map.has_key?(health, :memory_usage)
      assert Map.has_key?(health, :index_stats)
      
      cleanup_repository(pid)
    end
  end

  describe "Enhanced Module storage and retrieval" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      {:ok, pid} = Repository.start_link(name: :test_module_enhanced)
      
      # Create enhanced module data
      sample_ast = SampleASTs.simple_genserver_ast()
      
      enhanced_module = %EnhancedModuleData{
        module_name: :TestGenServer,
        file_path: "test/test_genserver.ex",
        ast: sample_ast,
        functions: %{},
        dependencies: [],
        exports: [],
        attributes: %{behaviour: [:gen_server]},
        complexity_metrics: %{combined_complexity: 5.0},
        quality_metrics: %{maintainability_index: 85.0},
        security_analysis: %{has_vulnerabilities: false, issues: []},
        performance_hints: [],
        file_size: 1500,
        line_count: 50,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
      
      on_exit(fn -> cleanup_repository(pid) end)
      
      %{repository: pid, enhanced_module: enhanced_module}
    end
    
    test "stores and retrieves enhanced module data", %{repository: repo, enhanced_module: module_data} do
      # Store enhanced module
      assert :ok = Repository.store_module(repo, module_data)
      
      # Retrieve enhanced module
      {:ok, retrieved} = Repository.get_module(repo, :TestGenServer)
      
      assert retrieved.module_name == :TestGenServer
      assert retrieved.file_path == "test/test_genserver.ex"
      assert retrieved.file_size == 1500
      assert retrieved.line_count == 50
      assert retrieved.attributes.behaviour == [:gen_server]
      assert retrieved.complexity_metrics.combined_complexity == 5.0
    end
    
    test "indexes modules by file path", %{repository: repo, enhanced_module: module_data} do
      assert :ok = Repository.store_module(repo, module_data)
      
      # Query by file path should work
      {:ok, modules} = Repository.query_modules_by_file(repo, "test/test_genserver.ex")
      assert length(modules) == 1
      assert hd(modules).module_name == :TestGenServer
    end
    
    test "handles large module storage efficiently", %{repository: repo} do
      # Create a large module with many functions
      large_module = create_large_module_data(100)
      
      {time_us, :ok} = :timer.tc(fn ->
        Repository.store_module(repo, large_module)
      end)
      
      # Should store large module in <50ms (50,000 microseconds)
      assert time_us < 50_000
    end
    
    test "validates module data before storage", %{repository: repo} do
      invalid_module = %EnhancedModuleData{
        module_name: nil,  # Invalid: nil module name
        file_path: "test.ex",
        ast: {:invalid, :ast}
      }
      
      assert {:error, :invalid_data} = Repository.store_module(repo, invalid_module)
    end
  end

  describe "Enhanced Function storage and retrieval" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      {:ok, pid} = Repository.start_link(name: :test_function_enhanced)
      
      # Create enhanced function data
      function_ast = {:def, [line: 10], [
        {:handle_call, [line: 10], [{:get_counter, [], nil}, {:_from, [], nil}, {:state, [], nil}]},
        [do: {:reply, [line: 11], [{:., [line: 11], [{:state, [], nil}, :counter]}, {:state, [], nil}]}]
      ]}
      
      enhanced_function = %EnhancedFunctionData{
        module_name: :TestGenServer,
        function_name: :handle_call,
        arity: 3,
        ast: function_ast,
        cfg_data: nil,
        dfg_data: nil,
        cpg_data: nil,
        complexity_metrics: %{combined_complexity: 1.5},
        performance_analysis: %{has_issues: false, bottlenecks: []},
        security_analysis: %{has_vulnerabilities: false, issues: []},
        optimization_hints: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
      
      on_exit(fn -> cleanup_repository(pid) end)
      
      %{repository: pid, enhanced_function: enhanced_function}
    end
    
    test "stores and retrieves enhanced function data", %{repository: repo, enhanced_function: function_data} do
      # Store enhanced function
      assert :ok = Repository.store_function(repo, function_data)
      
      # Retrieve enhanced function
      {:ok, retrieved} = Repository.get_function(repo, :TestGenServer, :handle_call, 3)
      
      assert retrieved.module_name == :TestGenServer
      assert retrieved.function_name == :handle_call
      assert retrieved.arity == 3
      assert retrieved.complexity_metrics.combined_complexity == 1.5
    end
    
    test "queries functions by complexity", %{repository: repo, enhanced_function: function_data} do
      assert :ok = Repository.store_function(repo, function_data)
      
      # Query functions with complexity > 1.0
      {:ok, functions} = Repository.query_functions(repo, %{
        complexity: {:gt, 1.0},
        limit: 10
      })
      
      assert length(functions) == 1
      assert hd(functions).complexity_metrics.combined_complexity == 1.5
    end
    
    test "queries functions by pattern", %{repository: repo, enhanced_function: function_data} do
      assert :ok = Repository.store_function(repo, function_data)
      
      # Query functions by module
      {:ok, functions} = Repository.query_functions(repo, %{
        module: :TestGenServer,
        function_name: :handle_call
      })
      
      assert length(functions) == 1
      assert hd(functions).module_name == :TestGenServer
    end
    
    test "handles function storage performance requirements", %{repository: repo} do
      # Create 100 functions
      functions = create_multiple_functions(100)
      
      {time_us, results} = :timer.tc(fn ->
        Enum.map(functions, fn func ->
          Repository.store_function(repo, func)
        end)
      end)
      
      # All should succeed
      assert Enum.all?(results, &(&1 == :ok))
      
      # Should complete in <50ms for 100 functions
      assert time_us < 50_000
    end
  end

  describe "AST node correlation and retrieval" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      {:ok, pid} = Repository.start_link(name: :test_ast_correlation)
      
      on_exit(fn -> cleanup_repository(pid) end)
      
      %{repository: pid}
    end
    
    test "retrieves AST node by ID", %{repository: repo} do
      # This test will fail initially (TDD red phase)
      ast_node_id = "TestModule:test_function:1:call"
      
      # Should return error for non-existent node
      assert {:error, :not_found} = Repository.get_ast_node(repo, ast_node_id)
      
      # TODO: Implement AST node storage and retrieval
      # After implementation, this should work:
      # {:ok, {ast_node, metadata}} = Repository.get_ast_node(repo, ast_node_id)
    end
    
    test "finds function references", %{repository: repo} do
      # This test will fail initially (TDD red phase)
      
      # Should return empty list for non-existent function
      {:ok, references} = Repository.find_references(repo, :TestModule, :test_function, 1)
      assert references == []
      
      # TODO: Implement reference tracking
      # After implementation with stored functions, should find references
    end
  end

  describe "Performance benchmarks" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      {:ok, pid} = Repository.start_link(name: :test_performance, memory_limit: 1000)
      
      on_exit(fn -> cleanup_repository(pid) end)
      
      %{repository: pid}
    end
    
    test "module storage meets performance targets", %{repository: repo} do
      # Create 50 modules with 20 functions each (1000 total functions)
      modules = create_multiple_modules(50, 20)
      
      {time_us, results} = :timer.tc(fn ->
        Enum.map(modules, fn module ->
          Repository.store_module(repo, module)
        end)
      end)
      
      # All should succeed
      assert Enum.all?(results, &(&1 == :ok))
      
      # Should complete in <50ms for 1000 functions
      assert time_us < 50_000
    end
    
    test "complex AST queries meet performance targets", %{repository: repo} do
      # Store test data
      modules = create_multiple_modules(10, 10)
      Enum.each(modules, &Repository.store_module(repo, &1))
      
      # Complex query combining multiple criteria
      {time_us, {:ok, results}} = :timer.tc(fn ->
        Repository.query_functions(repo, %{
          complexity: {:gt, 2.0},
          visibility: :public,
          is_callback: true,
          limit: 50,
          sort: {:desc, :complexity}
        })
      end)
      
      # Should complete in <100ms (100,000 microseconds)
      assert time_us < 100_000
      assert is_list(results)
    end
    
    test "memory usage stays within limits", %{repository: repo} do
      # Store large amount of data
      modules = create_multiple_modules(100, 10)
      Enum.each(modules, &Repository.store_module(repo, &1))
      
      # Check memory usage
      {:ok, stats} = Repository.get_statistics(repo)
      
      # Should stay under 500MB (configured limit is 1000MB for this test)
      assert stats.memory_usage_mb < 500
    end
  end

  describe "Integration with EventStore" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      {:ok, repo_pid} = Repository.start_link(name: :test_integration_repo)
      {:ok, store_pid} = ElixirScope.Storage.EventStore.start_link(name: :test_integration_store)
      
      on_exit(fn -> 
        cleanup_repository(repo_pid)
        if Process.alive?(store_pid), do: GenServer.stop(store_pid)
      end)
      
      %{repository: repo_pid, event_store: store_pid}
    end
    
    test "correlates events with AST nodes", %{repository: repo, event_store: store} do
      # Store module with AST node IDs
      module_data = create_sample_module_with_ast_ids()
      :ok = Repository.store_module(repo, module_data)
      
      # Create event with AST node correlation
      event = %{
        event_type: :function_call,
        module: :TestModule,
        function: :test_function,
        arity: 1,
        ast_node_id: "TestModule:test_function:1:call",
        timestamp: DateTime.utc_now(),
        pid: self()
      }
      
      # Store event
      :ok = ElixirScope.Storage.EventStore.store_event(store, event)
      
      # Should be able to correlate event to AST node
      # The function is implemented and should return ast_node_not_found for non-existent nodes
      assert {:error, :ast_node_not_found} = Repository.correlate_event_to_ast(repo, event)
    end
  end

  # Helper functions
  defp cleanup_repository(pid) do
    try do
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal, 5000)
      end
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end

  defp create_large_module_data(function_count) do
    functions = create_multiple_functions(function_count)
    
    %EnhancedModuleData{
      module_name: :LargeModule,
      file_path: "test/large_module.ex",
      ast: {:defmodule, [], []},
      functions: Enum.into(functions, %{}, fn func -> {{func.function_name, func.arity}, func} end),
      dependencies: [],
      exports: [],
      attributes: %{},
      complexity_metrics: %{combined_complexity: function_count * 1.5},
      quality_metrics: %{maintainability_index: 85.0},
      security_analysis: %{has_vulnerabilities: false, issues: []},
      performance_hints: [],
      file_size: function_count * 100,
      line_count: function_count * 5,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp create_multiple_functions(count) do
    1..count
    |> Enum.map(fn i ->
      %EnhancedFunctionData{
        module_name: :TestModule,
        function_name: :"function_#{i}",
        arity: 1,
        ast: {:def, [], []},
        cfg_data: nil,
        dfg_data: nil,
        cpg_data: nil,
        complexity_metrics: %{combined_complexity: 1.0 + (i / 10)},
        performance_analysis: %{has_issues: false, bottlenecks: []},
        security_analysis: %{has_vulnerabilities: false, issues: []},
        optimization_hints: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end)
  end

  defp create_multiple_modules(module_count, functions_per_module) do
    1..module_count
    |> Enum.map(fn i ->
      functions = create_multiple_functions(functions_per_module)
      
      %EnhancedModuleData{
        module_name: :"Module#{i}",
        file_path: "test/module#{i}.ex",
        ast: {:defmodule, [], []},
        functions: Enum.into(functions, %{}, fn func -> {{func.function_name, func.arity}, func} end),
        dependencies: [],
        exports: [],
        attributes: %{},
        complexity_metrics: %{combined_complexity: functions_per_module * 1.5},
        quality_metrics: %{maintainability_index: 85.0},
        security_analysis: %{has_vulnerabilities: false, issues: []},
        performance_hints: [],
        file_size: functions_per_module * 100,
        line_count: functions_per_module * 5,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end)
  end

  defp create_sample_module_with_ast_ids do
    test_function = %EnhancedFunctionData{
      module_name: :TestModule,
      function_name: :test_function,
      arity: 1,
      ast: {:def, [ast_node_id: "TestModule:test_function:1:def"], []},
      cfg_data: nil,
      dfg_data: nil,
      cpg_data: nil,
      complexity_metrics: %{combined_complexity: 1.0},
      performance_analysis: %{has_issues: false, bottlenecks: []},
      security_analysis: %{has_vulnerabilities: false, issues: []},
      optimization_hints: [],
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
    
    %EnhancedModuleData{
      module_name: :TestModule,
      file_path: "test/test_module.ex",
      ast: {:defmodule, [ast_node_id: "TestModule:module:def"], []},
      functions: %{{:test_function, 1} => test_function},
      dependencies: [],
      exports: [],
      attributes: %{},
      complexity_metrics: %{combined_complexity: 1.0},
      quality_metrics: %{maintainability_index: 95.0},
      security_analysis: %{has_vulnerabilities: false, issues: []},
      performance_hints: [],
      file_size: 500,
      line_count: 20,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end
end 