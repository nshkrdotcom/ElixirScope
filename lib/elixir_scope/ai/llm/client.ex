defmodule ElixirScope.AI.LLM.Client do
  @moduledoc """
  Main LLM client interface for ElixirScope.
  
  Provides a simple, unified API for code analysis, error explanation,
  and fix suggestions. Handles provider selection and automatic fallback
  from Vertex/Gemini to Mock provider on errors.
  """

  alias ElixirScope.AI.LLM.{Response, Config}
  alias ElixirScope.AI.LLM.Providers.{Vertex, Gemini, Mock}

  require Logger

  @doc """
  Analyzes code using the configured LLM provider.
  
  ## Examples
  
      iex> ElixirScope.AI.LLM.Client.analyze_code("def hello, do: :world")
      %ElixirScope.AI.LLM.Response{
        text: "This is a simple function definition...",
        success: true,
        provider: :vertex
      }
  """
  @spec analyze_code(String.t(), map()) :: Response.t()
  def analyze_code(code, context \\ %{}) do
    with_fallback(fn provider ->
      case provider do
        :vertex -> Vertex.analyze_code(code, context)
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
        provider: :vertex
      }
  """
  @spec explain_error(String.t(), map()) :: Response.t()
  def explain_error(error_message, context \\ %{}) do
    with_fallback(fn provider ->
      case provider do
        :vertex -> Vertex.explain_error(error_message, context)
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
        provider: :vertex
      }
  """
  @spec suggest_fix(String.t(), map()) :: Response.t()
  def suggest_fix(problem_description, context \\ %{}) do
    with_fallback(fn provider ->
      case provider do
        :vertex -> Vertex.suggest_fix(problem_description, context)
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
      vertex_configured: Config.valid_config?(:vertex),
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
      :vertex ->
        Logger.info("Testing Vertex connection...")
        analyze_code(test_code, %{test: true})
      
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
    fallback_provider = Config.get_fallback_provider()
    
    case try_provider(operation, primary_provider) do
      %Response{success: true} = response ->
        response
      
      %Response{success: false} = primary_response ->
        Logger.warning("Primary provider #{primary_provider} failed: #{primary_response.error}")
        Logger.info("Falling back to #{fallback_provider} provider")
        
        case try_provider(operation, fallback_provider) do
          %Response{success: true} = fallback_response ->
            fallback_response
          
          %Response{success: false} = fallback_response ->
            Logger.error("Fallback provider #{fallback_provider} also failed: #{fallback_response.error}")
            # Return the primary error, but note the fallback attempt
            %{primary_response | 
              metadata: Map.put(primary_response.metadata, :fallback_attempted, true)
            }
        end
    end
  end

  defp try_provider(operation, provider) do
    try do
      operation.(provider)
    rescue
      error ->
        Logger.error("Provider #{provider} raised an exception: #{inspect(error)}")
        Response.error(
          "Provider #{provider} encountered an unexpected error: #{inspect(error)}",
          provider,
          %{exception: true, error_type: error.__struct__}
        )
    end
  end
end 