defmodule ElixirScope.AI.LLM.Providers.MockTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.AI.LLM.Providers.Mock
  alias ElixirScope.AI.LLM.Response

  describe "analyze_code/2" do
    test "returns successful response for simple code" do
      code = "def hello, do: :world"
      response = Mock.analyze_code(code)
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :mock
      assert response.confidence == 0.85
      assert String.contains?(response.text, "Code Analysis")
      assert String.contains?(response.text, "Mock Provider")
      assert response.metadata.code_length == String.length(code)
      assert response.metadata.analysis_type == "code_analysis"
    end

    test "returns different analysis for module code" do
      code = """
      defmodule Test do
        def hello, do: :world
      end
      """
      response = Mock.analyze_code(code)
      
      assert response.success == true
      assert String.contains?(response.text, "module definition")
    end

    test "returns different analysis for function code" do
      code = "def complex_function(x, y), do: x + y"
      response = Mock.analyze_code(code)
      
      assert response.success == true
      assert String.contains?(response.text, "function")
    end

    test "includes context analysis when context provided" do
      code = "def test, do: :ok"
      context = %{complexity: 5, issues: ["too_long"]}
      response = Mock.analyze_code(code, context)
      
      assert response.success == true
      assert String.contains?(response.text, "Context Analysis")
      assert String.contains?(response.text, "complexity")
      assert Enum.sort(response.metadata.context_keys) == [:complexity, :issues]
    end
  end

  describe "explain_error/2" do
    test "returns successful response for error explanation" do
      error = "undefined function foo/0"
      response = Mock.explain_error(error)
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :mock
      assert response.confidence == 0.90
      assert String.contains?(response.text, "Error Explanation")
      assert String.contains?(response.text, "Mock Provider")
      assert response.metadata.error_length == String.length(error)
      assert response.metadata.analysis_type == "error_explanation"
    end

    test "provides specific explanation for undefined errors" do
      error = "undefined variable x"
      response = Mock.explain_error(error)
      
      assert response.success == true
      assert String.contains?(response.text, "defined or imported")
      assert String.contains?(response.text, "defined or imported")
    end

    test "provides specific explanation for syntax errors" do
      error = "syntax error before: ')'"
      response = Mock.explain_error(error)
      
      assert response.success == true
      assert String.contains?(response.text, "syntax error")
      assert String.contains?(response.text, "grammar rules")
    end

    test "includes context when provided" do
      error = "timeout"
      context = %{function: "fetch_data", timeout: 5000}
      response = Mock.explain_error(error, context)
      
      assert response.success == true
      assert String.contains?(response.text, "Contextual Insights")
      assert Enum.sort(response.metadata.context_keys) == [:function, :timeout]
    end
  end

  describe "suggest_fix/2" do
    test "returns successful response for fix suggestion" do
      problem = "function is too complex"
      response = Mock.suggest_fix(problem)
      
      assert %Response{} = response
      assert response.success == true
      assert response.provider == :mock
      assert response.confidence == 0.80
      assert String.contains?(response.text, "Fix Suggestion")
      assert String.contains?(response.text, "Mock Provider")
      assert response.metadata.problem_length == String.length(problem)
      assert response.metadata.analysis_type == "fix_suggestion"
    end

    test "provides specific suggestions for performance issues" do
      problem = "performance is slow"
      response = Mock.suggest_fix(problem)
      
      assert response.success == true
      assert String.contains?(response.text, "performance")
      assert String.contains?(response.text, "efficient data structures")
    end

    test "provides specific suggestions for complexity issues" do
      problem = "code complexity is high"
      response = Mock.suggest_fix(problem)
      
      assert response.success == true
      assert String.contains?(response.text, "complexity")
      assert String.contains?(response.text, "Extract functions")
    end

    test "provides specific suggestions for testing issues" do
      problem = "need better test coverage"
      response = Mock.suggest_fix(problem)
      
      assert response.success == true
      assert String.contains?(response.text, "testing")
      assert String.contains?(response.text, "edge case tests")
    end

    test "includes context suggestions when provided" do
      problem = "error handling"
      context = %{module: "UserService", errors: 3}
      response = Mock.suggest_fix(problem, context)
      
      assert response.success == true
      assert String.contains?(response.text, "Context-Specific")
      assert Enum.sort(response.metadata.context_keys) == [:errors, :module]
    end
  end

  describe "simulate_error/1" do
    test "returns error response for timeout simulation" do
      response = Mock.simulate_error("timeout")
      
      assert %Response{} = response
      assert response.success == false
      assert response.provider == :mock
      assert response.confidence == 0.0
      assert response.text == ""
      assert response.error == "Mock provider timeout simulation"
      assert response.metadata.simulated == true
      assert response.metadata.error_type == "timeout"
    end

    test "returns error response for rate limit simulation" do
      response = Mock.simulate_error("rate_limit")
      
      assert response.success == false
      assert response.error == "Mock provider rate limit simulation"
      assert response.metadata.error_type == "rate_limit"
    end

    test "returns error response for invalid request simulation" do
      response = Mock.simulate_error("invalid_request")
      
      assert response.success == false
      assert response.error == "Mock provider invalid request simulation"
      assert response.metadata.error_type == "invalid_request"
    end

    test "returns generic error for unknown error type" do
      response = Mock.simulate_error("unknown")
      
      assert response.success == false
      assert response.error == "Mock provider generic error simulation"
      assert response.metadata.error_type == "unknown"
    end

    test "uses default error type when not specified" do
      response = Mock.simulate_error()
      
      assert response.success == false
      assert response.error == "Mock provider timeout simulation"
      assert response.metadata.error_type == "timeout"
    end
  end
end 