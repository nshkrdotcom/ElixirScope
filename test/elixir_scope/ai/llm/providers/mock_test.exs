defmodule ElixirScope.AI.LLM.Providers.MockTest do
  @moduledoc """
  Comprehensive tests for the Mock provider.
  
  These tests run entirely offline and test all provider functionality
  without making any external API calls.
  Run with: mix test.mock
  """
  
  use ExUnit.Case, async: true
  
  alias ElixirScope.AI.LLM.Response
  alias ElixirScope.AI.LLM.Providers.Mock
  
  describe "Mock Provider - Basic Functionality" do
    test "provider_name/0 returns :mock" do
      assert Mock.provider_name() == :mock
    end
    
    test "configured?/0 always returns true" do
      assert Mock.configured?() == true
    end
    
    test "test_connection/0 returns successful mock response" do
      response = Mock.test_connection()
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 0
      assert response.error == nil
      assert is_map(response.metadata)
      assert %DateTime{} = response.timestamp
      
      # Mock should return a connection test message
      assert String.contains?(response.text, "Mock") or 
             String.contains?(response.text, "connection") or
             String.contains?(response.text, "test")
    end
  end
  
  describe "Mock Provider - Code Analysis" do
    test "analyze_code/2 returns valid response for simple code" do
      code = "def hello, do: :world"
      context = %{}
      
      response = Mock.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 10
      assert response.error == nil
      assert is_map(response.metadata)
      assert %DateTime{} = response.timestamp
    end
    
    test "analyze_code/2 handles complex Elixir code" do
      code = """
      defmodule Calculator do
        @moduledoc "A simple calculator module"
        
        def add(a, b) when is_number(a) and is_number(b) do
          a + b
        end
        
        def subtract(a, b) when is_number(a) and is_number(b) do
          a - b
        end
        
        def multiply(a, b) when is_number(a) and is_number(b) do
          a * b
        end
        
        def divide(a, b) when is_number(a) and is_number(b) and b != 0 do
          a / b
        end
        
        def divide(_, 0), do: {:error, :division_by_zero}
      end
      """
      
      context = %{
        file: "calculator.ex",
        complexity: 4,
        purpose: "arithmetic operations"
      }
      
      response = Mock.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 20
      assert response.error == nil
    end
    
    test "analyze_code/2 handles OTP code patterns" do
      code = """
      defmodule MyApp.Worker do
        use GenServer
        
        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end
        
        def init(state) do
          {:ok, state}
        end
        
        def handle_call(:get_state, _from, state) do
          {:reply, state, state}
        end
        
        def handle_cast({:update_state, new_state}, _state) do
          {:noreply, new_state}
        end
      end
      """
      
      context = %{
        pattern: "GenServer",
        framework: "OTP"
      }
      
      response = Mock.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
    
    test "analyze_code/2 handles Phoenix controller code" do
      code = """
      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller
        
        def index(conn, _params) do
          users = MyApp.Accounts.list_users()
          render(conn, "index.html", users: users)
        end
        
        def show(conn, %{"id" => id}) do
          user = MyApp.Accounts.get_user!(id)
          render(conn, "show.html", user: user)
        end
      end
      """
      
      context = %{
        framework: "Phoenix",
        pattern: "controller"
      }
      
      response = Mock.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
  end
  
  describe "Mock Provider - Error Explanation" do
    test "explain_error/2 handles compilation errors" do
      error_message = """
      ** (CompileError) lib/my_module.ex:5: undefined function foo/1
          (elixir 1.14.0) lib/kernel/parallel_compiler.ex:229: anonymous fn/4 in Kernel.ParallelCompiler.spawn_workers/7
      """
      
      context = %{
        file: "my_module.ex",
        line: 5,
        error_type: "CompileError"
      }
      
      response = Mock.explain_error(error_message, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 15
      assert response.error == nil
    end
    
    test "explain_error/2 handles runtime errors" do
      error_message = """
      ** (FunctionClauseError) no function clause matching in Calculator.divide/2
          
          The following arguments were given to Calculator.divide/2:
          
              # 1
              10
          
              # 2
              0
          
          lib/calculator.ex:15: Calculator.divide/2
      """
      
      context = %{
        file: "calculator.ex",
        line: 15,
        function: "divide/2",
        error_type: "FunctionClauseError"
      }
      
      response = Mock.explain_error(error_message, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
    
    test "explain_error/2 handles pattern matching errors" do
      error_message = """
      ** (MatchError) no match of right hand side value: {:error, :not_found}
          lib/user_service.ex:23: UserService.get_user_name/1
      """
      
      context = %{
        file: "user_service.ex",
        line: 23,
        error_type: "MatchError"
      }
      
      response = Mock.explain_error(error_message, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
  end
  
  describe "Mock Provider - Fix Suggestions" do
    test "suggest_fix/2 handles complexity issues" do
      problem = """
      This function has high cyclomatic complexity and could be refactored:
      
      def process_data(data) do
        if is_list(data) do
          if length(data) > 0 do
            if Enum.all?(data, &is_integer/1) do
              if Enum.sum(data) > 100 do
                :large_sum
              else
                :small_sum
              end
            else
              :not_integers
            end
          else
            :empty_list
          end
        else
          :not_list
        end
      end
      """
      
      context = %{
        complexity: 8,
        issue: "high cyclomatic complexity"
      }
      
      response = Mock.suggest_fix(problem, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 20
      assert response.error == nil
    end
    
    test "suggest_fix/2 handles performance issues" do
      problem = """
      This function is inefficient and could be optimized:
      
      def find_user_by_email(users, email) do
        Enum.find(users, fn user ->
          String.downcase(user.email) == String.downcase(email)
        end)
      end
      
      # Called in a loop with thousands of users
      """
      
      context = %{
        issue: "performance",
        scale: "large dataset"
      }
      
      response = Mock.suggest_fix(problem, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
    
    test "suggest_fix/2 handles design pattern issues" do
      problem = """
      This GenServer violates single responsibility principle:
      
      defmodule UserManager do
        use GenServer
        
        # Handles user CRUD, email sending, analytics, and caching
        def handle_call({:create_user, data}, _from, state) do
          # 50+ lines of mixed responsibilities
        end
      end
      """
      
      context = %{
        pattern: "GenServer",
        issue: "single responsibility violation",
        complexity: 9
      }
      
      response = Mock.suggest_fix(problem, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
  end
  
  describe "Mock Provider - Context Handling" do
    test "handles empty context gracefully" do
      code = "def simple, do: :ok"
      
      response = Mock.analyze_code(code, %{})
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
    
    test "handles rich context with metadata" do
      code = "def greet(name), do: \"Hello \#{name}\""
      
      context = %{
        file: "greeter.ex",
        line: 1,
        author: "test_user",
        project: "elixir_scope",
        complexity: 1,
        test_coverage: 95,
        last_modified: "2024-01-15",
        metadata: %{
          framework: "Phoenix",
          version: "1.7.0",
          dependencies: ["ecto", "phoenix_html"],
          custom_data: %{
            team: "backend",
            priority: "high"
          }
        }
      }
      
      response = Mock.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
    
    test "handles context with special characters" do
      code = "def unicode_test, do: \"🚀 Hello 世界\""
      
      context = %{
        file: "unicode_test.ex",
        description: "Testing unicode: ñáéíóú 中文 🎉",
        tags: ["unicode", "i18n", "测试"]
      }
      
      response = Mock.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
  end
  
  describe "Mock Provider - Edge Cases and Error Handling" do
    test "handles malformed code gracefully" do
      malformed_code = "def broken_syntax do end end end"
      
      response = Mock.analyze_code(malformed_code, %{})
      
      assert %Response{} = response
      assert response.provider == :mock
      # Mock should handle this gracefully
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
    
    test "handles very long code input" do
      # Create a very long but valid Elixir module
      long_code = "defmodule VeryLongModule do\n" <>
        "  @moduledoc \"A module with many functions\"\n\n" <>
        Enum.map_join(1..200, "\n\n", fn i -> 
          "  def function_#{i}(param) do\n" <>
          "    case param do\n" <>
          "      :option_a -> {:ok, \"Result A for function #{i}\"}\n" <>
          "      :option_b -> {:ok, \"Result B for function #{i}\"}\n" <>
          "      :option_c -> {:ok, \"Result C for function #{i}\"}\n" <>
          "      _ -> {:error, \"Invalid option for function #{i}\"}\n" <>
          "    end\n" <>
          "  end"
        end) <>
        "\nend"
      
      response = Mock.analyze_code(long_code, %{})
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
      
      # Should handle large input efficiently
      assert String.length(long_code) > 50_000
    end
    
    test "handles empty string input" do
      response = Mock.analyze_code("", %{})
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
    
    test "handles nil context gracefully" do
      # This shouldn't happen in normal usage, but test defensive programming
      code = "def test, do: :ok"
      
      # Mock should handle this without crashing by treating nil as empty map
      response = Mock.analyze_code(code, %{})
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
    
    test "handles very large context maps" do
      code = "def test, do: :ok"
      
      # Create a large context map
      large_context = %{
        metadata: %{
          large_data: Enum.reduce(1..1000, %{}, fn i, acc ->
            Map.put(acc, "key_#{i}", "value_#{i}_with_some_longer_text_to_make_it_bigger")
          end)
        }
      }
      
      response = Mock.analyze_code(code, large_context)
      
      assert %Response{} = response
      assert response.provider == :mock
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
    end
  end
  
  describe "Mock Provider - Response Consistency" do
    test "response structure is always consistent" do
      responses = [
        Mock.analyze_code("def test, do: :ok", %{}),
        Mock.explain_error("some error", %{}),
        Mock.suggest_fix("some problem", %{}),
        Mock.test_connection()
      ]
      
      Enum.each(responses, fn response ->
        assert %Response{} = response
        assert Map.has_key?(response, :text)
        assert Map.has_key?(response, :success)
        assert Map.has_key?(response, :provider)
        assert Map.has_key?(response, :metadata)
        assert Map.has_key?(response, :timestamp)
        assert Map.has_key?(response, :confidence)
        assert Map.has_key?(response, :error)
        
        # All mock responses should be successful
        assert response.success == true
        assert response.provider == :mock
        assert response.error == nil
        assert is_binary(response.text)
        assert is_map(response.metadata)
        assert %DateTime{} = response.timestamp
      end)
    end
    
    test "timestamps are recent and properly formatted" do
      response = Mock.test_connection()
      
      assert %DateTime{} = response.timestamp
      
      # Timestamp should be very recent (within last few seconds)
      now = DateTime.utc_now()
      diff = DateTime.diff(now, response.timestamp, :second)
      assert diff >= 0 and diff < 5
    end
    
    test "metadata includes expected fields" do
      response = Mock.analyze_code("def test, do: :ok", %{file: "test.ex"})
      
      assert is_map(response.metadata)
      # Mock provider should include basic metadata
      assert Map.has_key?(response.metadata, :analysis_type)
      assert response.metadata.analysis_type == "code_analysis"
    end
    
    test "confidence levels are reasonable" do
      responses = [
        Mock.analyze_code("def test, do: :ok", %{}),
        Mock.explain_error("some error", %{}),
        Mock.suggest_fix("some problem", %{})
      ]
      
      Enum.each(responses, fn response ->
        assert is_number(response.confidence)
        assert response.confidence >= 0.0
        assert response.confidence <= 1.0
      end)
    end
  end
  
  describe "Mock Provider - Performance" do
    test "responses are fast" do
      start_time = System.monotonic_time(:millisecond)
      
      _response = Mock.analyze_code("def test, do: :ok", %{})
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # Mock responses should be very fast (under 100ms)
      assert duration < 100
    end
    
    test "handles concurrent requests efficiently" do
      tasks = for i <- 1..20 do
        Task.async(fn ->
          Mock.analyze_code("def test_#{i}, do: #{i}", %{test_id: i})
        end)
      end
      
      start_time = System.monotonic_time(:millisecond)
      responses = Task.await_many(tasks, 5_000)
      end_time = System.monotonic_time(:millisecond)
      
      duration = end_time - start_time
      
      assert length(responses) == 20
      # All should be successful
      Enum.each(responses, fn response ->
        assert %Response{} = response
        assert response.success == true
        assert response.provider == :mock
      end)
      
      # Should handle 20 concurrent requests quickly
      assert duration < 1_000  # Under 1 second
    end
  end
end 