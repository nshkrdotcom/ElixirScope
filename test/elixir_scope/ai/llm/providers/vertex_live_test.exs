defmodule ElixirScope.AI.LLM.Providers.VertexLiveTest do
  @moduledoc """
  Live integration tests for the Vertex provider.
  
  These tests make actual API calls to Google's Vertex AI service and require:
  1. VERTEX_JSON_FILE environment variable pointing to a valid service account JSON file
  2. Internet connectivity
  3. Valid Vertex AI API quota
  
  To run these tests separately:
  
      # Run only live Vertex tests
      mix test test/elixir_scope/ai/llm/providers/vertex_live_test.exs
      
      # Run with specific tag
      mix test --only live_api
      
      # Skip live tests during regular test runs
      mix test --exclude live_api
  """
  
  use ExUnit.Case, async: false
  
  alias ElixirScope.AI.LLM.Providers.Vertex
  alias ElixirScope.AI.LLM.Response

  @moduletag :live_api
  @moduletag timeout: 30_000  # 30 second timeout for API calls

  setup_all do
    case System.get_env("VERTEX_JSON_FILE") do
      nil ->
        {:skip, "VERTEX_JSON_FILE environment variable not set"}
      
      file_path ->
        case File.exists?(file_path) do
          false ->
            {:skip, "VERTEX_JSON_FILE points to non-existent file: #{file_path}"}
          
          true ->
            case File.read(file_path) do
              {:ok, content} ->
                case Jason.decode(content) do
                  {:ok, credentials} ->
                    required_keys = ["type", "project_id", "private_key", "client_email"]
                    missing_keys = Enum.filter(required_keys, &(not Map.has_key?(credentials, &1)))
                    
                    if Enum.empty?(missing_keys) do
                      # Ensure we're using the real Vertex API URL, not any test overrides
                      System.delete_env("VERTEX_BASE_URL")
                      System.delete_env("VERTEX_MODEL")
                      System.delete_env("VERTEX_DEFAULT_MODEL")
                      :ok
                    else
                      {:skip, "VERTEX_JSON_FILE missing required keys: #{inspect(missing_keys)}"}
                    end
                  
                  {:error, error} ->
                    {:skip, "VERTEX_JSON_FILE contains invalid JSON: #{inspect(error)}"}
                end
              
              {:error, error} ->
                {:skip, "Cannot read VERTEX_JSON_FILE: #{inspect(error)}"}
            end
        end
    end
  end

  setup do
    # Global lock to ensure live API tests run sequentially across all test files
    # This prevents rate limiting when running the full test suite
    :global.set_lock({:vertex_live_test_lock, self()}, [node()], :infinity)
    
    # Add a small delay between tests to avoid rate limiting
    # Only add delay if this is not the first test
    if Process.get(:vertex_test_count, 0) > 0 do
      :timer.sleep(2000)  # 2 seconds delay between tests
    end
    Process.put(:vertex_test_count, Process.get(:vertex_test_count, 0) + 1)
    
    on_exit(fn ->
      # Release the global lock when test completes
      :global.del_lock({:vertex_live_test_lock, self()}, [node()])
    end)
    
    :ok
  end

  describe "Live Vertex AI Integration" do
    @tag :live_api
    test "provider_name/0 returns :vertex" do
      assert Vertex.provider_name() == :vertex
    end

    @tag :live_api
    test "configured?/0 returns true when credentials are set" do
      assert Vertex.configured?() == true
    end

    @tag :live_api
    test "analyze_code/2 makes successful API call" do
      code = """
      defmodule Calculator do
        def add(a, b), do: a + b
        def multiply(a, b), do: a * b
      end
      """
      
      context = %{
        file: "calculator.ex",
        purpose: "Simple arithmetic operations"
      }

      response = Vertex.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :vertex
      assert is_binary(response.text)
      assert String.length(response.text) > 50  # Should be a substantial response
      assert is_map(response.metadata)
      assert response.metadata.analysis_type == "code_analysis"
      
      # Response should contain relevant analysis terms
      text_lower = String.downcase(response.text)
      assert String.contains?(text_lower, "function") or 
             String.contains?(text_lower, "module") or
             String.contains?(text_lower, "code")
    end

    @tag :live_api
    test "explain_error/2 makes successful API call" do
      error_message = """
      ** (CompileError) lib/calculator.ex:3: undefined function subtract/2
      """
      
      context = %{
        file: "calculator.ex",
        line: 3,
        attempted_function: "subtract/2"
      }

      response = Vertex.explain_error(error_message, context)
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :vertex
      assert is_binary(response.text)
      assert String.length(response.text) > 30
      assert response.metadata.analysis_type == "error_explanation"
      
      # Response should contain error-related terms
      text_lower = String.downcase(response.text)
      assert String.contains?(text_lower, "undefined") or
             String.contains?(text_lower, "function") or
             String.contains?(text_lower, "error")
    end

    @tag :live_api
    test "suggest_fix/2 makes successful API call" do
      problem = """
      My Elixir function is too complex and hard to read. It has nested case statements
      and multiple responsibilities.
      """
      
      context = %{
        complexity_score: 8,
        function_name: "process_data",
        suggestions_needed: ["refactoring", "readability"]
      }

      response = Vertex.suggest_fix(problem, context)
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :vertex
      assert is_binary(response.text)
      assert String.length(response.text) > 50
      assert response.metadata.analysis_type == "fix_suggestion"
      
      # Response should contain fix-related terms
      text_lower = String.downcase(response.text)
      assert String.contains?(text_lower, "refactor") or
             String.contains?(text_lower, "improve") or
             String.contains?(text_lower, "simplify") or
             String.contains?(text_lower, "extract")
    end

    @tag :live_api
    test "test_connection/0 works with live API" do
      response = Vertex.test_connection()
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :vertex
      assert is_binary(response.text)
    end

    @tag :live_api
    test "handles different Vertex models via VERTEX_DEFAULT_MODEL" do
      # Test that the provider respects the VERTEX_DEFAULT_MODEL env var
      original_model = System.get_env("VERTEX_DEFAULT_MODEL")
      
      try do
        # Set a valid model that should work
        System.put_env("VERTEX_DEFAULT_MODEL", "gemini-2.0-flash")
        
        response = Vertex.analyze_code("def hello, do: :world", %{})
        
        assert %Response{} = response
        assert response.success == true
        assert response.provider == :vertex
        
      after
        # Restore original model setting
        if original_model do
          System.put_env("VERTEX_DEFAULT_MODEL", original_model)
        else
          System.delete_env("VERTEX_DEFAULT_MODEL")
        end
      end
    end

    @tag :live_api
    test "handles API errors gracefully" do
      # Test with invalid credentials to ensure error handling works
      original_file = System.get_env("VERTEX_JSON_FILE")
      
      try do
        # Create a temporary file with invalid credentials
        temp_file = System.tmp_dir!() |> Path.join("invalid_vertex.json")
        invalid_creds = %{
          "type" => "service_account",
          "project_id" => "invalid-project",
          "private_key" => "-----BEGIN PRIVATE KEY-----\ninvalid\n-----END PRIVATE KEY-----\n",
          "client_email" => "invalid@invalid-project.iam.gserviceaccount.com"
        }
        File.write!(temp_file, Jason.encode!(invalid_creds))
        System.put_env("VERTEX_JSON_FILE", temp_file)
        
        response = Vertex.analyze_code("def test, do: :ok", %{})
        
        assert %Response{} = response
        assert response.success == false
        assert response.provider == :vertex
        assert is_binary(response.error)
        assert String.contains?(response.error, "authenticate") or 
               String.contains?(response.error, "error") or
               String.contains?(response.error, "invalid")
        
      after
        # Restore original credentials file
        if original_file do
          System.put_env("VERTEX_JSON_FILE", original_file)
        else
          System.delete_env("VERTEX_JSON_FILE")
        end
        
        # Clean up temp file
        temp_file = System.tmp_dir!() |> Path.join("invalid_vertex.json")
        if File.exists?(temp_file), do: File.rm(temp_file)
      end
    end

    @tag :live_api
    test "handles invalid model gracefully" do
      # Test with invalid model to ensure error handling works
      original_model = System.get_env("VERTEX_DEFAULT_MODEL")
      
      try do
        System.put_env("VERTEX_DEFAULT_MODEL", "invalid-model-name")
        
        response = Vertex.analyze_code("def test, do: :ok", %{})
        
        assert %Response{} = response
        # Should fail gracefully with invalid model
        assert response.success == false
        assert response.provider == :vertex
        assert is_binary(response.error)
        # Be more flexible with error message matching
        error_lower = String.downcase(response.error)
        assert String.contains?(error_lower, "model") or 
               String.contains?(error_lower, "not found") or
               String.contains?(error_lower, "invalid") or
               String.contains?(error_lower, "400") or
               String.contains?(error_lower, "bad request")
        
      after
        # Restore original model setting
        if original_model do
          System.put_env("VERTEX_DEFAULT_MODEL", original_model)
        else
          System.delete_env("VERTEX_DEFAULT_MODEL")
        end
      end
    end
  end

  describe "Performance and Reliability" do
    @tag :live_api
    test "response time is reasonable" do
      start_time = System.monotonic_time(:millisecond)
      
      response = Vertex.analyze_code("def simple, do: :ok", %{})
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      assert response.success == true
      assert duration < 15_000  # Should complete within 15 seconds (Vertex can be slower than Gemini)
    end

    @tag :live_api
    test "handles concurrent requests" do
      # Use fewer concurrent requests to avoid rate limiting
      tasks = for i <- 1..2 do
        Task.async(fn ->
          # Add small random delay to stagger requests
          :timer.sleep(:rand.uniform(1000))
          Vertex.analyze_code("def test_#{i}, do: #{i}", %{test_id: i})
        end)
      end
      
      responses = Task.await_many(tasks, 60_000)  # Increased timeout for Vertex
      
      assert length(responses) == 2
      # Allow for some failures due to rate limiting
      successful_responses = Enum.filter(responses, & &1.success)
      assert length(successful_responses) >= 1, "At least one request should succeed"
      
      Enum.each(successful_responses, fn response ->
        assert %Response{} = response
        assert response.success == true
        assert response.provider == :vertex
      end)
    end
  end
end 