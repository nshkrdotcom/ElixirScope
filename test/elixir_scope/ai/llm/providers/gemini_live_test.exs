defmodule ElixirScope.AI.LLM.Providers.GeminiLiveTest do
  @moduledoc """
  Live integration tests for the Gemini provider.
  
  These tests make actual API calls to Google's Gemini service and require:
  1. GEMINI_API_KEY environment variable to be set
  2. Internet connectivity
  3. Valid Gemini API quota
  
  To run these tests separately:
  
      # Run only live Gemini tests
      mix test test/elixir_scope/ai/llm/providers/gemini_live_test.exs
      
      # Run with specific tag
      mix test --only live_api
      
      # Skip live tests during regular test runs
      mix test --exclude live_api
  """
  
  use ExUnit.Case, async: false
  
  alias ElixirScope.AI.LLM.Providers.Gemini
  alias ElixirScope.AI.LLM.Response

  @moduletag :live_api
  @moduletag timeout: 30_000  # 30 second timeout for API calls

  setup_all do
    case System.get_env("GEMINI_API_KEY") do
      nil ->
        {:skip, "GEMINI_API_KEY environment variable not set"}
      
      api_key when byte_size(api_key) < 10 ->
        {:skip, "GEMINI_API_KEY appears to be invalid (too short)"}
      
      _api_key ->
        :ok
    end
  end

  describe "Live Gemini API Integration" do
    @tag :live_api
    test "provider_name/0 returns :gemini" do
      assert Gemini.provider_name() == :gemini
    end

    @tag :live_api
    test "configured?/0 returns true when API key is set" do
      assert Gemini.configured?() == true
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

      response = Gemini.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :gemini
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

      response = Gemini.explain_error(error_message, context)
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :gemini
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

      response = Gemini.suggest_fix(problem, context)
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :gemini
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
      response = Gemini.test_connection()
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :gemini
      assert is_binary(response.text)
    end

    @tag :live_api
    test "handles different Gemini models via GEMINI_DEFAULT_MODEL" do
      # Test that the provider respects the GEMINI_DEFAULT_MODEL env var
      original_model = System.get_env("GEMINI_DEFAULT_MODEL")
      
      try do
        # Set a specific model
        System.put_env("GEMINI_DEFAULT_MODEL", "gemini-1.5-pro")
        
        response = Gemini.analyze_code("def hello, do: :world", %{})
        
        assert %Response{} = response
        assert response.success == true
        assert response.provider == :gemini
        
      after
        # Restore original model setting
        if original_model do
          System.put_env("GEMINI_DEFAULT_MODEL", original_model)
        else
          System.delete_env("GEMINI_DEFAULT_MODEL")
        end
      end
    end

    @tag :live_api
    test "handles API errors gracefully" do
      # Test with invalid API key to ensure error handling works
      original_key = System.get_env("GEMINI_API_KEY")
      
      try do
        System.put_env("GEMINI_API_KEY", "invalid-key-12345")
        
        response = Gemini.analyze_code("def test, do: :ok", %{})
        
        assert %Response{} = response
        assert response.success == false
        assert response.provider == :gemini
        assert is_binary(response.error)
        assert String.contains?(response.error, "API") or 
               String.contains?(response.error, "error") or
               String.contains?(response.error, "invalid")
        
      after
        # Restore original API key
        if original_key do
          System.put_env("GEMINI_API_KEY", original_key)
        else
          System.delete_env("GEMINI_API_KEY")
        end
      end
    end
  end

  describe "Performance and Reliability" do
    @tag :live_api
    test "response time is reasonable" do
      start_time = System.monotonic_time(:millisecond)
      
      response = Gemini.analyze_code("def simple, do: :ok", %{})
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      assert response.success == true
      assert duration < 10_000  # Should complete within 10 seconds
    end

    @tag :live_api
    test "handles concurrent requests" do
      tasks = for i <- 1..3 do
        Task.async(fn ->
          Gemini.analyze_code("def test_#{i}, do: #{i}", %{test_id: i})
        end)
      end
      
      responses = Task.await_many(tasks, 30_000)
      
      assert length(responses) == 3
      Enum.each(responses, fn response ->
        assert %Response{} = response
        assert response.success == true
        assert response.provider == :gemini
      end)
    end
  end
end 