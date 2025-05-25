defmodule ElixirScope.AI.LLM.Providers.Gemini do
  @moduledoc """
  Gemini LLM provider for real AI-powered code analysis.
  
  Makes HTTP requests to Google's Gemini API for code analysis,
  error explanation, and fix suggestions.
  """

  @behaviour ElixirScope.AI.LLM.Provider

  alias ElixirScope.AI.LLM.{Response, Config}

  @doc """
  Analyzes code using Gemini API.
  """
  @impl true
  @spec analyze_code(String.t(), map()) :: Response.t()
  def analyze_code(code, context) do
    prompt = build_code_analysis_prompt(code, context)
    make_gemini_request(prompt, "code_analysis")
  end

  @doc """
  Explains an error using Gemini API.
  """
  @impl true
  @spec explain_error(String.t(), map()) :: Response.t()
  def explain_error(error_message, context) do
    prompt = build_error_explanation_prompt(error_message, context)
    make_gemini_request(prompt, "error_explanation")
  end

  @doc """
  Suggests a fix using Gemini API.
  """
  @impl true
  @spec suggest_fix(String.t(), map()) :: Response.t()
  def suggest_fix(problem_description, context) do
    prompt = build_fix_suggestion_prompt(problem_description, context)
    make_gemini_request(prompt, "fix_suggestion")
  end

  # Private functions

  defp make_gemini_request(prompt, analysis_type) do
    require Logger
    Logger.info("Gemini: Starting #{analysis_type} request")
    
    # In test environment, don't make real HTTP requests unless explicitly configured
    if Mix.env() == :test and not test_mode_allows_http?() do
      Logger.warning("Gemini: API not available in test mode without valid API key")
      Response.error("Gemini API not available in test mode without valid API key", :gemini, %{analysis_type: analysis_type})
    else
      case get_api_key() do
        nil ->
          Logger.error("Gemini: API key not configured")
          Response.error("Gemini API key not configured", :gemini, %{analysis_type: analysis_type})
        
        api_key when byte_size(api_key) < 10 ->
          Logger.error("Gemini: API key appears to be invalid (length: #{byte_size(api_key)})")
          Response.error("Gemini API key appears to be invalid", :gemini, %{analysis_type: analysis_type})
        
        api_key ->
          Logger.info("Gemini: API key found (length: #{byte_size(api_key)})")
          perform_request(prompt, api_key, analysis_type)
      end
    end
  end

  defp test_mode_allows_http? do
    # Only allow HTTP requests in test mode if we have a valid API key
    case get_api_key() do
      nil -> false
      api_key when byte_size(api_key) < 10 -> false
      _api_key -> true
    end
  end

  defp get_api_key do
    require Logger
    env_key = System.get_env("GEMINI_API_KEY")
    config_key = Config.get_gemini_api_key()
    
    cond do
      env_key ->
        Logger.debug("Gemini: Using API key from GEMINI_API_KEY environment variable")
        env_key
      config_key ->
        Logger.debug("Gemini: Using API key from config")
        config_key
      true ->
        Logger.warning("Gemini: No API key found in environment or config")
        nil
    end
  end

  defp perform_request(prompt, _api_key, analysis_type) do
    require Logger
    url = build_api_url()
    headers = build_headers()
    body = build_request_body(prompt)
    
    # Add appropriate timeout for tests and better error handling
    # Use longer timeout for live API tests, shorter for unit tests
    timeout = cond do
      Mix.env() == :test and test_mode_allows_http?() -> 30_000  # 30 seconds for live API tests
      Mix.env() == :test -> 5_000  # 5 seconds for unit tests
      true -> Config.get_request_timeout()  # Default for production
    end
    
    case HTTPoison.post(url, body, headers, timeout: timeout, recv_timeout: timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        parse_success_response(response_body, analysis_type)
      
      {:ok, %HTTPoison.Response{status_code: status_code, body: error_body}} ->
        parse_error_response(status_code, error_body, analysis_type)
      
      {:error, %HTTPoison.Error{reason: :timeout}} ->
        Response.error("Request timeout - check network connection and API key", :gemini, %{analysis_type: analysis_type})
      
      {:error, %HTTPoison.Error{reason: :nxdomain}} ->
        Response.error("DNS resolution failed - check network connection", :gemini, %{analysis_type: analysis_type})
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        Response.error("HTTP request failed: #{reason}", :gemini, %{analysis_type: analysis_type})
    end
  end

  defp build_api_url do
    base_url = Config.get_gemini_base_url()
    model = Config.get_gemini_model()
    api_key = get_api_key()
    
    "#{base_url}/v1beta/models/#{model}:generateContent?key=#{api_key}"
  end

  defp build_headers do
    [
      {"Content-Type", "application/json"},
      {"User-Agent", "ElixirScope/1.0"}
    ]
  end

  defp build_request_body(prompt) do
    request = %{
      contents: [
        %{
          parts: [
            %{text: prompt}
          ]
        }
      ],
      generationConfig: %{
        temperature: 0.3,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048
      }
    }
    
    Jason.encode!(request)
  end

  defp parse_success_response(response_body, analysis_type) do
    case Jason.decode(response_body) do
      {:ok, %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}} | _]}} ->
        Response.success(
          String.trim(text),
          0.95,
          :gemini,
          %{
            analysis_type: analysis_type,
            response_length: String.length(text)
          }
        )
      
      {:ok, response} ->
        Response.error("Unexpected response format: #{inspect(response)}", :gemini, %{analysis_type: analysis_type})
      
      {:error, reason} ->
        Response.error("JSON decode error: #{reason}", :gemini, %{analysis_type: analysis_type})
    end
  end

  defp parse_error_response(status_code, error_body, analysis_type) do
    error_message = case Jason.decode(error_body) do
      {:ok, %{"error" => %{"message" => message}}} -> message
      _ -> "HTTP #{status_code}: #{error_body}"
    end
    
    Response.error(
      "Gemini API error: #{error_message}",
      :gemini,
      %{
        analysis_type: analysis_type,
        status_code: status_code
      }
    )
  end

  # Prompt building functions

  defp build_code_analysis_prompt(code, context) do
    context_section = if map_size(context) > 0 do
      context_info = context
      |> Enum.map(fn {k, v} -> "- #{k}: #{inspect(v)}" end)
      |> Enum.join("\n")
      
      """
      
      ## Additional Context:
      #{context_info}
      """
    else
      ""
    end

    """
    You are an expert Elixir developer analyzing code for the ElixirScope development tool.

    Please analyze the following Elixir code and provide insights about:
    1. Code structure and organization
    2. Potential improvements or optimizations
    3. Best practices adherence
    4. Any potential issues or concerns
    5. Suggestions for better maintainability

    ## Code to Analyze:
    ```elixir
    #{code}
    ```#{context_section}

    Please provide a clear, actionable analysis that helps developers improve their code.
    """
  end

  defp build_error_explanation_prompt(error_message, context) do
    context_section = if map_size(context) > 0 do
      context_info = context
      |> Enum.map(fn {k, v} -> "- #{k}: #{inspect(v)}" end)
      |> Enum.join("\n")
      
      """
      
      ## Additional Context:
      #{context_info}
      """
    else
      ""
    end

    """
    You are an expert Elixir developer helping to explain errors for the ElixirScope development tool.

    Please explain the following error message in clear, understandable terms:
    1. What the error means
    2. Common causes of this error
    3. How to identify the root cause
    4. General strategies for fixing it

    ## Error Message:
    #{error_message}#{context_section}

    Please provide a helpful explanation that guides developers toward a solution.
    """
  end

  defp build_fix_suggestion_prompt(problem_description, context) do
    context_section = if map_size(context) > 0 do
      context_info = context
      |> Enum.map(fn {k, v} -> "- #{k}: #{inspect(v)}" end)
      |> Enum.join("\n")
      
      """
      
      ## Additional Context:
      #{context_info}
      """
    else
      ""
    end

    """
    You are an expert Elixir developer providing fix suggestions for the ElixirScope development tool.

    Please provide specific, actionable suggestions to address the following problem:

    ## Problem Description:
    #{problem_description}#{context_section}

    Please provide:
    1. Specific steps to fix the issue
    2. Code examples where helpful
    3. Best practices to prevent similar issues
    4. Alternative approaches if applicable

    Focus on practical, implementable solutions.
    """
  end

  @impl true
  def provider_name, do: :gemini

  @impl true
  def configured? do
    case get_api_key() do
      nil -> false
      api_key when byte_size(api_key) < 10 -> false
      _api_key -> true
    end
  end

  @impl true
  def test_connection do
    analyze_code("def test, do: :ok", %{test: true})
  end
end 