defmodule ElixirScope.Integration.ASTRuntimeIntegrationTest do
  @moduledoc """
  Comprehensive integration tests for AST-Runtime correlation system.
  
  Tests the complete integration between:
  - RuntimeCorrelator: AST-Runtime correlation
  - EnhancedInstrumentation: AST-aware event capture
  - TemporalBridgeEnhancement: AST-aware time-travel debugging
  - Enhanced AST Repository: Structural analysis
  """
  
  use ExUnit.Case, async: false
  require Logger
  
  alias ElixirScope.ASTRepository.{RuntimeCorrelator, EnhancedRepository}
  alias ElixirScope.Capture.{EnhancedInstrumentation, TemporalBridgeEnhancement}
  alias ElixirScope.Events
  alias ElixirScope.Storage.EventStore
  
  @moduletag :integration
  @moduletag timeout: 30_000
  
  # Test module for instrumentation
  defmodule TestInstrumentedModule do
    @moduledoc "Test module for AST-Runtime integration testing"
    
    def simple_function(x, y) do
      result = x + y
      Logger.debug("Simple function result: #{result}")
      result
    end
    
    def complex_function(data) when is_list(data) do
      data
      |> Enum.map(&(&1 * 2))
      |> Enum.filter(&(&1 > 10))
      |> Enum.sum()
    end
    
    def complex_function(data) when is_map(data) do
      data
      |> Map.values()
      |> Enum.sum()
    end
    
    def error_function() do
      raise "Intentional error for testing"
    end
    
    def recursive_function(0), do: 0
    def recursive_function(n) when n > 0 do
      1 + recursive_function(n - 1)
    end
    
    def genserver_like_function(state, {:get, key}) do
      {:reply, Map.get(state, key), state}
    end
    
    def genserver_like_function(state, {:put, key, value}) do
      new_state = Map.put(state, key, value)
      {:reply, :ok, new_state}
    end
  end
  
  setup_all do
    # Start the complete AST-Runtime correlation system
    {:ok, ast_repo} = EnhancedRepository.start_link([])
    {:ok, event_store} = EventStore.start_link([])
    
    {:ok, correlator} = RuntimeCorrelator.start_link([
      ast_repo: ast_repo,
      event_store: event_store
    ])
    
    {:ok, enhanced_instrumentation} = EnhancedInstrumentation.start_link([
      ast_repo: ast_repo,
      correlator: correlator,
      enabled: true,
      ast_correlation_enabled: true
    ])
    
    {:ok, temporal_bridge} = TemporalBridgeEnhancement.start_link([
      ast_repo: ast_repo,
      correlator: correlator,
      event_store: event_store,
      enabled: true
    ])
    
    # Add test module AST data
    test_module_ast = create_test_module_ast_data()
    {:ok, _enhanced_data} = EnhancedRepository.store_enhanced_module(TestInstrumentedModule, test_module_ast, [])
    
    on_exit(fn ->
      # Clean shutdown
      if Process.alive?(temporal_bridge), do: GenServer.stop(temporal_bridge)
      if Process.alive?(enhanced_instrumentation), do: GenServer.stop(enhanced_instrumentation)
      if Process.alive?(correlator), do: GenServer.stop(correlator)
      if Process.alive?(event_store), do: GenServer.stop(event_store)
      if Process.alive?(ast_repo), do: GenServer.stop(ast_repo)
    end)
    
    %{
      ast_repo: ast_repo,
      event_store: event_store,
      correlator: correlator,
      enhanced_instrumentation: enhanced_instrumentation,
      temporal_bridge: temporal_bridge,
      test_module_data: test_module_ast
    }
  end
  
  setup context do
    # Ensure all processes are alive before each test
    %{
      ast_repo: ast_repo,
      correlator: correlator,
      enhanced_instrumentation: enhanced_instrumentation,
      temporal_bridge: temporal_bridge
    } = context
    
    unless Process.alive?(ast_repo) do
      flunk("AST Repository process died")
    end
    
    unless Process.alive?(correlator) do
      flunk("Runtime Correlator process died")
    end
    
    unless Process.alive?(enhanced_instrumentation) do
      flunk("Enhanced Instrumentation process died")
    end
    
    unless Process.alive?(temporal_bridge) do
      flunk("Temporal Bridge process died")
    end
    
    :ok
  end
  
  describe "end-to-end AST-Runtime correlation" do
    test "complete function execution with AST correlation", context do
      %{ast_repo: ast_repo, correlator: correlator} = context
      
      # Simulate function execution with enhanced instrumentation
      correlation_id = "e2e_test_#{System.unique_integer()}"
      ast_node_id = "TestInstrumentedModule.simple_function/2:line_8"
      
      # Function entry
      EnhancedInstrumentation.report_enhanced_function_entry(
        TestInstrumentedModule,
        :simple_function,
        [5, 3],
        correlation_id,
        ast_node_id
      )
      
      # Variable snapshot during execution
      EnhancedInstrumentation.report_enhanced_variable_snapshot(
        correlation_id,
        %{"x" => 5, "y" => 3, "result" => 8},
        9,
        ast_node_id
      )
      
      # Function exit
      EnhancedInstrumentation.report_enhanced_function_exit(
        correlation_id,
        8,
        1_500_000,  # 1.5ms
        ast_node_id
      )
      
      # Allow time for async processing
      Process.sleep(100)
      
      # Verify correlation worked
      test_event = %Events.FunctionEntry{
        module: TestInstrumentedModule,
        function: :simple_function,
        arity: 2,
        args: [5, 3],
        correlation_id: correlation_id,
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond),
        caller_line: 8
      }
      
      {:ok, ast_context} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, test_event)
      
      assert ast_context.module == TestInstrumentedModule
      assert ast_context.function == :simple_function
      assert ast_context.arity == 2
      assert ast_context.ast_node_id == ast_node_id
      assert ast_context.ast_metadata.complexity == 3
    end
    
    test "structural breakpoint integration", context do
      %{enhanced_instrumentation: instrumentation} = context
      
      # Set a structural breakpoint
      {:ok, breakpoint_id} = EnhancedInstrumentation.set_structural_breakpoint(%{
        pattern: quote(do: {:simple_function, _, _}),
        condition: :any,
        ast_path: ["TestInstrumentedModule", "simple_function"],
        enabled: true,
        metadata: %{test: "integration"}
      })
      
      # Simulate function execution that should trigger breakpoint
      correlation_id = "breakpoint_test_#{System.unique_integer()}"
      ast_node_id = "TestInstrumentedModule.simple_function/2:line_8"
      
      EnhancedInstrumentation.report_enhanced_function_entry(
        TestInstrumentedModule,
        :simple_function,
        [10, 20],
        correlation_id,
        ast_node_id
      )
      
      # Allow time for breakpoint evaluation
      Process.sleep(50)
      
      # Verify breakpoint was created
      {:ok, breakpoints} = EnhancedInstrumentation.list_breakpoints()
      assert Map.has_key?(breakpoints.structural, breakpoint_id)
      
      # Clean up
      :ok = EnhancedInstrumentation.remove_breakpoint(breakpoint_id)
    end
    
    test "data flow breakpoint integration", context do
      %{enhanced_instrumentation: instrumentation} = context
      
      # Set a data flow breakpoint
      {:ok, breakpoint_id} = EnhancedInstrumentation.set_data_flow_breakpoint(%{
        variable: "result",
        ast_path: ["TestInstrumentedModule", "simple_function"],
        flow_conditions: [:assignment],
        enabled: true,
        metadata: %{test: "data_flow"}
      })
      
      # Simulate execution with variable flow
      correlation_id = "data_flow_test_#{System.unique_integer()}"
      ast_node_id = "TestInstrumentedModule.simple_function/2:line_8"
      
      EnhancedInstrumentation.report_enhanced_function_entry(
        TestInstrumentedModule,
        :simple_function,
        [7, 13],
        correlation_id,
        ast_node_id
      )
      
      # Variable snapshot that should trigger breakpoint
      EnhancedInstrumentation.report_enhanced_variable_snapshot(
        correlation_id,
        %{"x" => 7, "y" => 13, "result" => 20},
        9,
        ast_node_id
      )
      
      # Allow time for breakpoint evaluation
      Process.sleep(50)
      
      # Verify breakpoint exists
      {:ok, breakpoints} = EnhancedInstrumentation.list_breakpoints()
      assert Map.has_key?(breakpoints.data_flow, breakpoint_id)
      
      # Clean up
      :ok = EnhancedInstrumentation.remove_breakpoint(breakpoint_id)
    end
    
    test "semantic watchpoint integration", context do
      %{enhanced_instrumentation: instrumentation} = context
      
      # Set a semantic watchpoint
      {:ok, watchpoint_id} = EnhancedInstrumentation.set_semantic_watchpoint(%{
        variable: "state",
        track_through: [:pattern_match, :function_call],
        ast_scope: "TestInstrumentedModule.genserver_like_function/2",
        enabled: true,
        metadata: %{test: "semantic"}
      })
      
      # Simulate GenServer-like execution
      correlation_id = "semantic_test_#{System.unique_integer()}"
      ast_node_id = "TestInstrumentedModule.genserver_like_function/2:line_28"
      
      EnhancedInstrumentation.report_enhanced_function_entry(
        TestInstrumentedModule,
        :genserver_like_function,
        [%{key1: "value1"}, {:get, :key1}],
        correlation_id,
        ast_node_id
      )
      
      # Variable snapshots showing state evolution
      EnhancedInstrumentation.report_enhanced_variable_snapshot(
        correlation_id,
        %{"state" => %{key1: "value1"}},
        29,
        ast_node_id
      )
      
      # Allow time for watchpoint processing
      Process.sleep(50)
      
      # Verify watchpoint exists
      {:ok, breakpoints} = EnhancedInstrumentation.list_breakpoints()
      assert Map.has_key?(breakpoints.semantic, watchpoint_id)
      
      # Clean up
      :ok = EnhancedInstrumentation.remove_breakpoint(watchpoint_id)
    end
  end
  
  describe "temporal bridge AST integration" do
    test "AST-aware state reconstruction", context do
      %{temporal_bridge: temporal_bridge, ast_repo: ast_repo} = context
      
      session_id = "temporal_test_#{System.unique_integer()}"
      timestamp = System.monotonic_time(:nanosecond)
      
      # Simulate some execution events
      correlation_id = "temporal_correlation_#{System.unique_integer()}"
      
      # Create events that would be stored in EventStore
      events = [
        %Events.FunctionEntry{
          module: TestInstrumentedModule,
          function: :complex_function,
          arity: 1,
          args: [[1, 2, 3, 4, 5, 6]],
          correlation_id: correlation_id,
          timestamp: timestamp,
          wall_time: System.system_time(:nanosecond)
        },
        %{
          event_type: :local_variable_snapshot,
          module: TestInstrumentedModule,
          function: :complex_function,
          correlation_id: correlation_id,
          timestamp: timestamp + 1_000_000,
          variables: %{"data" => [1, 2, 3, 4, 5, 6]},
          ast_node_id: "TestInstrumentedModule.complex_function/1:line_13"
        },
        %{
          event_type: :local_variable_snapshot,
          module: TestInstrumentedModule,
          function: :complex_function,
          correlation_id: correlation_id,
          timestamp: timestamp + 2_000_000,
          variables: %{"data" => [2, 4, 6, 8, 10, 12]},
          ast_node_id: "TestInstrumentedModule.complex_function/1:line_14"
        }
      ]
      
      # Test AST-enhanced state reconstruction
      # Note: This would normally integrate with actual TemporalBridge
      # For testing, we'll verify the enhancement functionality
      
      {:ok, enhanced_state} = TemporalBridgeEnhancement.reconstruct_state_with_ast(
        session_id,
        timestamp + 1_500_000,
        ast_repo
      )
      
      # Verify enhanced state structure
      assert Map.has_key?(enhanced_state, :original_state)
      assert Map.has_key?(enhanced_state, :ast_context)
      assert Map.has_key?(enhanced_state, :structural_info)
      assert Map.has_key?(enhanced_state, :execution_path)
      assert Map.has_key?(enhanced_state, :variable_flow)
      assert enhanced_state.timestamp == timestamp + 1_500_000
    end
    
    test "AST execution trace building", context do
      %{temporal_bridge: temporal_bridge} = context
      
      session_id = "trace_test_#{System.unique_integer()}"
      start_time = System.monotonic_time(:nanosecond)
      end_time = start_time + 10_000_000  # 10ms later
      
      {:ok, trace} = TemporalBridgeEnhancement.get_ast_execution_trace(
        session_id,
        start_time,
        end_time
      )
      
      # Verify trace structure
      assert Map.has_key?(trace, :events)
      assert Map.has_key?(trace, :ast_flow)
      assert Map.has_key?(trace, :state_transitions)
      assert Map.has_key?(trace, :structural_patterns)
      assert Map.has_key?(trace, :execution_metadata)
      
      assert trace.execution_metadata.session_id == session_id
      assert trace.execution_metadata.start_time == start_time
      assert trace.execution_metadata.end_time == end_time
    end
    
    test "AST node state navigation", context do
      %{temporal_bridge: temporal_bridge} = context
      
      session_id = "navigation_test_#{System.unique_integer()}"
      ast_node_id = "TestInstrumentedModule.simple_function/2:line_8"
      
      {:ok, states} = TemporalBridgeEnhancement.get_states_for_ast_node(
        session_id,
        ast_node_id
      )
      
      # Should return a list of states (may be empty for test)
      assert is_list(states)
    end
    
    test "execution flow between AST nodes", context do
      %{temporal_bridge: temporal_bridge} = context
      
      session_id = "flow_test_#{System.unique_integer()}"
      from_node = "TestInstrumentedModule.simple_function/2:line_8"
      to_node = "TestInstrumentedModule.complex_function/1:line_13"
      
      {:ok, flow} = TemporalBridgeEnhancement.get_execution_flow_between_nodes(
        session_id,
        from_node,
        to_node
      )
      
      # Verify flow structure
      assert Map.has_key?(flow, :from_ast_node_id)
      assert Map.has_key?(flow, :to_ast_node_id)
      assert Map.has_key?(flow, :flow_events)
      assert Map.has_key?(flow, :flow_states)
      assert Map.has_key?(flow, :execution_paths)
      
      assert flow.from_ast_node_id == from_node
      assert flow.to_ast_node_id == to_node
    end
  end
  
  describe "performance integration" do
    test "end-to-end performance meets targets", context do
      %{ast_repo: ast_repo, correlator: correlator, enhanced_instrumentation: instrumentation} = context
      
      # Test high-volume scenario
      num_events = 100
      correlation_ids = Enum.map(1..num_events, fn i -> "perf_test_#{i}" end)
      
      start_time = System.monotonic_time(:millisecond)
      
      # Simulate rapid function executions
      Enum.each(correlation_ids, fn correlation_id ->
        ast_node_id = "TestInstrumentedModule.simple_function/2:line_8"
        
        EnhancedInstrumentation.report_enhanced_function_entry(
          TestInstrumentedModule,
          :simple_function,
          [1, 2],
          correlation_id,
          ast_node_id
        )
        
        EnhancedInstrumentation.report_enhanced_function_exit(
          correlation_id,
          3,
          500_000,  # 0.5ms
          ast_node_id
        )
      end)
      
      end_time = System.monotonic_time(:millisecond)
      total_duration = end_time - start_time
      
      # Performance targets
      avg_time_per_event = total_duration / num_events
      assert avg_time_per_event < 5.0, "Average time per event #{avg_time_per_event}ms exceeds 5ms target"
      
      # Test correlation performance
      test_event = %Events.FunctionEntry{
        module: TestInstrumentedModule,
        function: :simple_function,
        arity: 2,
        args: [1, 2],
        correlation_id: hd(correlation_ids),
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      correlation_start = System.monotonic_time(:millisecond)
      {:ok, _ast_context} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, test_event)
      correlation_end = System.monotonic_time(:millisecond)
      
      correlation_time = correlation_end - correlation_start
      assert correlation_time < 5, "Correlation time #{correlation_time}ms exceeds 5ms target"
    end
    
    test "memory usage remains stable under load", context do
      %{enhanced_instrumentation: instrumentation} = context
      
      # Get initial memory usage
      initial_memory = :erlang.memory(:total)
      
      # Create many breakpoints and watchpoints
      breakpoint_ids = Enum.map(1..50, fn i ->
        {:ok, id} = EnhancedInstrumentation.set_structural_breakpoint(%{
          pattern: quote(do: {:test_pattern, unquote(i)}),
          condition: :any,
          metadata: %{test_id: i}
        })
        id
      end)
      
      watchpoint_ids = Enum.map(1..50, fn i ->
        {:ok, id} = EnhancedInstrumentation.set_semantic_watchpoint(%{
          variable: "test_var_#{i}",
          track_through: [:all],
          metadata: %{test_id: i}
        })
        id
      end)
      
      # Simulate many events
      Enum.each(1..200, fn i ->
        correlation_id = "memory_test_#{i}"
        ast_node_id = "TestInstrumentedModule.simple_function/2:line_8"
        
        EnhancedInstrumentation.report_enhanced_function_entry(
          TestInstrumentedModule,
          :simple_function,
          [i, i + 1],
          correlation_id,
          ast_node_id
        )
        
        EnhancedInstrumentation.report_enhanced_variable_snapshot(
          correlation_id,
          %{"x" => i, "y" => i + 1, "result" => i * 2 + 1},
          9,
          ast_node_id
        )
        
        EnhancedInstrumentation.report_enhanced_function_exit(
          correlation_id,
          i * 2 + 1,
          1_000_000,
          ast_node_id
        )
      end)
      
      # Allow time for processing
      Process.sleep(500)
      
      # Check final memory usage
      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory
      memory_increase_mb = memory_increase / (1024 * 1024)
      
      # Memory increase should be reasonable (less than 50MB for this test)
      assert memory_increase_mb < 50, "Memory increase #{memory_increase_mb}MB is too high"
      
      # Clean up
      Enum.each(breakpoint_ids ++ watchpoint_ids, fn id ->
        EnhancedInstrumentation.remove_breakpoint(id)
      end)
    end
  end
  
  describe "error handling and resilience" do
    test "system remains stable with invalid events", context do
      %{correlator: correlator, ast_repo: ast_repo} = context
      
      invalid_events = [
        %{},  # Empty event
        %{module: nil, function: nil},  # Nil values
        %{module: "invalid", function: "invalid"},  # String instead of atom
        %{module: NonExistentModule, function: :non_existent},  # Non-existent module
        nil  # Nil event
      ]
      
      # System should handle all invalid events gracefully
      Enum.each(invalid_events, fn event ->
        result = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
        assert match?({:error, _}, result)
      end)
      
      # System should still work with valid events
      valid_event = %Events.FunctionEntry{
        module: TestInstrumentedModule,
        function: :simple_function,
        arity: 2,
        args: [1, 2],
        correlation_id: "recovery_test",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      {:ok, _ast_context} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, valid_event)
    end
    
    test "concurrent access safety", context do
      %{ast_repo: ast_repo, enhanced_instrumentation: instrumentation} = context
      
      # Test concurrent operations
      tasks = Enum.map(1..20, fn i ->
        Task.async(fn ->
          # Concurrent correlation
          event = %Events.FunctionEntry{
            module: TestInstrumentedModule,
            function: :simple_function,
            arity: 2,
            args: [i, i + 1],
            correlation_id: "concurrent_#{i}",
            timestamp: System.monotonic_time(:nanosecond),
            wall_time: System.system_time(:nanosecond)
          }
          
          correlation_result = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
          
          # Concurrent breakpoint setting
          breakpoint_result = EnhancedInstrumentation.set_structural_breakpoint(%{
            pattern: quote(do: {:concurrent_test, unquote(i)}),
            condition: :any,
            metadata: %{concurrent_id: i}
          })
          
          # Concurrent instrumentation
          correlation_id = "concurrent_instr_#{i}"
          ast_node_id = "TestInstrumentedModule.simple_function/2:line_8"
          
          EnhancedInstrumentation.report_enhanced_function_entry(
            TestInstrumentedModule,
            :simple_function,
            [i, i + 1],
            correlation_id,
            ast_node_id
          )
          
          {correlation_result, breakpoint_result}
        end)
      end)
      
      results = Task.await_many(tasks, 10_000)
      
      # All tasks should complete successfully
      assert length(results) == 20
      
      Enum.each(results, fn {correlation_result, breakpoint_result} ->
        assert match?({:ok, _}, correlation_result)
        assert match?({:ok, _}, breakpoint_result)
      end)
    end
  end
  
  describe "statistics and monitoring" do
    test "comprehensive statistics collection", context do
      %{correlator: correlator, enhanced_instrumentation: instrumentation, temporal_bridge: temporal_bridge} = context
      
      # Perform various operations to generate statistics
      correlation_id = "stats_test_#{System.unique_integer()}"
      ast_node_id = "TestInstrumentedModule.simple_function/2:line_8"
      
      # Enhanced instrumentation operations
      EnhancedInstrumentation.report_enhanced_function_entry(
        TestInstrumentedModule,
        :simple_function,
        [10, 20],
        correlation_id,
        ast_node_id
      )
      
      EnhancedInstrumentation.report_enhanced_function_exit(
        correlation_id,
        30,
        2_000_000,
        ast_node_id
      )
      
      # Correlation operations
      test_event = %Events.FunctionEntry{
        module: TestInstrumentedModule,
        function: :simple_function,
        arity: 2,
        args: [10, 20],
        correlation_id: correlation_id,
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      {:ok, _} = RuntimeCorrelator.correlate_event_to_ast(correlator, test_event)
      
      # Allow time for statistics collection
      Process.sleep(100)
      
      # Get statistics from all components
      {:ok, correlator_stats} = RuntimeCorrelator.get_correlation_stats()
      {:ok, instrumentation_stats} = EnhancedInstrumentation.get_stats()
      {:ok, temporal_stats} = TemporalBridgeEnhancement.get_enhancement_stats()
      
      # Verify statistics structure
      assert Map.has_key?(correlator_stats, :correlation)
      assert Map.has_key?(correlator_stats, :cache)
      assert Map.has_key?(correlator_stats, :breakpoints)
      assert Map.has_key?(correlator_stats, :watchpoints)
      
      assert Map.has_key?(instrumentation_stats, :enabled)
      assert Map.has_key?(instrumentation_stats, :ast_correlation_enabled)
      assert Map.has_key?(instrumentation_stats, :breakpoint_stats)
      assert Map.has_key?(instrumentation_stats, :active_breakpoints)
      
      assert Map.has_key?(temporal_stats, :enhancement)
      assert Map.has_key?(temporal_stats, :cache)
      assert Map.has_key?(temporal_stats, :enabled)
    end
  end
  
  # Helper Functions
  
  defp create_test_module_ast_data do
    # Return actual AST for the test module
    quote do
      defmodule TestInstrumentedModule do
        @moduledoc "Test module for AST-Runtime correlation"
        
        def simple_function(x, y) when is_integer(x) and is_integer(y) do
          result = x + y
          Logger.info("Simple calculation: #{x} + #{y} = #{result}")
          result
        end
        
        def test_function(x) when is_integer(x) do
          result = x * 2
          Logger.info("Processing: #{x} -> #{result}")
          result
        end
        
        def complex_function(data) when is_list(data) do
          data
          |> Enum.map(&(&1 * 2))
          |> Enum.filter(&(&1 > 10))
          |> Enum.sum()
        end
        
        def async_function(items) do
          Task.async_stream(items, fn item ->
            Process.sleep(10)
            item * 3
          end)
          |> Enum.to_list()
        end
      end
    end
  end
end 