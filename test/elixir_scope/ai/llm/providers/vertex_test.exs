defmodule ElixirScope.AI.LLM.Providers.VertexTest do
  use ExUnit.Case, async: false  # Not async because we modify env vars
  
  alias ElixirScope.AI.LLM.Providers.Vertex
  alias ElixirScope.AI.LLM.Response

  setup do
    # Store original env vars
    original_vertex_file = System.get_env("VERTEX_JSON_FILE")
    original_provider = System.get_env("LLM_PROVIDER")
    
    # Clear env vars for clean test state
    System.delete_env("VERTEX_JSON_FILE")
    System.delete_env("LLM_PROVIDER")
    
    on_exit(fn ->
      # Restore original env vars
      if original_vertex_file, do: System.put_env("VERTEX_JSON_FILE", original_vertex_file)
      if original_provider, do: System.put_env("LLM_PROVIDER", original_provider)
      
      # Clear any cached tokens
      Process.delete(:vertex_access_token)
    end)
    
    :ok
  end

  describe "provider_name/0" do
    test "returns :vertex" do
      assert Vertex.provider_name() == :vertex
    end
  end

  describe "configured?/0" do
    test "returns false when no credentials file is set" do
      assert Vertex.configured?() == false
    end

    test "returns false when credentials file doesn't exist" do
      System.put_env("VERTEX_JSON_FILE", "/nonexistent/file.json")
      assert Vertex.configured?() == false
    end

    test "returns false when credentials file has invalid JSON" do
      # Create a temporary file with invalid JSON
      temp_file = System.tmp_dir!() |> Path.join("invalid_vertex.json")
      File.write!(temp_file, "invalid json")
      
      try do
        System.put_env("VERTEX_JSON_FILE", temp_file)
        assert Vertex.configured?() == false
      after
        File.rm(temp_file)
      end
    end

    test "returns false when credentials file is missing required keys" do
      # Create a temporary file with incomplete credentials
      temp_file = System.tmp_dir!() |> Path.join("incomplete_vertex.json")
      incomplete_creds = %{
        "type" => "service_account",
        "project_id" => "test-project"
        # Missing private_key and client_email
      }
      File.write!(temp_file, Jason.encode!(incomplete_creds))
      
      try do
        System.put_env("VERTEX_JSON_FILE", temp_file)
        assert Vertex.configured?() == false
      after
        File.rm(temp_file)
      end
    end

    test "returns true when credentials file has all required keys" do
      # Create a temporary file with complete credentials
      temp_file = System.tmp_dir!() |> Path.join("complete_vertex.json")
      complete_creds = %{
        "type" => "service_account",
        "project_id" => "test-project",
        "private_key" => "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----\n",
        "client_email" => "test@test-project.iam.gserviceaccount.com"
      }
      File.write!(temp_file, Jason.encode!(complete_creds))
      
      try do
        System.put_env("VERTEX_JSON_FILE", temp_file)
        assert Vertex.configured?() == true
      after
        File.rm(temp_file)
      end
    end
  end

  describe "analyze_code/2 without credentials" do
    test "returns error response when not configured" do
      response = Vertex.analyze_code("def hello, do: :world", %{})
      
      assert %Response{} = response
      assert response.success == false
      assert response.provider == :vertex
      assert response.confidence == 0.0
      assert response.text == ""
      assert String.contains?(response.error, "authenticate")
      assert response.metadata.analysis_type == "code_analysis"
      assert response.metadata.error_type == :authentication_failed
    end
  end

  describe "explain_error/2 without credentials" do
    test "returns error response when not configured" do
      response = Vertex.explain_error("undefined function foo/0", %{})
      
      assert %Response{} = response
      assert response.success == false
      assert response.provider == :vertex
      assert response.confidence == 0.0
      assert response.text == ""
      assert String.contains?(response.error, "authenticate")
      assert response.metadata.analysis_type == "error_explanation"
      assert response.metadata.error_type == :authentication_failed
    end
  end

  describe "suggest_fix/2 without credentials" do
    test "returns error response when not configured" do
      response = Vertex.suggest_fix("function is too complex", %{})
      
      assert %Response{} = response
      assert response.success == false
      assert response.provider == :vertex
      assert response.confidence == 0.0
      assert response.text == ""
      assert String.contains?(response.error, "authenticate")
      assert response.metadata.analysis_type == "fix_suggestion"
      assert response.metadata.error_type == :authentication_failed
    end
  end

  describe "test_connection/0" do
    test "returns error response when not configured" do
      response = Vertex.test_connection()
      
      assert %Response{} = response
      assert response.success == false
      assert response.provider == :vertex
      assert String.contains?(response.error, "authenticate")
    end
  end

  describe "response format consistency" do
    test "all methods return consistent Response structure" do
      responses = [
        Vertex.analyze_code("def test, do: :ok", %{}),
        Vertex.explain_error("error message", %{}),
        Vertex.suggest_fix("problem description", %{}),
        Vertex.test_connection()
      ]
      
      Enum.each(responses, fn response ->
        assert %Response{} = response
        assert is_boolean(response.success)
        assert response.provider == :vertex
        assert is_binary(response.text)
        assert is_binary(response.error) or response.error == nil
        assert is_map(response.metadata)
        assert %DateTime{} = response.timestamp
        assert is_float(response.confidence)
      end)
    end
  end

  describe "error handling" do
    test "handles empty input gracefully" do
      response = Vertex.analyze_code("", %{})
      
      assert %Response{} = response
      assert response.success == false
      assert response.provider == :vertex
    end

    test "handles nil context gracefully" do
      # This should not crash, even though we pass nil instead of a map
      response = Vertex.analyze_code("def test, do: :ok", nil)
      
      assert %Response{} = response
      assert response.success == false
      assert response.provider == :vertex
    end

    test "handles large input gracefully" do
      large_code = String.duplicate("def test_func, do: :ok\n", 1000)
      response = Vertex.analyze_code(large_code, %{})
      
      assert %Response{} = response
      assert response.success == false  # Will fail due to no credentials
      assert response.provider == :vertex
    end

    test "handles special characters in input" do
      special_code = "def test, do: \"Special chars: ñáéíóú 中文 🚀\""
      response = Vertex.analyze_code(special_code, %{})
      
      assert %Response{} = response
      assert response.success == false  # Will fail due to no credentials
      assert response.provider == :vertex
    end
  end
end 