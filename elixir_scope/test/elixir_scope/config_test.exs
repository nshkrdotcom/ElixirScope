defmodule ElixirScope.ConfigTest do
  use ExUnit.Case, async: true # Enable async for faster tests
  alias ElixirScope.Config

  # Helper to temporarily set and then restore application environment variables
  defp with_env_vars(vars, fun) do
    # Store original values for the keys we are about to change
    original_vars_to_restore =
      Enum.map(vars, fn {key, _value} ->
        {key, Application.get_env(:elixir_scope, key)}
      end)

    # Set the new values for the test
    Enum.each(vars, fn {key, value} ->
      Application.put_env(:elixir_scope, key, value)
    end)

    try do
      fun.()
    after
      # Restore original values
      Enum.each(original_vars_to_restore, fn {key, value} ->
        if is_nil(value) do
          # If the original value was nil (meaning key was not set or explicitly set to nil),
          # delete the key to truly restore the previous state.
          Application.delete_env(:elixir_scope, key)
        else
          Application.put_env(:elixir_scope, key, value)
        end
      end)
    end
  end

  describe "ElixirScope.Config" do
    test "helper functions return module-defined defaults when no override is set" do
      assert Config.ai_backend_url() == "http://localhost:8080/v1/chat/completions"
      assert Config.max_trace_events() == 1_000_000
      assert Config.default_log_level() == :info
    end

    test "get/2 returns nil if key is not set and no default is provided to get/2" do
      # Ensure these keys are not accidentally set by other tests or configs
      Application.delete_env(:elixir_scope, :ai_backend_url)
      Application.delete_env(:elixir_scope, :max_trace_events)
      Application.delete_env(:elixir_scope, :default_log_level)
      Application.delete_env(:elixir_scope, :non_existent_key_for_get_test)


      assert Config.get(:ai_backend_url) == nil
      assert Config.get(:max_trace_events) == nil
      assert Config.get(:default_log_level) == nil
      assert Config.get(:non_existent_key_for_get_test) == nil
    end

    test "get/2 returns the specific default_value passed to it if key is not set" do
      Application.delete_env(:elixir_scope, :non_existent_key_for_default_test)
      assert Config.get(:non_existent_key_for_default_test, "my_specific_default") == "my_specific_default"
      assert Config.get(:non_existent_key_for_default_test, :some_atom_default) == :some_atom_default
    end

    test "helper functions return overridden values when set via Application.put_env/3" do
      with_env_vars([ai_backend_url: "http://new-ai-backend.com/api"], fn ->
        assert Config.ai_backend_url() == "http://new-ai-backend.com/api"
        assert Config.get(:ai_backend_url) == "http://new-ai-backend.com/api" # Also check get/2
      end)

      with_env_vars([max_trace_events: 500], fn ->
        assert Config.max_trace_events() == 500
        assert Config.get(:max_trace_events) == 500
      end)

      with_env_vars([default_log_level: :debug], fn ->
        assert Config.default_log_level() == :debug
        assert Config.get(:default_log_level) == :debug
      end)
    end

    test "get/2 retrieves overridden value for a custom key" do
      with_env_vars([custom_key: "custom_value"], fn ->
        assert Config.get(:custom_key) == "custom_value"
      end)
    end

    test "get/2 retrieves overridden value even if a default is specified (override takes precedence)" do
      with_env_vars([custom_key_with_default: "overridden_value"], fn ->
        assert Config.get(:custom_key_with_default, "default_for_custom") == "overridden_value"
      end)
    end
  end
end
