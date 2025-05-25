defmodule ElixirScope.AI.LLM.Providers.GeminiLiveTest do
  @moduledoc """
  Live API tests for the Gemini provider.
  
  These tests make actual API calls to Google's Gemini service.
  Run with: mix test.gemini
  
  Prerequisites:
  - GOOGLE_API_KEY environment variable must be set
  - Internet connection required
  """
  
  use ExUnit.Case, async: false
  
  alias ElixirScope.AI.LLM.Response
  alias ElixirScope.AI.LLM.Providers.Gemini
  
  @moduletag :live_api
  
  setup_all do
    unless Gemini.configured?() do
      IO.puts("\n⚠️  Skipping Gemini tests - GOOGLE_API_KEY not configured")
      :skip
    else
      IO.puts("\n🚀 Running Gemini live API tests...")
      :ok
    end
  end
  
  describe "Gemini Provider - Live API Tests" do
    test "provider_name/0 returns :gemini" do
      assert Gemini.provider_name() == :gemini
    end
    
    test "configured?/0 returns true when API key is set" do
      assert Gemini.configured?() == true
    end
    
    test "test_connection/0 successfully connects to Gemini API" do
      response = Gemini.test_connection()
      
      assert %Response{} = response
      assert response.provider == :gemini
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 0
      assert response.error == nil
      
      IO.puts("✅ Connection test: #{String.slice(response.text, 0, 100)}...")
    end
    
    test "analyze_code/2 analyzes simple Elixir code" do
      code = """
      defmodule Calculator do
        def add(a, b) do
          a + b
        end
        
        def multiply(a, b) do
          a * b
        end
      end
      """
      
      context = %{
        file: "calculator.ex",
        purpose: "basic arithmetic operations"
      }
      
      response = Gemini.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :gemini
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 50
      assert response.error == nil
      
      # Should mention something about the code
      text_lower = String.downcase(response.text)
      assert text_lower =~ ~r/(function|module|calculator|add|multiply)/
      
      IO.puts("✅ Code analysis: #{String.slice(response.text, 0, 150)}...")
    end
    
    test "explain_error/2 explains Elixir compilation error" do
      error_message = """
      ** (CompileError) lib/my_module.ex:5: undefined function foo/1
          (elixir 1.14.0) lib/kernel/parallel_compiler.ex:229: anonymous fn/4 in Kernel.ParallelCompiler.spawn_workers/7
      """
      
      context = %{
        file: "my_module.ex",
        line: 5,
        function: "foo/1"
      }
      
      response = Gemini.explain_error(error_message, context)
      
      assert %Response{} = response
      assert response.provider == :gemini
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 30
      assert response.error == nil
      
      # Should mention something about undefined function
      text_lower = String.downcase(response.text)
      assert text_lower =~ ~r/(undefined|function|not.*defined|missing)/
      
      IO.puts("✅ Error explanation: #{String.slice(response.text, 0, 150)}...")
    end
    
    test "suggest_fix/2 suggests improvements for code" do
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
        file: "data_processor.ex",
        complexity: 8,
        issue: "high cyclomatic complexity"
      }
      
      response = Gemini.suggest_fix(problem, context)
      
      assert %Response{} = response
      assert response.provider == :gemini
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 50
      assert response.error == nil
      
      # Should mention refactoring or improvement suggestions
      text_lower = String.downcase(response.text)
      assert text_lower =~ ~r/(refactor|improve|simplify|pattern.*match|cond|case)/
      
      IO.puts("✅ Fix suggestion: #{String.slice(response.text, 0, 150)}...")
    end
    
    test "handles context with metadata" do
      code = "def greet(name), do: \"Hello \" <> name"
      
      context = %{
        file: "greeter.ex",
        line: 1,
        author: "test_user",
        project: "elixir_scope",
        metadata: %{
          complexity: 1,
          test_coverage: 95,
          last_modified: "2024-01-15"
        }
      }
      
      response = Gemini.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :gemini
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
      
      IO.puts("✅ Context handling: #{String.slice(response.text, 0, 100)}...")
    end
    
    test "handles empty context gracefully" do
      code = "def simple_function, do: :ok"
      
      response = Gemini.analyze_code(code, %{})
      
      assert %Response{} = response
      assert response.provider == :gemini
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
      
      IO.puts("✅ Empty context: #{String.slice(response.text, 0, 100)}...")
    end
    
    test "response includes proper metadata" do
      response = Gemini.test_connection()
      
      assert %Response{} = response
      assert is_map(response.metadata)
      assert %DateTime{} = response.timestamp
      
      # Check that timestamp is recent (within last minute)
      now = DateTime.utc_now()
      diff = DateTime.diff(now, response.timestamp, :second)
      assert diff >= 0 and diff < 60
      
      IO.puts("✅ Metadata check: timestamp=#{response.timestamp}")
    end
  end
  
  describe "Gemini Error Handling" do
    test "handles malformed code gracefully" do
      malformed_code = "def broken_syntax do end end end"
      
      response = Gemini.analyze_code(malformed_code, %{})
      
      assert %Response{} = response
      assert response.provider == :gemini
      # Should either succeed with analysis or fail gracefully
      assert is_boolean(response.success)
      
      if response.success do
        assert is_binary(response.text)
        assert response.error == nil
      else
        assert is_binary(response.error)
      end
      
      IO.puts("✅ Malformed code handling: success=#{response.success}")
    end
    
    test "handles very long input" do
      # Create a long but valid Elixir module
      long_code = """
      defmodule VeryLongModule do
      #{Enum.map_join(1..50, "\n", fn i -> "  def function_#{i}(x), do: x + #{i}" end)}
      end
      """
      
      response = Gemini.analyze_code(long_code, %{})
      
      assert %Response{} = response
      assert response.provider == :gemini
      assert is_boolean(response.success)
      
      IO.puts("✅ Long input handling: success=#{response.success}, length=#{String.length(long_code)}")
    end
    
    test "handles special characters and unicode" do
      unicode_code = """
      defmodule UnicodeTest do
        def greet(name) do
          "¡Hola " <> name <> "! 你好 🚀 Здравствуй"
        end
        
        def emoji_function do
          "🎉 🔥 ⚡ 🌟"
        end
      end
      """
      
      response = Gemini.analyze_code(unicode_code, %{})
      
      assert %Response{} = response
      assert response.provider == :gemini
      assert is_boolean(response.success)
      
      IO.puts("✅ Unicode handling: success=#{response.success}")
    end
  end
end 