# test/elixir_scope/ast_repository/repository_test.exs
defmodule ElixirScope.ASTRepository.RepositoryTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.ASTRepository.{Repository, ModuleData, FunctionData}
  alias ElixirScope.Utils
  alias ElixirScope.TestHelpers

  describe "Repository lifecycle" do
    setup do
      # Ensure Config GenServer is available for Repository tests
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "can create a new repository instance" do
      assert {:ok, repository} = Repository.new()
      assert repository.repository_id
      assert repository.version == "1.0.0"
      assert is_integer(repository.creation_timestamp)
    end
    
    test "can start repository as GenServer" do
      assert {:ok, pid} = Repository.start_link(name: :test_repository)
      assert Process.alive?(pid)
      
      # Clean up
      try do
        GenServer.stop(pid)
      rescue
        _ -> :ok  # Process already dead or stopping
      catch
        :exit, _ -> :ok  # Process already dead or stopping
      end
    end
    
    test "repository health check works" do
      {:ok, pid} = Repository.start_link(name: :test_health_repository)
      
      assert {:ok, health} = Repository.health_check(pid)
      assert health.status == :healthy
      assert is_integer(health.uptime_ms)
      assert is_map(health.memory_usage)
      
      # Clean up
      try do
        GenServer.stop(pid)
      rescue
        _ -> :ok  # Process already dead or stopping
      catch
        :exit, _ -> :ok  # Process already dead or stopping
      end
    end
  end
  
  describe "Module storage and retrieval" do
    setup do
      # Ensure Config GenServer is available
      :ok = TestHelpers.ensure_config_available()
      
      {:ok, pid} = Repository.start_link(name: :test_module_repository)
      
      # Create sample AST for testing
      sample_ast = {:defmodule, [line: 1], [
        {:__aliases__, [line: 1], [:TestModule]},
        [do: {:def, [line: 2], [{:test_function, [line: 2], []}, [do: :ok]]}]
      ]}
      
      module_data = ModuleData.new(:TestModule, sample_ast, [
        source_file: "test/test_module.ex",
        instrumentation_points: [],
        correlation_metadata: %{"test_correlation_id" => "test_ast_node_id"}
      ])
      
      on_exit(fn -> 
        try do
          if Process.alive?(pid) do
            GenServer.stop(pid)
          end
        rescue
          _ -> :ok  # Process already dead or stopping
        catch
          :exit, _ -> :ok  # Process already dead or stopping
        end
      end)
      
      %{repository: pid, module_data: module_data, sample_ast: sample_ast}
    end
    
    test "can store and retrieve module data", %{repository: repository, module_data: module_data} do
      # Store module
      assert :ok = Repository.store_module(repository, module_data)
      
      # Retrieve module
      assert {:ok, retrieved_data} = Repository.get_module(repository, :TestModule)
      assert retrieved_data.module_name == :TestModule
      assert retrieved_data.source_file == "test/test_module.ex"
      assert retrieved_data.version == "1.0.0"
    end
    
    test "returns error for non-existent module", %{repository: repository} do
      assert {:error, :not_found} = Repository.get_module(repository, :NonExistentModule)
    end
    
    test "can update module data", %{repository: repository, module_data: module_data} do
      # Store initial module
      assert :ok = Repository.store_module(repository, module_data)
      
      # Update module
      update_fn = fn data ->
        ModuleData.update_runtime_insights(data, %{execution_count: 42})
      end
      
      assert :ok = Repository.update_module(repository, :TestModule, update_fn)
      
      # Verify update
      assert {:ok, updated_data} = Repository.get_module(repository, :TestModule)
      assert updated_data.runtime_insights.execution_count == 42
    end
    
    test "update returns error for non-existent module", %{repository: repository} do
      update_fn = fn data -> data end
      
      assert {:error, :not_found} = Repository.update_module(repository, :NonExistentModule, update_fn)
    end
  end
  
  describe "Function storage and retrieval" do
    setup do
      # Ensure Config GenServer is available
      :ok = TestHelpers.ensure_config_available()
      
      {:ok, pid} = Repository.start_link(name: :test_function_repository)
      
      # Create sample function AST
      function_ast = {:def, [line: 2], [
        {:test_function, [line: 2], []},
        [do: :ok]
      ]}
      
      function_key = {:TestModule, :test_function, 0}
      function_data = FunctionData.new(function_key, function_ast, [
        source_location: {"test/test_module.ex", 2},
        visibility: :public
      ])
      
      on_exit(fn -> 
        try do
          if Process.alive?(pid) do
            GenServer.stop(pid)
          end
        rescue
          _ -> :ok  # Process already dead or stopping
        catch
          :exit, _ -> :ok  # Process already dead or stopping
        end
      end)
      
      %{repository: pid, function_data: function_data, function_key: function_key}
    end
    
    test "can store and retrieve function data", %{repository: repository, function_data: function_data, function_key: function_key} do
      # Store function
      assert :ok = Repository.store_function(repository, function_data)
      
      # Retrieve function
      assert {:ok, retrieved_data} = Repository.get_function(repository, function_key)
      assert retrieved_data.function_key == function_key
      assert retrieved_data.visibility == :public
      assert retrieved_data.version == "1.0.0"
    end
    
    test "returns error for non-existent function", %{repository: repository} do
      non_existent_key = {:NonExistentModule, :non_existent_function, 0}
      assert {:error, :not_found} = Repository.get_function(repository, non_existent_key)
    end
  end
  
  describe "Runtime correlation" do
    setup do
      # Ensure Config GenServer is available
      :ok = TestHelpers.ensure_config_available()
      
      {:ok, pid} = Repository.start_link(name: :test_correlation_repository)
      
      # Create module with correlation metadata
      sample_ast = {:defmodule, [line: 1], [
        {:__aliases__, [line: 1], [:TestModule]},
        [do: {:def, [line: 2], [{:test_function, [line: 2], []}, [do: :ok]]}]
      ]}
      
      correlation_metadata = %{"test_correlation_123" => "ast_node_456"}
      
      module_data = ModuleData.new(:TestModule, sample_ast, [
        correlation_metadata: correlation_metadata
      ])
      
      # Store the module
      :ok = Repository.store_module(pid, module_data)
      
      on_exit(fn -> 
        try do
          if Process.alive?(pid) do
            GenServer.stop(pid)
          end
        rescue
          _ -> :ok  # Process already dead or stopping
        catch
          :exit, _ -> :ok  # Process already dead or stopping
        end
      end)
      
      %{repository: pid, correlation_id: "test_correlation_123", ast_node_id: "ast_node_456"}
    end
    
    test "can correlate runtime events", %{repository: repository, correlation_id: correlation_id, ast_node_id: ast_node_id} do
      # Create a runtime event with correlation ID
      runtime_event = %{
        correlation_id: correlation_id,
        timestamp: Utils.monotonic_timestamp(),
        event_type: :function_call,
        data: %{module: :TestModule, function: :test_function}
      }
      
      # Correlate the event
      assert {:ok, correlated_ast_node_id} = Repository.correlate_event(repository, runtime_event)
      assert correlated_ast_node_id == ast_node_id
    end
    
    test "returns error for event without correlation ID", %{repository: repository} do
      runtime_event = %{
        timestamp: Utils.monotonic_timestamp(),
        event_type: :function_call,
        data: %{module: :TestModule, function: :test_function}
      }
      
      assert {:error, :no_correlation_id} = Repository.correlate_event(repository, runtime_event)
    end
    
    test "returns error for unknown correlation ID", %{repository: repository} do
      runtime_event = %{
        correlation_id: "unknown_correlation_id",
        timestamp: Utils.monotonic_timestamp(),
        event_type: :function_call
      }
      
      assert {:error, :correlation_not_found} = Repository.correlate_event(repository, runtime_event)
    end
  end
  
  describe "Statistics and monitoring" do
    setup do
      # Ensure Config GenServer is available
      :ok = TestHelpers.ensure_config_available()
      
      {:ok, pid} = Repository.start_link(name: :test_stats_repository)
      
      on_exit(fn -> 
        try do
          if Process.alive?(pid) do
            GenServer.stop(pid)
          end
        rescue
          _ -> :ok  # Process already dead or stopping
        catch
          :exit, _ -> :ok  # Process already dead or stopping
        end
      end)
      
      %{repository: pid}
    end
    
    test "can get repository statistics", %{repository: repository} do
      assert {:ok, stats} = Repository.get_statistics(repository)
      
      assert is_binary(stats.repository_id)
      assert stats.version == "1.0.0"
      assert is_integer(stats.uptime_ms)
      assert is_map(stats.table_sizes)
      assert stats.table_sizes.modules >= 0
      assert stats.table_sizes.functions >= 0
      assert stats.table_sizes.correlations >= 0
    end
    
    test "statistics update when storing data", %{repository: repository} do
      # Get initial stats
      {:ok, initial_stats} = Repository.get_statistics(repository)
      initial_modules = initial_stats.table_sizes.modules
      
      # Store a module
      sample_ast = {:defmodule, [line: 1], [
        {:__aliases__, [line: 1], [:StatsTestModule]},
        [do: nil]
      ]}
      
      module_data = ModuleData.new(:StatsTestModule, sample_ast)
      :ok = Repository.store_module(repository, module_data)
      
      # Get updated stats
      {:ok, updated_stats} = Repository.get_statistics(repository)
      assert updated_stats.table_sizes.modules == initial_modules + 1
    end
  end
  
  describe "Instrumentation points" do
    setup do
      # Ensure Config GenServer is available
      :ok = TestHelpers.ensure_config_available()
      
      {:ok, pid} = Repository.start_link(name: :test_instrumentation_repository)
      
      # Create module with instrumentation points
      instrumentation_points = [
        %{ast_node_id: "node_123", type: :function_entry, metadata: %{}},
        %{ast_node_id: "node_456", type: :function_exit, metadata: %{}}
      ]
      
      sample_ast = {:defmodule, [line: 1], [
        {:__aliases__, [line: 1], [:InstrumentedModule]},
        [do: nil]
      ]}
      
      module_data = ModuleData.new(:InstrumentedModule, sample_ast, [
        instrumentation_points: instrumentation_points
      ])
      
      :ok = Repository.store_module(pid, module_data)
      
      on_exit(fn -> 
        try do
          if Process.alive?(pid) do
            GenServer.stop(pid)
          end
        rescue
          _ -> :ok  # Process already dead or stopping
        catch
          :exit, _ -> :ok  # Process already dead or stopping
        end
      end)
      
      %{repository: pid, instrumentation_points: instrumentation_points}
    end
    
    test "can retrieve instrumentation points", %{repository: repository} do
      assert {:ok, points} = Repository.get_instrumentation_points(repository, "node_123")
      assert is_map(points)
      assert points.ast_node_id == "node_123"
      assert points.type == :function_entry
    end
    
    test "returns error for non-existent instrumentation point", %{repository: repository} do
      assert {:error, :not_found} = Repository.get_instrumentation_points(repository, "non_existent_node")
    end
  end


end
