defmodule ElixirScope.UnifiedTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.Unified
  alias ElixirScope.Unified.{ModeSelector, SessionManager, EventCorrelator}
  
  # Test module for tracing
  defmodule TestModule do
    def simple_function(x) do
      x * 2
    end
    
    def function_with_args(a, b, c) do
      a + b + c
    end
    
    def function_that_calls_other(x) do
      simple_function(x) + 10
    end
    
    def function_with_exception do
      raise "Test exception"
    end
  end

  setup do
    # Start the unified system components if not already started
    case SessionManager.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    
    case EventCorrelator.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    
    on_exit(fn ->
      # Clean up any active sessions
      try do
        Unified.list_sessions()
        |> Enum.each(fn session -> 
          Unified.stop_session(session.session_id)
        end)
      rescue
        _ -> :ok  # Ignore cleanup errors
      end
    end)
    
    :ok
  end

  describe "unified interface - function tracing" do
    test "traces a simple function successfully" do
      # Test basic function tracing
      {:ok, session} = Unified.trace_function(TestModule, :simple_function, 1)
      
      assert session.mode == :runtime
      assert session.target == {TestModule, :simple_function, 1}
      assert session.status == :active
      assert is_binary(session.session_id)
      assert is_binary(session.correlation_id)
      
      # Stop the session
      {:ok, final_stats} = Unified.stop_session(session.session_id)
      assert is_map(final_stats)
    end

    test "traces function with options" do
      options = %{
        mode: :runtime,
        capture: [:args, :return],
        duration: 30_000,
        sample_rate: 1.0
      }
      
      {:ok, session} = Unified.trace_function(TestModule, :function_with_args, 3, options)
      
      assert session.mode == :runtime
      assert session.options == options
      assert session.target == {TestModule, :function_with_args, 3}
      
      {:ok, _} = Unified.stop_session(session.session_id)
    end

    test "auto mode selection chooses runtime" do
      {:ok, session} = Unified.trace_function(TestModule, :simple_function, 1, %{mode: :auto})
      
      # In Phase 1, auto mode should always select runtime
      assert session.mode == :runtime
      
      {:ok, _} = Unified.stop_session(session.session_id)
    end

    test "fallback from AST to runtime when AST not available" do
      {:ok, session} = Unified.trace_function(TestModule, :simple_function, 1, %{mode: :ast})
      
      # Should fall back to runtime since AST is not available in Phase 1
      assert session.mode == :runtime
      
      {:ok, _} = Unified.stop_session(session.session_id)
    end

    test "traces function without specifying arity" do
      {:ok, sessions} = Unified.trace_function_all_arities(TestModule, :simple_function)
      
      # Should find the single arity version
      assert length(sessions) == 1
      session = hd(sessions)
      assert session.target == {TestModule, :simple_function, 1}
      
      Enum.each(sessions, fn session ->
        {:ok, _} = Unified.stop_session(session.session_id)
      end)
    end
  end

  describe "unified interface - module tracing" do
    test "traces all functions in a module" do
      {:ok, sessions} = Unified.trace_module(TestModule)
      
      # Should trace all public functions
      assert length(sessions) > 0
      
      # Verify all sessions are for the correct module
      Enum.each(sessions, fn session ->
        {module, _function, _arity} = session.target
        assert module == TestModule
        assert session.mode == :runtime
      end)
      
      # Clean up
      Enum.each(sessions, fn session ->
        {:ok, _} = Unified.stop_session(session.session_id)
      end)
    end

    test "traces specific functions in a module" do
      options = %{
        functions: [:simple_function, :function_with_args],
        mode: :runtime
      }
      
      {:ok, sessions} = Unified.trace_module(TestModule, options)
      
      # Should only trace the specified functions
      function_names = Enum.map(sessions, fn session ->
        {_module, function, _arity} = session.target
        function
      end)
      
      assert :simple_function in function_names
      assert :function_with_args in function_names
      
      # Clean up
      Enum.each(sessions, fn session ->
        {:ok, _} = Unified.stop_session(session.session_id)
      end)
    end

    test "applies function filters correctly" do
      options = %{
        functions: :all,
        filters: %{min_arity: 2}
      }
      
      {:ok, sessions} = Unified.trace_module(TestModule, options)
      
      # Should only include functions with arity >= 2
      Enum.each(sessions, fn session ->
        {_module, _function, arity} = session.target
        assert arity >= 2
      end)
      
      # Clean up
      Enum.each(sessions, fn session ->
        {:ok, _} = Unified.stop_session(session.session_id)
      end)
    end
  end

  describe "session management" do
    test "lists active sessions" do
      # Start multiple sessions
      {:ok, session1} = Unified.trace_function(TestModule, :simple_function, 1)
      {:ok, session2} = Unified.trace_function(TestModule, :function_with_args, 3)
      
      active_sessions = Unified.list_sessions()
      
      assert length(active_sessions) >= 2
      session_ids = Enum.map(active_sessions, & &1.session_id)
      assert session1.session_id in session_ids
      assert session2.session_id in session_ids
      
      # Clean up
      {:ok, _} = Unified.stop_session(session1.session_id)
      {:ok, _} = Unified.stop_session(session2.session_id)
    end

    test "gets session information" do
      {:ok, session} = Unified.trace_function(TestModule, :simple_function, 1)
      
      {:ok, session_info} = Unified.get_session_info(session.session_id)
      
      assert session_info.session_id == session.session_id
      assert session_info.target == session.target
      assert session_info.mode == session.mode
      assert session_info.status == :active
      
      {:ok, _} = Unified.stop_session(session.session_id)
    end

    test "handles session not found" do
      assert {:error, :session_not_found} = Unified.get_session_info("nonexistent_session")
    end

    test "pauses and resumes sessions" do
      {:ok, session} = Unified.trace_function(TestModule, :simple_function, 1)
      
      # Pause session
      assert :ok = Unified.pause_session(session.session_id)
      
      # Resume session
      assert :ok = Unified.resume_session(session.session_id)
      
      {:ok, _} = Unified.stop_session(session.session_id)
    end
  end

  describe "event querying" do
    test "queries session events" do
      {:ok, session} = Unified.trace_function(TestModule, :simple_function, 1)
      
      # Execute the traced function to generate events
      TestModule.simple_function(42)
      
      # Query events (may be empty if runtime tracing isn't fully integrated yet)
      {:ok, events} = Unified.query_session_events(session.session_id)
      
      assert is_list(events)
      
      {:ok, _} = Unified.stop_session(session.session_id)
    end

    test "queries events with filters" do
      {:ok, session} = Unified.trace_function(TestModule, :simple_function, 1)
      
      query_options = %{
        event_types: [:function_call, :function_return],
        limit: 10
      }
      
      {:ok, events} = Unified.query_session_events(session.session_id, query_options)
      
      assert is_list(events)
      assert length(events) <= 10
      
      {:ok, _} = Unified.stop_session(session.session_id)
    end

    test "creates event stream" do
      {:ok, session} = Unified.trace_function(TestModule, :simple_function, 1)
      
      {:ok, stream_pid} = Unified.stream_session_events(session.session_id)
      
      assert is_pid(stream_pid)
      assert Process.alive?(stream_pid)
      
      {:ok, _} = Unified.stop_session(session.session_id)
    end
  end

  describe "system status and metrics" do
    test "gets system status" do
      status = Unified.system_status()
      
      assert is_map(status)
      assert Map.has_key?(status, :runtime_system)
      assert Map.has_key?(status, :active_sessions)
      assert Map.has_key?(status, :capabilities)
      
      # Verify capabilities reflect Phase 1 status
      capabilities = status.capabilities
      assert capabilities.runtime_tracing == true
      assert capabilities.ast_instrumentation == false
      assert capabilities.hybrid_mode == false
    end

    test "gets performance metrics" do
      metrics = Unified.performance_metrics()
      
      assert is_map(metrics)
      assert Map.has_key?(metrics, :session_creation_time)
      assert Map.has_key?(metrics, :overhead_percentage)
      assert is_number(metrics.overhead_percentage)
    end
  end

  describe "mode selector" do
    test "selects runtime mode for auto selection" do
      {:ok, mode} = ModeSelector.select_mode({TestModule, :simple_function, 1}, %{mode: :auto})
      assert mode == :runtime
    end

    test "validates explicit mode selection" do
      {:ok, mode} = ModeSelector.select_mode({TestModule, :simple_function, 1}, %{mode: :runtime})
      assert mode == :runtime
    end

    test "falls back from unavailable modes" do
      {:ok, mode} = ModeSelector.select_mode({TestModule, :simple_function, 1}, %{mode: :ast})
      assert mode == :runtime  # Should fall back to runtime
    end

    test "gets mode capabilities" do
      capabilities = ModeSelector.get_mode_capabilities()
      
      assert is_map(capabilities)
      assert Map.has_key?(capabilities, :runtime)
      assert Map.has_key?(capabilities, :ast)
      assert Map.has_key?(capabilities, :hybrid)
      
      # Verify Phase 1 availability
      assert capabilities.runtime.available == true
      assert capabilities.ast.available == false
      assert capabilities.hybrid.available == false
    end

    test "explains mode selection" do
      explanation = ModeSelector.explain_selection({TestModule, :simple_function, 1}, %{mode: :auto})
      
      assert is_map(explanation)
      assert Map.has_key?(explanation, :selected_mode)
      assert Map.has_key?(explanation, :reasoning)
      assert Map.has_key?(explanation, :alternatives)
      assert Map.has_key?(explanation, :recommendations)
      
      assert explanation.selected_mode == :runtime
      assert is_list(explanation.reasoning)
    end
  end

  describe "error handling" do
    test "handles invalid mode selection" do
      assert {:error, {:invalid_mode, :invalid}} = 
        ModeSelector.select_mode({TestModule, :simple_function, 1}, %{mode: :invalid})
    end

    test "handles module not found" do
      # This should still work but may have empty function list
      {:ok, sessions} = Unified.trace_module(NonExistentModule)
      assert sessions == []
    end

    test "handles function not found gracefully" do
      # Should return empty list for non-existent functions
      {:ok, sessions} = Unified.trace_function_all_arities(TestModule, :nonexistent_function)
      assert sessions == []
    end
  end

  describe "integration with runtime system" do
    test "unified interface integrates with runtime tracing" do
      # This test verifies that the unified interface properly delegates to the runtime system
      {:ok, session} = Unified.trace_function(TestModule, :simple_function, 1)
      
      # Verify session was created
      assert session.mode == :runtime
      assert is_binary(session.correlation_id)
      
      # Execute function to potentially generate events
      result = TestModule.simple_function(21)
      assert result == 42
      
      # Stop session and get final stats
      {:ok, final_stats} = Unified.stop_session(session.session_id)
      
      assert is_map(final_stats)
      assert Map.has_key?(final_stats, :session_id)
      assert Map.has_key?(final_stats, :duration_ns)
    end
  end
end 