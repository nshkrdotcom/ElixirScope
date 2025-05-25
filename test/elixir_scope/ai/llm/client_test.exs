defmodule ElixirScope.AI.LLM.ClientTest do
  use ExUnit.Case, async: false  # Not async because we modify env vars
  
  alias ElixirScope.AI.LLM.{Client, Response}

  setup do
    # Store original env vars
    original_gemini_key = System.get_env("GEMINI_API_KEY")
    original_vertex_file = System.get_env("VERTEX_JSON_FILE")
    original_provider = System.get_env("LLM_PROVIDER")
    
    # Clear env vars for clean test state
    System.delete_env("GEMINI_API_KEY")
    System.delete_env("VERTEX_JSON_FILE")
    System.delete_env("LLM_PROVIDER")
    
    # Clear application config
    Application.delete_env(:elixir_scope, :gemini_api_key)
    Application.delete_env(:elixir_scope, :vertex_json_file)
    Application.delete_env(:elixir_scope, :llm_provider)
    
    on_exit(fn ->
      # Restore original env vars
      if original_gemini_key, do: System.put_env("GEMINI_API_KEY", original_gemini_key)
      if original_vertex_file, do: System.put_env("VERTEX_JSON_FILE", original_vertex_file)
      if original_provider, do: System.put_env("LLM_PROVIDER", original_provider)
      
      # Clear application config
      Application.delete_env(:elixir_scope, :gemini_api_key)
      Application.delete_env(:elixir_scope, :vertex_json_file)
      Application.delete_env(:elixir_scope, :llm_provider)
    end)
    
    :ok
  end

  describe "analyze_code/2" do
    test "uses mock provider when no Gemini API key" do
      response = Client.analyze_code("def hello, do: :world")
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :mock
      assert String.contains?(response.text, "Mock Provider")
    end

    test "includes context in analysis" do
      context = %{complexity: 5, issues: ["too_long"]}
      response = Client.analyze_code("def test, do: :ok", context)
      
      assert response.success == true
      assert response.provider == :mock
      assert String.contains?(response.text, "Context Analysis")
    end
  end

  describe "explain_error/2" do
    test "uses mock provider when no Gemini API key" do
      response = Client.explain_error("undefined function foo/0")
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :mock
      assert String.contains?(response.text, "Mock Provider")
    end

    test "includes context in explanation" do
      context = %{function: "test_func", line: 42}
      response = Client.explain_error("timeout error", context)
      
      assert response.success == true
      assert response.provider == :mock
      assert String.contains?(response.text, "Contextual Insights")
    end
  end

  describe "suggest_fix/2" do
    test "uses mock provider when no Gemini API key" do
      response = Client.suggest_fix("function is too complex")
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :mock
      assert String.contains?(response.text, "Mock Provider")
    end

    test "includes context in suggestions" do
      context = %{module: "TestModule", complexity: 10}
      response = Client.suggest_fix("performance issue", context)
      
      assert response.success == true
      assert response.provider == :mock
      assert String.contains?(response.text, "Context-Specific")
    end
  end

  describe "get_provider_status/0" do
    test "returns correct status when no API key configured" do
      status = Client.get_provider_status()
      
      assert status.primary_provider == :mock
      assert status.fallback_provider == :mock
      assert status.gemini_configured == false
      assert status.vertex_configured == false
      assert status.mock_available == true
    end

    test "returns correct status when Gemini API key is configured" do
      System.put_env("GEMINI_API_KEY", "test-key")
      System.put_env("LLM_PROVIDER", "gemini")  # Explicitly set provider in test
      
      status = Client.get_provider_status()
      
      assert status.primary_provider == :gemini
      assert status.fallback_provider == :mock
      assert status.gemini_configured == true
      assert status.vertex_configured == false
      assert status.mock_available == true
    end
  end

  describe "test_connection/0" do
    test "tests mock provider when no API key" do
      response = Client.test_connection()
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :mock
      assert String.contains?(response.text, "Mock Provider")
    end

    @tag :live_api
    test "attempts Gemini when API key is configured" do
      System.put_env("GEMINI_API_KEY", "test-key")
      System.put_env("LLM_PROVIDER", "gemini")  # Explicitly set provider in test
      
      # This will fail because we don't have a real API key, but should attempt Gemini
      response = Client.test_connection()
      
      # Should fallback to mock since Gemini will fail
      assert %Response{} = response
      assert response.metadata[:fallback_used] == true || response.provider == :mock
    end
  end

  describe "provider fallback" do
    @tag :live_api
    test "falls back to mock when Gemini fails" do
      # Force Gemini as primary but it will fail without real API key
      System.put_env("GEMINI_API_KEY", "invalid-key")
      System.put_env("LLM_PROVIDER", "gemini")  # Explicitly set provider in test
      
      response = Client.analyze_code("def test, do: :ok")
      
      # Should either be mock provider or have fallback_used metadata
      assert response.provider == :mock || response.metadata[:fallback_used] == true
    end
  end
end 