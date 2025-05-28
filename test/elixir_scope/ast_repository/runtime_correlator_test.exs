# test/elixir_scope/ast_repository/runtime_correlator_test.exs
defmodule ElixirScope.ASTRepository.RuntimeCorrelatorTest do
  use ExUnit.Case, async: false
  require Logger
  
  alias ElixirScope.ASTRepository.RuntimeCorrelator
  alias ElixirScope.ASTRepository.TestSupport.Helpers
  alias ElixirScope.Utils
  alias ElixirScope.Events
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  @moduletag :integration
  
  # Helper functions for debugging intermittent failures
  defp ensure_config_available do
    case GenServer.whereis(ElixirScope.Config) do
      nil ->
        Logger.info("🔄 Starting Config GenServer for test...")
        {:ok, _pid} = ElixirScope.Config.start_link([])
        wait_for_config_ready()
      pid ->
        Logger.info("✅ Config GenServer already running: #{inspect(pid)}")
        # Verify it's responsive
        try do
          ElixirScope.Config.get()
          :ok
        rescue
          error ->
            Logger.warning("⚠️ Config GenServer unresponsive, restarting: #{inspect(error)}")
            GenServer.stop(pid)
            {:ok, _pid} = ElixirScope.Config.start_link([])
            wait_for_config_ready()
        end
    end
  end

  defp wait_for_config_ready(attempts \\ 0) do
    if attempts > 50 do
      raise "Config GenServer failed to become ready after 50 attempts"
    end
    
    try do
      ElixirScope.Config.get()
      Logger.info("✅ Config GenServer ready after #{attempts} attempts")
      :ok
    rescue
      _ ->
        Process.sleep(10)
        wait_for_config_ready(attempts + 1)
    end
  end

  defp monitor_test_processes(context) do
    config_pid = GenServer.whereis(ElixirScope.Config)
    repository_pid = context[:repository]
    correlator_pid = context[:correlator]
    
    [config_pid, repository_pid, correlator_pid]
    |> Enum.filter(&is_pid/1)
    |> Enum.each(fn pid ->
      ref = Process.monitor(pid)
      spawn(fn ->
        receive do
          {:DOWN, ^ref, :process, ^pid, reason} ->
            Logger.error("💀 Process #{inspect(pid)} died during test: #{inspect(reason)}")
            Logger.error("📍 Test: #{inspect(self())}")
        end
      end)
    end)
  end

  setup do
    # Start the Enhanced AST Repository
    {:ok, ast_repo} = EnhancedRepository.start_link([])
    
    # Stop RuntimeCorrelator if it's already running
    case GenServer.whereis(RuntimeCorrelator) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
    
    # Start the RuntimeCorrelator
    {:ok, correlator} = RuntimeCorrelator.start_link([
      ast_repo: ast_repo,
      event_store: nil
    ])
    
    # Create a simple AST for TestModule
    test_ast = {:defmodule, [], [
      {:__aliases__, [], [:TestModule]},
      [do: {:__block__, [], [
        {:def, [], [
          {:test_function, [], [{:arg1, [], nil}, {:arg2, [], nil}]},
          [do: {:ok, [], nil}]
        ]},
        {:defp, [], [
          {:private_function, [], [{:arg1, [], nil}]},
          [do: {:ok, [], nil}]
        ]}
      ]}]
    ]}
    
    # Store the enhanced module with AST
    {:ok, _enhanced_data} = EnhancedRepository.store_enhanced_module(TestModule, test_ast)
    
    on_exit(fn ->
      # Clean up GenServers safely
      case GenServer.whereis(RuntimeCorrelator) do
        nil -> :ok
        pid when is_pid(pid) -> 
          if Process.alive?(pid) do
            GenServer.stop(pid)
          end
      end
      case GenServer.whereis(EnhancedRepository) do
        nil -> :ok
        pid when is_pid(pid) -> 
          if Process.alive?(pid) do
            GenServer.stop(pid)
          end
      end
    end)
    
    %{
      ast_repo: ast_repo,
      correlator: correlator
    }
  end
  
  describe "event correlation" do
    test "correlates function entry event to AST", %{ast_repo: ast_repo} do
      event = %Events.FunctionEntry{
        module: TestModule,
        function: :test_function,
        arity: 2,
        args: [:arg1, :arg2],
        correlation_id: "test_correlation_123",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      {:ok, ast_context} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
      
      assert ast_context.module == TestModule
      assert ast_context.function == :test_function
      assert ast_context.arity == 2
      assert ast_context.ast_node_id == "TestModule.test_function/2:line_10"
      assert ast_context.line_number == 10
      assert ast_context.ast_metadata.complexity == 5
      assert ast_context.ast_metadata.visibility == :public
    end
    
    test "correlates function exit event to AST", %{ast_repo: ast_repo} do
      event = %Events.FunctionExit{
        module: TestModule,
        function: :test_function,
        arity: 2,
        call_id: "call_123",
        result: :ok,
        duration_ns: 1_500_000,
        exit_reason: :normal,
        correlation_id: "test_correlation_123",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      {:ok, ast_context} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
      
      assert ast_context.module == TestModule
      assert ast_context.function == :test_function
      assert ast_context.arity == 2
      assert ast_context.ast_node_id == "TestModule.test_function/2:line_10"
    end
    
    test "handles correlation for unknown module", %{ast_repo: ast_repo} do
      event = %Events.FunctionEntry{
        module: UnknownModule,
        function: :unknown_function,
        arity: 0,
        args: [],
        correlation_id: "unknown_correlation",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      {:error, :module_not_found} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
    end
    
    test "handles correlation for unknown function", %{ast_repo: ast_repo} do
      event = %Events.FunctionEntry{
        module: TestModule,
        function: :unknown_function,
        arity: 0,
        args: [],
        correlation_id: "unknown_function_correlation",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      {:error, :function_not_found} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
    end
  end
  
  describe "runtime context" do
    test "gets comprehensive runtime context", %{ast_repo: ast_repo} do
      event = %Events.FunctionEntry{
        module: TestModule,
        function: :test_function,
        arity: 2,
        args: [:arg1, :arg2],
        correlation_id: "context_test_123",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      {:ok, context} = RuntimeCorrelator.get_runtime_context(ast_repo, event)
      
      assert context.module == TestModule
      assert context.function == :test_function
      assert context.arity == 2
      assert context.ast_node_id == "TestModule.test_function/2:line_10"
      assert context.variable_scope.local_variables == %{}
      assert context.variable_scope.scope_level == 10
    end
    
    test "handles context for event without variables", %{ast_repo: ast_repo} do
      event = %Events.FunctionEntry{
        module: TestModule,
        function: :private_function,
        arity: 1,
        args: [:arg1],
        correlation_id: "no_vars_123",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      {:ok, context} = RuntimeCorrelator.get_runtime_context(ast_repo, event)
      
      assert context.module == TestModule
      assert context.function == :private_function
      assert context.variable_scope.local_variables == %{}
    end
  end
  
  describe "event enhancement" do
    test "enhances event with AST metadata", %{ast_repo: ast_repo} do
      event = %Events.FunctionEntry{
        module: TestModule,
        function: :test_function,
        arity: 2,
        args: [:arg1, :arg2],
        correlation_id: "enhance_test_123",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      {:ok, enhanced_event} = RuntimeCorrelator.enhance_event_with_ast(ast_repo, event)
      
      assert enhanced_event.original_event == event
      assert enhanced_event.ast_context.module == TestModule
      assert enhanced_event.ast_context.function == :test_function
      assert enhanced_event.correlation_metadata.correlation_version == "1.0"
      assert enhanced_event.structural_info.ast_node_type == :function_call
      assert enhanced_event.structural_info.structural_depth == 1
    end
    
    test "handles enhancement for invalid event", %{ast_repo: ast_repo} do
      event = %{
        invalid: :event,
        timestamp: System.monotonic_time(:nanosecond)
      }
      
      {:error, :missing_module} = RuntimeCorrelator.enhance_event_with_ast(ast_repo, event)
    end
  end
  
  describe "execution trace building" do
    test "builds AST-aware execution trace", %{ast_repo: ast_repo} do
      events = [
        %Events.FunctionEntry{
          module: TestModule,
          function: :test_function,
          arity: 2,
          args: [:arg1, :arg2],
          correlation_id: "trace_test_1",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond)
        },
        %Events.FunctionExit{
          module: TestModule,
          function: :test_function,
          arity: 2,
          call_id: "call_1",
          result: :ok,
          duration_ns: 1_000_000,
          exit_reason: :normal,
          correlation_id: "trace_test_1",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond)
        },
        %Events.FunctionEntry{
          module: TestModule,
          function: :private_function,
          arity: 1,
          args: [:arg1],
          correlation_id: "trace_test_2",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond)
        }
      ]
      
      {:ok, trace} = RuntimeCorrelator.build_execution_trace(ast_repo, events)
      
      assert length(trace.events) == 3
      assert length(trace.ast_flow) == 3
      assert trace.trace_metadata.event_count == 3
      assert trace.trace_metadata.correlation_version == "1.0"
      
      # Check AST flow
      ast_flow = trace.ast_flow
      assert Enum.at(ast_flow, 0).ast_node_id == "TestModule.test_function/2:line_10"
      assert Enum.at(ast_flow, 1).ast_node_id == "TestModule.test_function/2:line_10"
      assert Enum.at(ast_flow, 2).ast_node_id == "TestModule.private_function/1:line_25"
      
      # Check structural patterns
      assert length(trace.structural_patterns) > 0
      pattern = hd(trace.structural_patterns)
      assert pattern.pattern_type == :function_call
      assert pattern.occurrences == 3
    end
    
    test "builds trace with variable flow", %{ast_repo: ast_repo} do
      events = [
        %Events.FunctionEntry{
          module: TestModule,
          function: :test_function,
          arity: 2,
          args: [:arg1, :arg2],
          correlation_id: "var_trace_1",
          timestamp: 1000,
          wall_time: System.system_time(:nanosecond)
        },
        %{
          event_type: :local_variable_snapshot,
          module: TestModule,
          function: :test_function,
          correlation_id: "var_trace_1",
          timestamp: 1500,
          variables: %{"x" => 1, "y" => "start"}
        },
        %{
          event_type: :local_variable_snapshot,
          module: TestModule,
          function: :test_function,
          correlation_id: "var_trace_1",
          timestamp: 2000,
          variables: %{"x" => 2, "y" => "middle", "z" => true}
        },
        %{
          event_type: :local_variable_snapshot,
          module: TestModule,
          function: :test_function,
          correlation_id: "var_trace_1",
          timestamp: 2500,
          variables: %{"x" => 3, "y" => "end"}
        },
        %Events.FunctionExit{
          module: TestModule,
          function: :test_function,
          arity: 2,
          call_id: "call_1",
          result: :ok,
          duration_ns: 2_000_000,
          exit_reason: :normal,
          correlation_id: "var_trace_1",
          timestamp: 3000,
          wall_time: System.system_time(:nanosecond)
        }
      ]
      
      {:ok, trace} = RuntimeCorrelator.build_execution_trace(ast_repo, events)
      
      # Check variable flow
      variable_flow = trace.variable_flow
      assert Map.has_key?(variable_flow, "x")
      assert Map.has_key?(variable_flow, "y")
      assert Map.has_key?(variable_flow, "z")
      
      x_history = variable_flow["x"]
      assert length(x_history) == 3
      assert Enum.at(x_history, 0).value == 1
      assert Enum.at(x_history, 1).value == 2
      assert Enum.at(x_history, 2).value == 3
      
      y_history = variable_flow["y"]
      assert length(y_history) == 3
      assert Enum.at(y_history, 0).value == "start"
      assert Enum.at(y_history, 1).value == "middle"
      assert Enum.at(y_history, 2).value == "end"
      
      z_history = variable_flow["z"]
      assert length(z_history) == 1
      assert Enum.at(z_history, 0).value == true
    end
    
    test "handles empty event list", %{ast_repo: ast_repo} do
      {:ok, trace} = RuntimeCorrelator.build_execution_trace(ast_repo, [])
      
      assert trace.events == []
      assert trace.ast_flow == []
      assert trace.variable_flow == %{}
      assert trace.structural_patterns == []
      assert trace.trace_metadata.event_count == 0
    end
  end
  
  describe "structural breakpoints" do
    test "sets and validates structural breakpoint" do
      breakpoint_spec = %{
        pattern: quote(do: {:handle_call, _, _}),
        condition: :pattern_match_failure,
        ast_path: ["TestModule", "handle_call"],
        enabled: true,
        metadata: %{description: "Test breakpoint"}
      }
      
      {:ok, breakpoint_id} = RuntimeCorrelator.set_structural_breakpoint(breakpoint_spec)
      
      assert is_binary(breakpoint_id)
      assert String.starts_with?(breakpoint_id, "structural_bp_")
    end
    
    test "validates structural breakpoint pattern" do
      invalid_spec = %{
        pattern: nil,
        condition: :any
      }
      
      {:error, :invalid_pattern} = RuntimeCorrelator.set_structural_breakpoint(invalid_spec)
    end
    
    test "sets structural breakpoint with default values" do
      minimal_spec = %{
        pattern: quote(do: {:test, _})
      }
      
      {:ok, breakpoint_id} = RuntimeCorrelator.set_structural_breakpoint(minimal_spec)
      assert is_binary(breakpoint_id)
    end
  end
  
  describe "data flow breakpoints" do
    test "sets and validates data flow breakpoint" do
      breakpoint_spec = %{
        variable: "user_id",
        ast_path: ["TestModule", "authenticate"],
        flow_conditions: [:assignment, :pattern_match],
        enabled: true,
        metadata: %{description: "Track user_id flow"}
      }
      
      {:ok, breakpoint_id} = RuntimeCorrelator.set_data_flow_breakpoint(breakpoint_spec)
      
      assert is_binary(breakpoint_id)
      assert String.starts_with?(breakpoint_id, "data_flow_bp_")
    end
    
    test "validates data flow breakpoint variable" do
      invalid_spec = %{
        variable: nil,
        ast_path: ["TestModule"]
      }
      
      {:error, :invalid_variable} = RuntimeCorrelator.set_data_flow_breakpoint(invalid_spec)
    end
  end
  
  describe "semantic watchpoints" do
    test "sets and validates semantic watchpoint" do
      watchpoint_spec = %{
        variable: "state",
        track_through: [:pattern_match, :function_call],
        ast_scope: "TestModule.handle_call/3",
        enabled: true,
        metadata: %{description: "Track state variable"}
      }
      
      {:ok, watchpoint_id} = RuntimeCorrelator.set_semantic_watchpoint(watchpoint_spec)
      
      assert is_binary(watchpoint_id)
      assert String.starts_with?(watchpoint_id, "wp_")
    end
    
    test "validates semantic watchpoint variable" do
      invalid_spec = %{
        variable: nil,
        track_through: [:all]
      }
      
      {:error, :invalid_variable} = RuntimeCorrelator.set_semantic_watchpoint(invalid_spec)
    end
  end
  
  describe "performance and caching" do
    test "correlation performance is within target", %{ast_repo: ast_repo} do
      event = %Events.FunctionEntry{
        module: TestModule,
        function: :test_function,
        arity: 2,
        args: [:arg1, :arg2],
        correlation_id: "perf_test_123",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      start_time = System.monotonic_time(:millisecond)
      {:ok, _ast_context} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
      end_time = System.monotonic_time(:millisecond)
      
      duration = end_time - start_time
      assert duration < 5, "Correlation took #{duration}ms, target is <1ms"
    end
    
    test "caching improves performance", %{ast_repo: ast_repo} do
      event = %Events.FunctionEntry{
        module: TestModule,
        function: :test_function,
        arity: 2,
        args: [:arg1, :arg2],
        correlation_id: "cache_test_123",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      # First call (cache miss)
      start_time1 = System.monotonic_time(:microsecond)
      {:ok, _ast_context1} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
      end_time1 = System.monotonic_time(:microsecond)
      duration1 = end_time1 - start_time1
      
      # Second call (cache hit)
      start_time2 = System.monotonic_time(:microsecond)
      {:ok, _ast_context2} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
      end_time2 = System.monotonic_time(:microsecond)
      duration2 = end_time2 - start_time2
      
      # Cache hit should be faster
      assert duration2 < duration1, "Cache hit (#{duration2}µs) should be faster than miss (#{duration1}µs)"
    end
    
    test "gets correlation statistics" do
      {:ok, stats} = RuntimeCorrelator.get_correlation_stats()
      
      assert Map.has_key?(stats, :correlation)
      assert Map.has_key?(stats, :cache)
      assert Map.has_key?(stats, :breakpoints)
      assert Map.has_key?(stats, :watchpoints)
      
      assert Map.has_key?(stats.correlation, :events_correlated)
      assert Map.has_key?(stats.correlation, :context_lookups)
      assert Map.has_key?(stats.correlation, :cache_hits)
      assert Map.has_key?(stats.correlation, :cache_misses)
    end
    
    test "clears caches successfully", %{ast_repo: ast_repo} do
      # Perform some operations to populate cache
      event = %Events.FunctionEntry{
        module: TestModule,
        function: :test_function,
        arity: 2,
        args: [:arg1, :arg2],
        correlation_id: "clear_cache_test",
        timestamp: System.monotonic_time(:nanosecond),
        wall_time: System.system_time(:nanosecond)
      }
      
      {:ok, _} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
      
      # Clear caches
      :ok = RuntimeCorrelator.clear_caches()
      
      # Verify caches are cleared
      {:ok, stats} = RuntimeCorrelator.get_correlation_stats()
      assert stats.cache.context_cache_size == 0
      assert stats.cache.trace_cache_size == 0
    end
  end
  
  describe "integration with existing systems" do
    test "correlates with Cinema Demo event format", %{ast_repo: ast_repo} do
      # Test with Cinema Demo style event
      cinema_event = %{
        "event_type" => "function_entry",
        "module" => TestModule,
        "function" => :test_function,
        "arity" => 2,
        "correlation_id" => "cinema_test_123",
        "timestamp" => System.monotonic_time(:nanosecond)
      }
      
      {:ok, ast_context} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, cinema_event)
      
      assert ast_context.module == TestModule
      assert ast_context.function == :test_function
      assert ast_context.arity == 2
    end
    
    test "handles EventStore event format", %{ast_repo: ast_repo} do
      # Test with EventStore style event
      event_store_event = %{
        event_type: :function_entry,
        data: %{
          module: TestModule,
          function: :test_function,
          arity: 2,
          args: [:arg1, :arg2]
        },
        correlation_id: "event_store_test_123",
        timestamp: System.monotonic_time(:nanosecond),
        metadata: %{source: :instrumentation}
      }
      
      # Extract data for correlation
      extracted_event = Map.merge(event_store_event.data, %{
        correlation_id: event_store_event.correlation_id,
        timestamp: event_store_event.timestamp
      })
      
      {:ok, ast_context} = RuntimeCorrelator.correlate_event_to_ast(ast_repo, extracted_event)
      
      assert ast_context.module == TestModule
      assert ast_context.function == :test_function
    end
    
    test "performance meets EventStore requirements", %{ast_repo: ast_repo} do
      # Test that correlation overhead is minimal for high-volume scenarios
      events = Enum.map(1..100, fn i ->
        %Events.FunctionEntry{
          module: TestModule,
          function: :test_function,
          arity: 2,
          args: [:arg1, :arg2],
          correlation_id: "perf_test_#{i}",
          timestamp: System.monotonic_time(:nanosecond),
          wall_time: System.system_time(:nanosecond)
        }
      end)
      
      start_time = System.monotonic_time(:millisecond)
      
      results = Enum.map(events, fn event ->
        RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
      end)
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # All correlations should succeed
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)
      
      # Average correlation time should be well under target
      avg_time = duration / length(events)
      assert avg_time < 1.0, "Average correlation time #{avg_time}ms exceeds 1ms target"
    end
  end
  
  describe "error handling and edge cases" do
    test "handles malformed events gracefully", %{ast_repo: ast_repo} do
      malformed_events = [
        %{},  # Empty map
        %{module: nil, function: nil},  # Nil values
        %{module: "not_atom", function: "not_atom"},  # String instead of atom
        %{timestamp: "not_number"},  # Invalid timestamp
        nil  # Nil event
      ]
      
      Enum.each(malformed_events, fn event ->
        result = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
        assert match?({:error, _}, result), "Expected error for malformed event: #{inspect(event)}"
      end)
    end
    
    test "handles concurrent access safely", %{ast_repo: ast_repo} do
      # Test concurrent correlation requests
      tasks = Enum.map(1..50, fn i ->
        Task.async(fn ->
          event = %Events.FunctionEntry{
            module: TestModule,
            function: :test_function,
            arity: 2,
            args: [:arg1, :arg2],
            correlation_id: "concurrent_test_#{i}",
            timestamp: System.monotonic_time(:nanosecond),
            wall_time: System.system_time(:nanosecond)
          }
          
          RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)
        end)
      end)
      
      results = Task.await_many(tasks, 5000)
      
      # All tasks should complete successfully
      assert length(results) == 50
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)
    end
    
    test "handles memory pressure gracefully" do
      # Test with large number of breakpoints and watchpoints
      breakpoint_specs = Enum.map(1..100, fn i ->
        %{
          pattern: quote(do: {:test_pattern, unquote(i)}),
          condition: :any,
          metadata: %{test_id: i}
        }
      end)
      
      watchpoint_specs = Enum.map(1..100, fn i ->
        %{
          variable: "test_var_#{i}",
          track_through: [:all],
          metadata: %{test_id: i}
        }
      end)
      
      # Set all breakpoints and watchpoints
      breakpoint_results = Enum.map(breakpoint_specs, &RuntimeCorrelator.set_structural_breakpoint/1)
      watchpoint_results = Enum.map(watchpoint_specs, &RuntimeCorrelator.set_semantic_watchpoint/1)
      
      # All should succeed
      assert Enum.all?(breakpoint_results, fn result -> match?({:ok, _}, result) end)
      assert Enum.all?(watchpoint_results, fn result -> match?({:ok, _}, result) end)
      
      # System should still be responsive
      {:ok, stats} = RuntimeCorrelator.get_correlation_stats()
      assert stats.breakpoints.structural == 100
      assert stats.watchpoints == 100
    end
  end
end
