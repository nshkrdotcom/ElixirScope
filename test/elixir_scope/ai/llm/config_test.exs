defmodule ElixirScope.AI.LLM.ConfigTest do
  use ExUnit.Case, async: false  # Not async because we modify env vars
  
  alias ElixirScope.AI.LLM.Config

  setup do
    # Store original env vars
    original_gemini_key = System.get_env("GEMINI_API_KEY")
    original_provider = System.get_env("LLM_PROVIDER")
    original_base_url = System.get_env("GEMINI_BASE_URL")
    original_model = System.get_env("GEMINI_MODEL")
    original_timeout = System.get_env("LLM_TIMEOUT")
    
    # Clear env vars for clean test state
    System.delete_env("GEMINI_API_KEY")
    System.delete_env("LLM_PROVIDER")
    System.delete_env("GEMINI_BASE_URL")
    System.delete_env("GEMINI_MODEL")
    System.delete_env("GEMINI_DEFAULT_MODEL")
    System.delete_env("LLM_TIMEOUT")
    
    # Clear application config
    Application.delete_env(:elixir_scope, :gemini_api_key)
    Application.delete_env(:elixir_scope, :llm_provider)
    Application.delete_env(:elixir_scope, :llm_timeout)
    
    on_exit(fn ->
      # Always clear env vars first to prevent leakage
      System.delete_env("GEMINI_API_KEY")
      System.delete_env("LLM_PROVIDER")
      System.delete_env("GEMINI_BASE_URL")
      System.delete_env("GEMINI_MODEL")
      System.delete_env("GEMINI_DEFAULT_MODEL")
      System.delete_env("LLM_TIMEOUT")
      
      # Then restore original env vars if they existed
      if original_gemini_key, do: System.put_env("GEMINI_API_KEY", original_gemini_key)
      if original_provider, do: System.put_env("LLM_PROVIDER", original_provider)
      if original_base_url, do: System.put_env("GEMINI_BASE_URL", original_base_url)
      if original_model, do: System.put_env("GEMINI_MODEL", original_model)
      if original_timeout, do: System.put_env("LLM_TIMEOUT", original_timeout)
      
      # Clear application config
      Application.delete_env(:elixir_scope, :gemini_api_key)
      Application.delete_env(:elixir_scope, :llm_provider)
      Application.delete_env(:elixir_scope, :llm_timeout)
    end)
    
    :ok
  end

  describe "get_gemini_api_key/0" do
    test "returns nil when no API key is configured" do
      assert Config.get_gemini_api_key() == nil
    end

    test "returns API key from environment variable" do
      System.put_env("GEMINI_API_KEY", "test-key-123")
      assert Config.get_gemini_api_key() == "test-key-123"
    end

    test "returns API key from application config" do
      Application.put_env(:elixir_scope, :gemini_api_key, "app-config-key")
      assert Config.get_gemini_api_key() == "app-config-key"
      Application.delete_env(:elixir_scope, :gemini_api_key)
    end

    test "application config takes precedence over environment" do
      System.put_env("GEMINI_API_KEY", "env-key")
      Application.put_env(:elixir_scope, :gemini_api_key, "app-key")
      
      assert Config.get_gemini_api_key() == "app-key"
      
      Application.delete_env(:elixir_scope, :gemini_api_key)
    end
  end

  describe "get_primary_provider/0" do
    test "returns :mock when no API key is available" do
      assert Config.get_primary_provider() == :mock
    end

    test "returns :gemini when API key is available" do
      System.put_env("GEMINI_API_KEY", "test-key")
      assert Config.get_primary_provider() == :gemini
    end

    test "respects explicit provider configuration" do
      System.put_env("GEMINI_API_KEY", "test-key")
      System.put_env("LLM_PROVIDER", "mock")
      assert Config.get_primary_provider() == :mock
    end

    test "falls back to mock for unknown provider" do
      System.put_env("LLM_PROVIDER", "unknown")
      assert Config.get_primary_provider() == :mock
    end
  end

  describe "get_fallback_provider/0" do
    test "always returns :mock" do
      assert Config.get_fallback_provider() == :mock
    end
  end

  describe "get_gemini_base_url/0" do
    test "returns default URL when not configured" do
      assert Config.get_gemini_base_url() == "https://generativelanguage.googleapis.com"
    end

    test "returns custom URL from environment" do
      System.put_env("GEMINI_BASE_URL", "https://custom.api.com")
      assert Config.get_gemini_base_url() == "https://custom.api.com"
    end
  end

  describe "get_gemini_model/0" do
    test "returns default model when not configured" do
      assert Config.get_gemini_model() == "gemini-1.5-flash"
    end

    test "returns custom model from GEMINI_DEFAULT_MODEL environment" do
      System.put_env("GEMINI_DEFAULT_MODEL", "gemini-1.5-pro")
      assert Config.get_gemini_model() == "gemini-1.5-pro"
    end

    test "returns custom model from GEMINI_MODEL environment" do
      System.put_env("GEMINI_MODEL", "gemini-pro")
      assert Config.get_gemini_model() == "gemini-pro"
    end

    test "GEMINI_DEFAULT_MODEL takes precedence over GEMINI_MODEL" do
      System.put_env("GEMINI_DEFAULT_MODEL", "gemini-1.5-pro")
      System.put_env("GEMINI_MODEL", "gemini-pro")
      assert Config.get_gemini_model() == "gemini-1.5-pro"
    end
  end

  describe "get_request_timeout/0" do
    test "returns default timeout when not configured" do
      assert Config.get_request_timeout() == 30_000
    end

    test "returns custom timeout from environment as string" do
      System.put_env("LLM_TIMEOUT", "60000")
      assert Config.get_request_timeout() == 60_000
    end

    test "returns custom timeout from application config" do
      Application.put_env(:elixir_scope, :llm_timeout, 45_000)
      assert Config.get_request_timeout() == 45_000
      Application.delete_env(:elixir_scope, :llm_timeout)
    end
  end

  describe "valid_config?/1" do
    test "returns false for :gemini when no API key" do
      assert Config.valid_config?(:gemini) == false
    end

    test "returns true for :gemini when API key is present" do
      System.put_env("GEMINI_API_KEY", "test-key")
      assert Config.valid_config?(:gemini) == true
    end

    test "returns true for :mock always" do
      assert Config.valid_config?(:mock) == true
    end

    test "returns false for unknown providers" do
      assert Config.valid_config?(:unknown) == false
    end
  end

  describe "debug_config/0" do
    test "returns configuration map without exposing API key" do
      System.put_env("GEMINI_API_KEY", "secret-key")
      
      config = Config.debug_config()
      
      assert config.primary_provider == :gemini
      assert config.fallback_provider == :mock
      assert config.gemini_api_key_present == true
      assert config.gemini_base_url == "https://generativelanguage.googleapis.com"
      assert config.gemini_model == "gemini-1.5-flash"
      assert config.request_timeout == 30_000
      
      # Ensure the actual API key is not exposed
      refute Map.has_key?(config, :gemini_api_key)
    end

    test "shows API key as not present when not configured" do
      config = Config.debug_config()
      assert config.gemini_api_key_present == false
    end
  end
end 