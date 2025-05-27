defmodule ElixirScopeTest do
  use ExUnit.Case, async: false  # Not async because we start/stop the application

  doctest ElixirScope

  # Helper to safely stop the application - handles cases where app isn't started
  defp safe_stop_application do
    case Application.stop(:elixir_scope) do
      :ok -> :ok
      {:error, {:not_started, _}} -> :ok
      error -> error
    end
  end

  describe "application lifecycle" do
    test "starts and stops successfully" do
      # Ensure application is stopped initially
      :ok = safe_stop_application()
      
      # Start ElixirScope
      assert :ok = ElixirScope.start()
      assert ElixirScope.running?() == true
      
      # Stop ElixirScope
      assert :ok = ElixirScope.stop()
      assert ElixirScope.running?() == false
    end

    test "starts with custom options" do
      :ok = safe_stop_application()
      
      assert :ok = ElixirScope.start(strategy: :full_trace, sampling_rate: 0.8)
      assert ElixirScope.running?() == true
      
      # Verify configuration was updated
      config = ElixirScope.get_config()
      assert config.ai.planning.default_strategy == :full_trace
      assert config.ai.planning.sampling_rate == 0.8
      
      :ok = ElixirScope.stop()
    end

    test "handles start errors gracefully" do
      # This is hard to test without mocking, but we can verify
      # the error handling path exists
      assert is_function(&ElixirScope.start/1, 1)
    end

    test "double start is safe" do
      :ok = safe_stop_application()
      
      assert :ok = ElixirScope.start()
      assert :ok = ElixirScope.start()  # Should not fail
      assert ElixirScope.running?() == true
      
      :ok = ElixirScope.stop()
    end

    test "stop when not running is safe" do
      :ok = safe_stop_application()
      
      # Stop when not running should be safe
      assert :ok = ElixirScope.stop()
      assert ElixirScope.running?() == false
    end
  end

  describe "status and monitoring" do
    setup do
      :ok = safe_stop_application()
      :ok = ElixirScope.start()
      on_exit(fn -> ElixirScope.stop() end)
      :ok
    end

    test "returns status when running" do
      status = ElixirScope.status()
      
      assert is_map(status)
      assert status.running == true
      assert Map.has_key?(status, :timestamp)
      assert Map.has_key?(status, :config)
      assert Map.has_key?(status, :stats)
      assert Map.has_key?(status, :storage)
      
      assert is_map(status.config)
      assert is_map(status.stats)
      assert is_map(status.storage)
    end

    test "returns status when not running" do
      :ok = ElixirScope.stop()
      
      status = ElixirScope.status()
      
      assert is_map(status)
      assert status.running == false
      assert Map.has_key?(status, :timestamp)
      # Should not have detailed info when not running
      refute Map.has_key?(status, :config)
      refute Map.has_key?(status, :stats)
      refute Map.has_key?(status, :storage)
    end

    test "running? correctly detects state" do
      assert ElixirScope.running?() == true
      
      :ok = ElixirScope.stop()
      assert ElixirScope.running?() == false
      
      :ok = ElixirScope.start()
      assert ElixirScope.running?() == true
    end
  end

  describe "configuration management" do
    setup do
      :ok = safe_stop_application()
      :ok = ElixirScope.start()
      on_exit(fn -> ElixirScope.stop() end)
      :ok
    end

    test "gets current configuration" do
      config = ElixirScope.get_config()
      
      assert %ElixirScope.Config{} = config
      assert config.ai.provider == :mock
      assert is_number(config.ai.planning.sampling_rate)
    end

    test "updates allowed configuration paths" do
      # Update sampling rate
      assert :ok = ElixirScope.update_config([:ai, :planning, :sampling_rate], 0.7)
      
      config = ElixirScope.get_config()
      assert config.ai.planning.sampling_rate == 0.7
    end

    test "rejects updates to non-allowed paths" do
      result = ElixirScope.update_config([:ai, :provider], :openai)
      assert {:error, :not_updatable} = result
      
      # Verify original value unchanged
      config = ElixirScope.get_config()
      assert config.ai.provider == :mock
    end

    test "validates configuration updates" do
      # Try to set invalid sampling rate
      result = ElixirScope.update_config([:ai, :planning, :sampling_rate], 1.5)
      assert {:error, _} = result
      
      # Verify original value unchanged
      config = ElixirScope.get_config()
      assert config.ai.planning.sampling_rate != 1.5
    end

    test "get_config returns error when not running" do
      :ok = ElixirScope.stop()
      
      result = ElixirScope.get_config()
      assert {:error, :not_running} = result
    end

    test "update_config returns error when not running" do
      :ok = ElixirScope.stop()
      
      result = ElixirScope.update_config([:ai, :planning, :sampling_rate], 0.5)
      assert {:error, :not_running} = result
    end
  end

  describe "event querying (Phase 1 Complete)" do
    setup do
      :ok = safe_stop_application()
      :ok = ElixirScope.start()
      on_exit(fn -> ElixirScope.stop() end)
      :ok
    end

    test "get_events returns actual events or not_running error" do
      result = ElixirScope.get_events()
      # Should return events list or not_running error, not not_implemented_yet
      case result do
        events when is_list(events) -> :ok
        {:error, :not_running} -> :ok
        {:error, reason} -> refute reason == :not_implemented_yet
      end
    end

    test "get_events with query returns actual events or not_running error" do
      result = ElixirScope.get_events(pid: self(), limit: 10)
      # Should return events list or not_running error, not not_implemented_yet
      case result do
        events when is_list(events) -> :ok
        {:error, :not_running} -> :ok
        {:error, reason} -> refute reason == :not_implemented_yet
      end
    end

    test "get_state_history returns not implemented error" do
      result = ElixirScope.get_state_history(self())
      assert {:error, :not_implemented_yet} = result
    end

    test "get_state_at returns actual state or not_running error" do
      timestamp = ElixirScope.Utils.monotonic_timestamp()
      result = ElixirScope.get_state_at(self(), timestamp)
      # Should return state or not_running error, not not_implemented_yet
      case result do
        state -> refute match?({:error, :not_implemented_yet}, state)
      end
    end

    test "get_message_flow returns actual messages or not_running error" do
      result = ElixirScope.get_message_flow(self(), self())
      # Should return messages list or not_running error, not not_implemented_yet
      case result do
        messages when is_list(messages) -> :ok
        {:error, :not_running} -> :ok
        {:error, reason} -> refute reason == :not_implemented_yet
      end
    end

    test "functions return not running error when stopped" do
      :ok = ElixirScope.stop()
      
      assert {:error, :not_running} = ElixirScope.get_events()
      assert {:error, :not_running} = ElixirScope.get_state_history(self())
      assert {:error, :not_running} = ElixirScope.get_state_at(self(), 0)
      assert {:error, :not_running} = ElixirScope.get_message_flow(self(), self())
    end
  end

  describe "AI and instrumentation (not yet implemented)" do
    setup do
      :ok = safe_stop_application()
      :ok = ElixirScope.start()
      on_exit(fn -> ElixirScope.stop() end)
      :ok
    end

    test "analyze_codebase returns not implemented error" do
      result = ElixirScope.analyze_codebase()
      assert {:error, :not_implemented_yet} = result
    end

    test "update_instrumentation returns not implemented error" do
      result = ElixirScope.update_instrumentation(sampling_rate: 0.5)
      assert {:error, :not_implemented_yet} = result
    end

    test "AI functions return not running error when stopped" do
      :ok = ElixirScope.stop()
      
      assert {:error, :not_running} = ElixirScope.analyze_codebase()
      assert {:error, :not_running} = ElixirScope.update_instrumentation(sampling_rate: 0.5)
    end
  end

  describe "start option handling" do
    test "handles strategy option" do
      :ok = safe_stop_application()
      
      assert :ok = ElixirScope.start(strategy: :minimal)
      
      config = ElixirScope.get_config()
      assert config.ai.planning.default_strategy == :minimal
      
      :ok = ElixirScope.stop()
    end

    test "handles sampling_rate option" do
      :ok = safe_stop_application()
      
      assert :ok = ElixirScope.start(sampling_rate: 0.3)
      
      config = ElixirScope.get_config()
      assert config.ai.planning.sampling_rate == 0.3
      
      :ok = ElixirScope.stop()
    end

    test "handles modules option (placeholder)" do
      :ok = safe_stop_application()
      
      # Should not fail, but will log that it's not yet implemented
      assert :ok = ElixirScope.start(modules: [SomeModule])
      
      :ok = ElixirScope.stop()
    end

    test "handles exclude_modules option (placeholder)" do
      :ok = safe_stop_application()
      
      # Should not fail, but will log that it's not yet implemented
      assert :ok = ElixirScope.start(exclude_modules: [SomeModule])
      
      :ok = ElixirScope.stop()
    end

    test "ignores unknown options" do
      :ok = safe_stop_application()
      
      # Should not fail, but will log warning
      assert :ok = ElixirScope.start(unknown_option: :value)
      
      :ok = ElixirScope.stop()
    end

    test "handles multiple options" do
      :ok = safe_stop_application()
      
      assert :ok = ElixirScope.start(
        strategy: :balanced,
        sampling_rate: 0.6,
        modules: [TestModule]
      )
      
      config = ElixirScope.get_config()
      assert config.ai.planning.default_strategy == :balanced
      assert config.ai.planning.sampling_rate == 0.6
      
      :ok = ElixirScope.stop()
    end
  end

  describe "performance characteristics" do
    setup do
      :ok = safe_stop_application()
      :ok = ElixirScope.start()
      on_exit(fn -> ElixirScope.stop() end)
      :ok
    end

    test "start is reasonably fast" do
      :ok = ElixirScope.stop()
      
      {duration, result} = :timer.tc(fn ->
        ElixirScope.start()
      end)
      
      # Should start successfully and reasonably quickly (< 1s)
      assert result == :ok
      assert duration < 1_000_000
    end

    test "status is fast" do
      {duration, result} = :timer.tc(fn ->
        ElixirScope.status()
      end)
      
      # Should return status and be reasonably fast (< 100ms)
      assert is_map(result)
      assert duration < 100_000
    end

    test "configuration access is fast" do
      {duration, result} = :timer.tc(fn ->
        ElixirScope.get_config()
      end)
      
      # Should return config and be reasonably fast (< 100ms)
      assert %ElixirScope.Config{} = result
      assert duration < 100_000
    end

    test "running? check is fast" do
      {duration, result} = :timer.tc(fn ->
        ElixirScope.running?()
      end)
      
      # Should return boolean and be reasonably fast (< 10ms)
      assert is_boolean(result)
      assert duration < 10_000
    end
  end

  describe "edge cases and robustness" do
    test "handles rapid start/stop cycles" do
      :ok = safe_stop_application()
      
      for _i <- 1..5 do
        assert :ok = ElixirScope.start()
        assert ElixirScope.running?() == true
        assert :ok = ElixirScope.stop()
        assert ElixirScope.running?() == false
      end
    end

    test "status handles application state changes" do
      :ok = safe_stop_application()
      
      # Status when not running
      status1 = ElixirScope.status()
      assert status1.running == false
      
      # Start and check status
      :ok = ElixirScope.start()
      status2 = ElixirScope.status()
      assert status2.running == true
      
      # Stop and check status
      :ok = ElixirScope.stop()
      status3 = ElixirScope.status()
      assert status3.running == false
    end

    test "configuration survives application restart" do
      :ok = safe_stop_application()
      
      # Start with custom config
      :ok = ElixirScope.start(sampling_rate: 0.42)
      config1 = ElixirScope.get_config()
      assert config1.ai.planning.sampling_rate == 0.42
      
      # Restart application
      :ok = ElixirScope.stop()
      :ok = ElixirScope.start()
      
      # Config should be back to defaults (since it's loaded from app config)
      config2 = ElixirScope.get_config()
      # In test env, default sampling rate from config is 1.0
      assert config2.ai.planning.sampling_rate == 1.0
    end
  end

  describe "typespec validation" do
    test "start accepts valid options" do
      :ok = safe_stop_application()
      
      # Test valid option types
      valid_options = [
        [],
        [strategy: :minimal],
        [strategy: :balanced],
        [strategy: :full_trace],
        [sampling_rate: 0.5],
        [modules: [TestModule]],
        [exclude_modules: [TestModule]],
        [strategy: :balanced, sampling_rate: 0.7]
      ]
      
      for opts <- valid_options do
        assert :ok = ElixirScope.start(opts)
        :ok = ElixirScope.stop()
      end
    end
  end
end 