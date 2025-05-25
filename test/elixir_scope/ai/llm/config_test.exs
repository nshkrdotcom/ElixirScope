defmodule ElixirScope.AI.LLM.ConfigTest do
  use ExUnit.Case, async: false  # Not async because we modify env vars
  
  alias ElixirScope.AI.LLM.Config

  setup do
    # Store original env vars
    original_gemini_key = System.get_env("GEMINI_API_KEY")
    original_vertex_file = System.get_env("VERTEX_JSON_FILE")
    original_provider = System.get_env("LLM_PROVIDER")
    original_base_url = System.get_env("GEMINI_BASE_URL")
    original_vertex_base_url = System.get_env("VERTEX_BASE_URL")
    original_model = System.get_env("GEMINI_MODEL")
    original_vertex_model = System.get_env("VERTEX_MODEL")
    original_timeout = System.get_env("LLM_TIMEOUT")
    
    # Clear env vars for clean test state
    System.delete_env("GEMINI_API_KEY")
    System.delete_env("VERTEX_JSON_FILE")
    System.delete_env("LLM_PROVIDER")
    System.delete_env("GEMINI_BASE_URL")
    System.delete_env("VERTEX_BASE_URL")
    System.delete_env("GEMINI_MODEL")
    System.delete_env("GEMINI_DEFAULT_MODEL")
    System.delete_env("VERTEX_MODEL")
    System.delete_env("VERTEX_DEFAULT_MODEL")
    System.delete_env("LLM_TIMEOUT")
    
    # Clear application config
    Application.delete_env(:elixir_scope, :gemini_api_key)
    Application.delete_env(:elixir_scope, :vertex_json_file)
    Application.delete_env(:elixir_scope, :llm_provider)
    Application.delete_env(:elixir_scope, :gemini_base_url)
    Application.delete_env(:elixir_scope, :vertex_base_url)
    Application.delete_env(:elixir_scope, :gemini_model)
    Application.delete_env(:elixir_scope, :vertex_model)
    Application.delete_env(:elixir_scope, :llm_timeout)
    
    on_exit(fn ->
      # Restore original env vars
      if original_gemini_key, do: System.put_env("GEMINI_API_KEY", original_gemini_key)
      if original_vertex_file, do: System.put_env("VERTEX_JSON_FILE", original_vertex_file)
      if original_provider, do: System.put_env("LLM_PROVIDER", original_provider)
      if original_base_url, do: System.put_env("GEMINI_BASE_URL", original_base_url)
      if original_vertex_base_url, do: System.put_env("VERTEX_BASE_URL", original_vertex_base_url)
      if original_model, do: System.put_env("GEMINI_MODEL", original_model)
      if original_vertex_model, do: System.put_env("VERTEX_MODEL", original_vertex_model)
      if original_timeout, do: System.put_env("LLM_TIMEOUT", original_timeout)
      
      # Clear application config
      Application.delete_env(:elixir_scope, :gemini_api_key)
      Application.delete_env(:elixir_scope, :vertex_json_file)
      Application.delete_env(:elixir_scope, :llm_provider)
      Application.delete_env(:elixir_scope, :gemini_base_url)
      Application.delete_env(:elixir_scope, :vertex_base_url)
      Application.delete_env(:elixir_scope, :gemini_model)
      Application.delete_env(:elixir_scope, :vertex_model)
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
    test "returns :mock when no API key or credentials are available" do
      assert Config.get_primary_provider() == :mock
    end

    test "returns :gemini when API key is available and provider is explicitly set" do
      System.put_env("GEMINI_API_KEY", "test-key")
      System.put_env("LLM_PROVIDER", "gemini")
      assert Config.get_primary_provider() == :gemini
    end

    test "returns :vertex when credentials are available and provider is explicitly set" do
      temp_file = System.tmp_dir!() |> Path.join("vertex_creds.json")
      credentials = %{
        "type" => "service_account",
        "project_id" => "test-project",
        "private_key" => "test-key",
        "client_email" => "test@test-project.iam.gserviceaccount.com"
      }
      File.write!(temp_file, Jason.encode!(credentials))
      
      try do
        System.put_env("VERTEX_JSON_FILE", temp_file)
        System.put_env("LLM_PROVIDER", "vertex")
        assert Config.get_primary_provider() == :vertex
      after
        File.rm(temp_file)
      end
    end

    test "returns :vertex when both vertex and gemini are available and vertex is explicitly set" do
      temp_file = System.tmp_dir!() |> Path.join("vertex_creds.json")
      credentials = %{
        "type" => "service_account",
        "project_id" => "test-project",
        "private_key" => "test-key",
        "client_email" => "test@test-project.iam.gserviceaccount.com"
      }
      File.write!(temp_file, Jason.encode!(credentials))
      
      try do
        System.put_env("VERTEX_JSON_FILE", temp_file)
        System.put_env("GEMINI_API_KEY", "test-key")
        System.put_env("LLM_PROVIDER", "vertex")
        assert Config.get_primary_provider() == :vertex
      after
        File.rm(temp_file)
      end
    end

    test "respects explicit provider configuration" do
      System.put_env("GEMINI_API_KEY", "test-key")
      System.put_env("LLM_PROVIDER", "mock")
      assert Config.get_primary_provider() == :mock
    end

    test "returns :vertex when LLM_PROVIDER is set to vertex" do
      System.put_env("LLM_PROVIDER", "vertex")
      assert Config.get_primary_provider() == :vertex
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
      assert Config.get_gemini_model() == "gemini-2.0-flash"
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

    test "returns false for :vertex when no credentials" do
      assert Config.valid_config?(:vertex) == false
    end

    test "returns true for :vertex when credentials are present" do
      temp_file = System.tmp_dir!() |> Path.join("vertex_creds.json")
      credentials = %{
        "type" => "service_account",
        "project_id" => "test-project",
        "private_key" => "test-key",
        "client_email" => "test@test-project.iam.gserviceaccount.com"
      }
      File.write!(temp_file, Jason.encode!(credentials))
      
      try do
        System.put_env("VERTEX_JSON_FILE", temp_file)
        assert Config.valid_config?(:vertex) == true
      after
        File.rm(temp_file)
      end
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
      System.put_env("LLM_PROVIDER", "gemini")
      
      config = Config.debug_config()
      
      assert config.primary_provider == :gemini
      assert config.fallback_provider == :mock
      assert config.gemini_api_key_present == true
      assert config.gemini_base_url == "https://generativelanguage.googleapis.com"
      assert config.gemini_model == "gemini-2.0-flash"
      assert config.vertex_credentials_present == false
      assert config.request_timeout == 30_000
      
      # Ensure the actual API key is not exposed
      refute Map.has_key?(config, :gemini_api_key)
      refute Map.has_key?(config, :vertex_credentials)
    end

    test "shows API key as not present when not configured" do
      config = Config.debug_config()
      assert config.gemini_api_key_present == false
      assert config.vertex_credentials_present == false
    end

    test "shows vertex credentials as present when configured" do
      temp_file = System.tmp_dir!() |> Path.join("vertex_creds.json")
      credentials = %{
        "type" => "service_account",
        "project_id" => "test-project",
        "private_key" => "test-key",
        "client_email" => "test@test-project.iam.gserviceaccount.com"
      }
      File.write!(temp_file, Jason.encode!(credentials))
      
      try do
        System.put_env("VERTEX_JSON_FILE", temp_file)
        System.put_env("LLM_PROVIDER", "vertex")
        
        config = Config.debug_config()
        
        assert config.primary_provider == :vertex
        assert config.vertex_credentials_present == true
        assert String.contains?(config.vertex_base_url, "test-project")
        assert config.vertex_model == "gemini-2.0-flash"
        
        # Ensure credentials are not exposed
        refute Map.has_key?(config, :vertex_credentials)
      after
        File.rm(temp_file)
      end
    end
  end

  describe "get_vertex_json_file/0" do
    test "returns nil when no file is configured" do
      assert Config.get_vertex_json_file() == nil
    end

    test "returns value from environment variable" do
      System.put_env("VERTEX_JSON_FILE", "/path/to/vertex.json")
      assert Config.get_vertex_json_file() == "/path/to/vertex.json"
    end

    test "returns value from application config" do
      Application.put_env(:elixir_scope, :vertex_json_file, "/app/config/vertex.json")
      assert Config.get_vertex_json_file() == "/app/config/vertex.json"
    end

    test "environment variable takes precedence over application config" do
      Application.put_env(:elixir_scope, :vertex_json_file, "/app/config/vertex.json")
      System.put_env("VERTEX_JSON_FILE", "/env/vertex.json")
      assert Config.get_vertex_json_file() == "/env/vertex.json"
    end
  end

  describe "get_vertex_credentials/0" do
    test "returns nil when no file is configured" do
      assert Config.get_vertex_credentials() == nil
    end

    test "returns nil when file doesn't exist" do
      System.put_env("VERTEX_JSON_FILE", "/nonexistent/file.json")
      assert Config.get_vertex_credentials() == nil
    end

    test "returns nil when file has invalid JSON" do
      temp_file = System.tmp_dir!() |> Path.join("invalid_vertex.json")
      File.write!(temp_file, "invalid json")
      
      try do
        System.put_env("VERTEX_JSON_FILE", temp_file)
        assert Config.get_vertex_credentials() == nil
      after
        File.rm(temp_file)
      end
    end

    test "returns parsed credentials when file is valid" do
      temp_file = System.tmp_dir!() |> Path.join("valid_vertex.json")
      credentials = %{
        "type" => "service_account",
        "project_id" => "test-project",
        "private_key" => "test-key",
        "client_email" => "test@test-project.iam.gserviceaccount.com"
      }
      File.write!(temp_file, Jason.encode!(credentials))
      
      try do
        System.put_env("VERTEX_JSON_FILE", temp_file)
        assert Config.get_vertex_credentials() == credentials
      after
        File.rm(temp_file)
      end
    end
  end

  describe "get_vertex_base_url/0" do
    test "returns default URL when no credentials are available" do
      url = Config.get_vertex_base_url()
      assert String.contains?(url, "aiplatform.googleapis.com")
      assert String.contains?(url, "PROJECT_ID")
    end

    test "returns URL with project ID when credentials are available" do
      temp_file = System.tmp_dir!() |> Path.join("vertex_with_project.json")
      credentials = %{
        "type" => "service_account",
        "project_id" => "my-test-project",
        "private_key" => "test-key",
        "client_email" => "test@my-test-project.iam.gserviceaccount.com"
      }
      File.write!(temp_file, Jason.encode!(credentials))
      
      try do
        System.put_env("VERTEX_JSON_FILE", temp_file)
        url = Config.get_vertex_base_url()
        assert String.contains?(url, "my-test-project")
        assert String.contains?(url, "aiplatform.googleapis.com")
        refute String.contains?(url, "PROJECT_ID")
      after
        File.rm(temp_file)
      end
    end
  end

  describe "get_vertex_model/0" do
    test "returns default model when no configuration is set" do
      assert Config.get_vertex_model() == "gemini-2.0-flash"
    end

    test "returns value from VERTEX_DEFAULT_MODEL environment variable" do
      System.put_env("VERTEX_DEFAULT_MODEL", "gemini-1.5-pro")
      assert Config.get_vertex_model() == "gemini-1.5-pro"
    end

    test "returns value from VERTEX_MODEL environment variable" do
      System.put_env("VERTEX_MODEL", "gemini-1.0-pro")
      assert Config.get_vertex_model() == "gemini-1.0-pro"
    end

    test "returns value from application config" do
      Application.put_env(:elixir_scope, :vertex_model, "custom-model")
      assert Config.get_vertex_model() == "custom-model"
    end

    test "environment variables take precedence over application config" do
      Application.put_env(:elixir_scope, :vertex_model, "app-model")
      System.put_env("VERTEX_DEFAULT_MODEL", "env-model")
      assert Config.get_vertex_model() == "env-model"
    end

    test "VERTEX_MODEL takes precedence over VERTEX_DEFAULT_MODEL" do
      System.put_env("VERTEX_DEFAULT_MODEL", "default-model")
      System.put_env("VERTEX_MODEL", "specific-model")
      assert Config.get_vertex_model() == "specific-model"
    end
  end
end 