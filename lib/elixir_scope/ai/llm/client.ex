defmodule ElixirScope.AI.LLM.Client do
  @moduledoc """
  Main LLM client interface for ElixirScope.
  
  Provides a simple, unified API for code analysis, error explanation,
  and fix suggestions. Handles provider selection and automatic fallback
  from Gemini to Mock provider on errors.
  """

  alias ElixirScope.AI.LLM.{Response, Config}
  alias ElixirScope.AI.LLM.Providers.{Gemini, Mock}

  require Logger

  @doc """
  Analyzes code using the configured LLM provider.
  
  ## Examples
  
      iex> ElixirScope.AI.LLM.Client.analyze_code("def hello, do: :world")
      %ElixirScope.AI.LLM.Response{
        text: "This is a simple function definition...",
        success: true,
        provider: :gemini
      }
  """
  @spec analyze_code(String.t(), map()) :: Response.t()
  def analyze_code(code, context \\ %{}) do
    with_fallback(fn provider ->
      case provider do
        :gemini -> Gemini.analyze_code(code, context)
        :mock -> Mock.analyze_code(code, context)
      end
    end)
  end

  @doc """
  Explains an error using the configured LLM provider.
  
  ## Examples
  
      iex> ElixirScope.AI.LLM.Client.explain_error("undefined function foo/0")
      %ElixirScope.AI.LLM.Response{
        text: "This error occurs when...",
        success: true,
        provider: :gemini
      }
  """
  @spec explain_error(String.t(), map()) :: Response.t()
  def explain_error(error_message, context \\ %{}) do
    with_fallback(fn provider ->
      case provider do
        :gemini -> Gemini.explain_error(error_message, context)
        :mock -> Mock.explain_error(error_message, context)
      end
    end)
  end

  @doc """
  Suggests a fix using the configured LLM provider.
  
  ## Examples
  
      iex> ElixirScope.AI.LLM.Client.suggest_fix("function is too complex")
      %ElixirScope.AI.LLM.Response{
        text: "To reduce complexity, consider...",
        success: true,
        provider: :gemini
      }
  """
  @spec suggest_fix(String.t(), map()) :: Response.t()
  def suggest_fix(problem_description, context \\ %{}) do
    with_fallback(fn provider ->
      case provider do
        :gemini -> Gemini.suggest_fix(problem_description, context)
        :mock -> Mock.suggest_fix(problem_description, context)
      end
    end)
  end

  @doc """
  Gets the current provider configuration.
  """
  @spec get_provider_status() :: map()
  def get_provider_status do
    primary = Config.get_primary_provider()
    fallback = Config.get_fallback_provider()
    
    %{
      primary_provider: primary,
      fallback_provider: fallback,
      gemini_configured: Config.valid_config?(:gemini),
      mock_available: Config.valid_config?(:mock)
    }
  end

  @doc """
  Tests connectivity to the primary provider.
  """
  @spec test_connection() :: Response.t()
  def test_connection do
    test_code = "def test, do: :ok"
    
    case Config.get_primary_provider() do
      :gemini ->
        Logger.info("Testing Gemini connection...")
        analyze_code(test_code, %{test: true})
      
      :mock ->
        Logger.info("Testing Mock provider...")
        analyze_code(test_code, %{test: true})
    end
  end

  # Private functions

  defp with_fallback(operation) do
    primary_provider = Config.get_primary_provider()
    
    case operation.(primary_provider) do
      %Response{success: true} = response ->
        response
      
      %Response{success: false} = error_response ->
        Logger.warning("Primary provider #{primary_provider} failed: #{error_response.error}")
        
        fallback_provider = Config.get_fallback_provider()
        
        if fallback_provider != primary_provider do
          Logger.info("Falling back to #{fallback_provider} provider")
          
          case operation.(fallback_provider) do
            %Response{success: true} = fallback_response ->
              # Add metadata indicating fallback was used
              %{fallback_response | 
                metadata: Map.put(fallback_response.metadata, :fallback_used, true)}
            
            %Response{success: false} = fallback_error ->
              Logger.error("Fallback provider #{fallback_provider} also failed: #{fallback_error.error}")
              
              # Return the original error with fallback info
              %{error_response | 
                metadata: Map.put(error_response.metadata, :fallback_failed, true)}
          end
        else
          error_response
        end
    end
  end
end 