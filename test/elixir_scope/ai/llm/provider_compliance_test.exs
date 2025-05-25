defmodule ElixirScope.AI.LLM.ProviderComplianceTest do
  @moduledoc """
  Tests to ensure all LLM providers comply with the Provider behaviour.
  
  This test suite verifies that each provider implements all required
  callbacks and returns properly formatted responses.
  """
  
  use ExUnit.Case, async: true
  
  alias ElixirScope.AI.LLM.Response
  alias ElixirScope.AI.LLM.Providers.{Gemini, Mock}

  @providers [
    {Mock, :mock},
    {Gemini, :gemini}
  ]

  describe "Provider behaviour compliance" do
    for {provider_module, provider_name} <- @providers do
      test "#{provider_module} implements all required callbacks" do
        provider_module = unquote(provider_module)
        
        # Check that the module implements the Provider behaviour
        assert function_exported?(provider_module, :analyze_code, 2)
        assert function_exported?(provider_module, :explain_error, 2)
        assert function_exported?(provider_module, :suggest_fix, 2)
        assert function_exported?(provider_module, :provider_name, 0)
        assert function_exported?(provider_module, :configured?, 0)
        assert function_exported?(provider_module, :test_connection, 0)
      end

      test "#{provider_module}.provider_name/0 returns correct atom" do
        provider_module = unquote(provider_module)
        expected_name = unquote(provider_name)
        
        assert provider_module.provider_name() == expected_name
      end

      test "#{provider_module}.configured?/0 returns boolean" do
        provider_module = unquote(provider_module)
        
        result = provider_module.configured?()
        assert is_boolean(result)
      end

      test "#{provider_module}.analyze_code/2 returns valid Response" do
        provider_module = unquote(provider_module)
        
        response = provider_module.analyze_code("def hello, do: :world", %{})
        
        assert %Response{} = response
        assert is_boolean(response.success)
        assert is_binary(response.text) or response.text == ""
        assert is_atom(response.provider)
        assert is_map(response.metadata)
        assert %DateTime{} = response.timestamp
        
        if response.success do
          assert response.error == nil
          assert String.length(response.text) > 0
        else
          assert is_binary(response.error)
        end
      end

      test "#{provider_module}.explain_error/2 returns valid Response" do
        provider_module = unquote(provider_module)
        
        response = provider_module.explain_error("undefined function foo/0", %{})
        
        assert %Response{} = response
        assert is_boolean(response.success)
        assert is_binary(response.text) or response.text == ""
        assert is_atom(response.provider)
        assert is_map(response.metadata)
        assert %DateTime{} = response.timestamp
        
        if response.success do
          assert response.error == nil
          assert String.length(response.text) > 0
        else
          assert is_binary(response.error)
        end
      end

      test "#{provider_module}.suggest_fix/2 returns valid Response" do
        provider_module = unquote(provider_module)
        
        response = provider_module.suggest_fix("function is too complex", %{})
        
        assert %Response{} = response
        assert is_boolean(response.success)
        assert is_binary(response.text) or response.text == ""
        assert is_atom(response.provider)
        assert is_map(response.metadata)
        assert %DateTime{} = response.timestamp
        
        if response.success do
          assert response.error == nil
          assert String.length(response.text) > 0
        else
          assert is_binary(response.error)
        end
      end

      test "#{provider_module}.test_connection/0 returns valid Response" do
        provider_module = unquote(provider_module)
        
        response = provider_module.test_connection()
        
        assert %Response{} = response
        assert is_boolean(response.success)
        assert is_binary(response.text) or response.text == ""
        assert is_atom(response.provider)
        assert is_map(response.metadata)
        assert %DateTime{} = response.timestamp
      end

      test "#{provider_module} handles empty context gracefully" do
        provider_module = unquote(provider_module)
        
        response = provider_module.analyze_code("def test, do: :ok", %{})
        assert %Response{} = response
        
        response = provider_module.explain_error("error message", %{})
        assert %Response{} = response
        
        response = provider_module.suggest_fix("problem description", %{})
        assert %Response{} = response
      end

      test "#{provider_module} handles context with data" do
        provider_module = unquote(provider_module)
        
        context = %{
          file: "test.ex",
          line: 42,
          complexity: 5,
          metadata: %{author: "test"}
        }
        
        response = provider_module.analyze_code("def test, do: :ok", context)
        assert %Response{} = response
        
        response = provider_module.explain_error("error message", context)
        assert %Response{} = response
        
        response = provider_module.suggest_fix("problem description", context)
        assert %Response{} = response
      end
    end
  end

  describe "Response format consistency" do
    test "all providers return consistent Response structure" do
      code = "def hello(name), do: \"Hello \#{name}\""
      context = %{test: true}
      
      responses = Enum.map(@providers, fn {provider_module, _name} ->
        provider_module.analyze_code(code, context)
      end)
      
      # All responses should have the same structure
      Enum.each(responses, fn response ->
        assert %Response{} = response
        assert Map.has_key?(response, :text)
        assert Map.has_key?(response, :success)
        assert Map.has_key?(response, :provider)
        assert Map.has_key?(response, :metadata)
        assert Map.has_key?(response, :timestamp)
        assert Map.has_key?(response, :confidence)
        assert Map.has_key?(response, :error)
      end)
    end

    test "provider names are unique" do
      provider_names = Enum.map(@providers, fn {provider_module, _name} ->
        provider_module.provider_name()
      end)
      
      unique_names = Enum.uniq(provider_names)
      assert length(provider_names) == length(unique_names)
    end
  end

  describe "Error handling consistency" do
    test "providers handle invalid input gracefully" do
      # Test with very long input
      long_code = String.duplicate("def test_func, do: :ok\n", 1000)
      
      Enum.each(@providers, fn {provider_module, _name} ->
        response = provider_module.analyze_code(long_code, %{})
        assert %Response{} = response
        # Should either succeed or fail gracefully
        assert is_boolean(response.success)
      end)
    end

    test "providers handle special characters in input" do
      special_code = "def test, do: \"Special chars: ñáéíóú 中文 🚀\""
      
      Enum.each(@providers, fn {provider_module, _name} ->
        response = provider_module.analyze_code(special_code, %{})
        assert %Response{} = response
        assert is_boolean(response.success)
      end)
    end
  end
end 