defmodule ElixirScope.AI.LLM.Providers.Vertex do
  @moduledoc """
  Vertex AI LLM provider for real AI-powered code analysis.
  
  Makes HTTP requests to Google's Vertex AI API using service account
  authentication for code analysis, error explanation, and fix suggestions.
  """

  @behaviour ElixirScope.AI.LLM.Provider

  alias ElixirScope.AI.LLM.{Response, Config}

  require Logger

  @doc """
  Analyzes code using Vertex AI API.
  """
  @impl true
  @spec analyze_code(String.t(), map()) :: Response.t()
  def analyze_code(code, context) do
    Logger.info("Vertex: Starting code_analysis request")
    prompt = build_code_analysis_prompt(code, context)
    perform_request(prompt, "code_analysis")
  end

  @doc """
  Explains an error using Vertex AI API.
  """
  @impl true
  @spec explain_error(String.t(), map()) :: Response.t()
  def explain_error(error_message, context) do
    Logger.info("Vertex: Starting error_explanation request")
    prompt = build_error_explanation_prompt(error_message, context)
    perform_request(prompt, "error_explanation")
  end

  @doc """
  Suggests a fix using Vertex AI API.
  """
  @impl true
  @spec suggest_fix(String.t(), map()) :: Response.t()
  def suggest_fix(problem_description, context) do
    Logger.info("Vertex: Starting fix_suggestion request")
    prompt = build_fix_suggestion_prompt(problem_description, context)
    perform_request(prompt, "fix_suggestion")
  end

  @impl true
  def provider_name, do: :vertex

  @impl true
  def configured? do
    case Config.get_vertex_credentials() do
      nil -> 
        Logger.debug("Vertex: No credentials found")
        false
      credentials when is_map(credentials) ->
        required_keys = ["type", "project_id", "private_key", "client_email"]
        has_required = Enum.all?(required_keys, &Map.has_key?(credentials, &1))
        Logger.debug("Vertex: Credentials validation: #{has_required}")
        has_required
    end
  end

  @impl true
  def test_connection do
    Logger.info("Vertex: Testing connection...")
    analyze_code("def test, do: :ok", %{test: true})
  end

  # Private functions

  # Helper function to redact sensitive information from HTTPoison responses
  defp redact_http_response({:ok, %HTTPoison.Response{} = response}) do
    redacted_request = if response.request do
      %{response.request | 
        headers: redact_headers(response.request.headers),
        body: if(String.length(response.request.body || "") > 100, do: "[REDACTED - #{String.length(response.request.body)} bytes]", else: response.request.body)
      }
    else
      nil
    end
    
    {:ok, %{response | request: redacted_request}}
  end
  defp redact_http_response({:error, error}), do: {:error, error}
  defp redact_http_response(other), do: other

  defp redact_headers(headers) when is_list(headers) do
    Enum.map(headers, fn
      {"Authorization", _} -> {"Authorization", "Bearer ***REDACTED***"}
      {key, value} -> {key, value}
    end)
  end
  defp redact_headers(headers), do: headers

  defp perform_request(prompt, analysis_type) do
    case get_access_token() do
      {:ok, access_token} ->
        perform_request_with_retry(prompt, access_token, analysis_type, 3)
      {:error, error} ->
        Logger.error("Vertex: Failed to get access token: #{inspect(error)}")
        Response.error("Failed to authenticate with Vertex AI: #{inspect(error)}", :vertex, %{
          analysis_type: analysis_type,
          error_type: :authentication_failed
        })
    end
  end

  defp perform_request_with_retry(prompt, access_token, analysis_type, retries_left) do
    require Logger
    
    url = build_api_url()
    headers = build_headers(access_token)
    body = build_request_body(prompt)
    
    # Add appropriate timeout for tests and better error handling
    timeout = cond do
      Mix.env() == :test and test_mode_allows_http?() -> 30_000  # 30 seconds for live API tests
      Mix.env() == :test -> 5_000  # 5 seconds for unit tests
      true -> Config.get_request_timeout()  # Default for production
    end
    
    # Log the raw request details (with redacted access token)
    redacted_url = String.replace(url, ~r/projects\/[^\/]+/, "projects/***PROJECT***")
    Logger.info("Vertex: Making API request to: #{redacted_url}")
    Logger.debug("Vertex: Request headers: #{inspect(Enum.map(headers, fn {k, v} -> if k == "Authorization", do: {k, "Bearer ***REDACTED***"}, else: {k, v} end))}")
    Logger.debug("Vertex: Request body: #{body}")
    Logger.info("Vertex: Request timeout: #{timeout}ms, retries left: #{retries_left}")
    start_time = System.monotonic_time(:millisecond)
    http_result = HTTPoison.post(url, body, headers, timeout: timeout, recv_timeout: timeout)
    end_time = System.monotonic_time(:millisecond)
    Logger.info("Vertex: HTTP request completed in #{end_time - start_time}ms")
    
    # Only log detailed response info at debug level and with redaction
    if Logger.level() == :debug do
      redacted_result = redact_http_response(http_result)
      Logger.debug("Vertex: HTTPoison response: #{inspect(redacted_result, limit: 200)}")
    end
    
    case http_result do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body} = response} ->
        Logger.info("Vertex: Successful API response (#{response.status_code})")
        Logger.debug("Vertex: Raw response body: #{response_body}")
        Logger.debug("Vertex: Response headers: #{inspect(response.headers)}")
        parse_success_response(response_body, analysis_type)
      
      {:ok, %HTTPoison.Response{status_code: 401, body: _error_body}} when retries_left > 0 ->
        # Authentication error - try to refresh token and retry
        Logger.warning("Vertex: Authentication failed, refreshing token and retrying (#{retries_left} retries left)")
        case get_access_token(true) do  # Force refresh
          {:ok, new_access_token} ->
            :timer.sleep(1000)
            perform_request_with_retry(prompt, new_access_token, analysis_type, retries_left - 1)
          {:error, error} ->
            Logger.error("Vertex: Token refresh failed: #{inspect(error)}")
            Response.error("Authentication failed and token refresh failed", :vertex, %{
              analysis_type: analysis_type,
              error_type: :authentication_failed,
              details: error
            })
        end
      
      {:ok, %HTTPoison.Response{status_code: 429, body: _error_body}} when retries_left > 0 ->
        # Rate limiting - wait and retry
        Logger.warning("Vertex: Rate limited, retrying in 2 seconds (#{retries_left} retries left)")
        :timer.sleep(2000)
        perform_request_with_retry(prompt, access_token, analysis_type, retries_left - 1)
      
      {:ok, %HTTPoison.Response{status_code: status_code, body: _error_body}} when status_code >= 500 and retries_left > 0 ->
        # Server error - wait and retry
        Logger.warning("Vertex: Server error #{status_code}, retrying in 1 second (#{retries_left} retries left)")
        :timer.sleep(1000)
        perform_request_with_retry(prompt, access_token, analysis_type, retries_left - 1)
      
      {:ok, %HTTPoison.Response{status_code: status_code, body: error_body}} ->
        Logger.error("Vertex: API error #{status_code}")
        Logger.debug("Vertex: Error response body: #{error_body}")
        error_message = parse_error_response(error_body, status_code)
        Response.error(error_message, :vertex, %{
          analysis_type: analysis_type,
          status_code: status_code,
          error_body: error_body
        })
      
      {:error, %HTTPoison.Error{reason: :nxdomain}} ->
        Logger.error("Vertex: DNS resolution failed")
        Response.error("DNS resolution failed - check network connection", :vertex, %{
          analysis_type: analysis_type,
          error_type: :network_error
        })
      
      {:error, %HTTPoison.Error{reason: :timeout}} ->
        Logger.error("Vertex: Request timeout")
        Response.error("Request timeout - Vertex AI API did not respond in time", :vertex, %{
          analysis_type: analysis_type,
          error_type: :timeout,
          timeout_ms: timeout
        })
      
      {:error, error} ->
        # Redact any sensitive information from error details
        safe_error = case error do
          %HTTPoison.Error{} = http_error -> 
            # HTTPoison.Error doesn't typically contain sensitive data, but be safe
            http_error
          other -> 
            # For other error types, inspect but limit output
            inspect(other, limit: 100)
        end
        Logger.error("Vertex: HTTP request failed: #{inspect(safe_error)}")
        Response.error("HTTP request failed: #{inspect(safe_error)}", :vertex, %{
          analysis_type: analysis_type,
          error_type: :http_error,
          details: safe_error
        })
    end
  end

  defp get_access_token(force_refresh \\ false) do
    Logger.debug("Vertex: Getting access token, force_refresh: #{force_refresh}")
    # Simple in-memory caching with expiration
    cache_key = :vertex_access_token
    
    case Process.get(cache_key) do
      {token, expires_at} when not force_refresh ->
        current_time = System.system_time(:second)
        if expires_at > current_time do
          Logger.debug("Vertex: Using cached token")
          {:ok, token}
        else
          Logger.debug("Vertex: Cached token expired, generating new one")
          generate_and_cache_token()
        end
      _ ->
        Logger.debug("Vertex: No cached token found, generating new one")
        generate_and_cache_token()
    end
  end

  defp generate_and_cache_token do
    Logger.debug("Vertex: Generating and caching new token")
    case generate_access_token() do
      {:ok, token} ->
        # Cache for 55 minutes (tokens expire in 1 hour)
        expires_at = System.system_time(:second) + 3300
        Logger.info("Vertex: Successfully generated access token")
        Process.put(:vertex_access_token, {token, expires_at})
        {:ok, token}
      error ->
        Logger.error("Vertex: Failed to generate token: #{inspect(error)}")
        error
    end
  end

  defp generate_access_token do
    credentials = Config.get_vertex_credentials()
    
    if credentials do
      case create_jwt(credentials) do
        {:ok, jwt} ->
          exchange_jwt_for_token(jwt)
        error ->
          error
      end
    else
      {:error, "No Vertex AI credentials found"}
    end
  end

  defp create_jwt(credentials) do
    now = System.system_time(:second)
    
    header = %{
      "alg" => "RS256",
      "typ" => "JWT"
    }
    
    payload = %{
      "iss" => credentials["client_email"],
      "scope" => "https://www.googleapis.com/auth/cloud-platform",
      "aud" => "https://oauth2.googleapis.com/token",
      "exp" => now + 3600,  # 1 hour
      "iat" => now
    }
    
    try do
      # Parse the private key - handle escaped newlines from JSON
      private_key_pem = credentials["private_key"]
      |> String.replace("\\n", "\n")
      
      # Decode PEM to get the DER-encoded private key
      case :public_key.pem_decode(private_key_pem) do
        [pem_entry | _] ->
          # Extract the private key from the PEM entry
          private_key = :public_key.pem_entry_decode(pem_entry)
          
          # Create JWT using base64url encoding (no padding)
          header_json = Jason.encode!(header)
          payload_json = Jason.encode!(payload)
          
          header_b64 = encode_base64url(header_json)
          payload_b64 = encode_base64url(payload_json)
          
          message = "#{header_b64}.#{payload_b64}"
          signature = :public_key.sign(message, :sha256, private_key)
          signature_b64 = encode_base64url(signature)
          
          jwt = "#{message}.#{signature_b64}"
          {:ok, jwt}
        
        [] ->
          {:error, "No valid private key found in PEM"}
      end
    rescue
      error ->
        Logger.error("Vertex: Failed to create JWT: #{inspect(error)}")
        {:error, "Failed to create JWT: #{inspect(error)}"}
    end
  end

  # Base64url encoding (RFC 4648 Section 5) - no padding
  defp encode_base64url(data) do
    data
    |> Base.encode64()
    |> String.replace("+", "-")
    |> String.replace("/", "_")
    |> String.trim_trailing("=")
  end

  defp exchange_jwt_for_token(jwt) do
    url = "https://oauth2.googleapis.com/token"
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
    
    body = URI.encode_query(%{
      "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
      "assertion" => jwt
    })
    
    Logger.debug("Vertex: Exchanging JWT for access token")
    
    case HTTPoison.post(url, body, headers, timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"access_token" => token}} ->
            Logger.debug("Vertex: Successfully obtained access token")
            {:ok, token}
          {:error, error} ->
            Logger.error("Vertex: Failed to parse token response: #{inspect(error)}")
            {:error, "Failed to parse token response: #{inspect(error)}"}
        end
      
      {:ok, %HTTPoison.Response{status_code: status_code, body: error_body}} ->
        Logger.error("Vertex: Token exchange failed with status #{status_code}: #{error_body}")
        {:error, "Token exchange failed with status #{status_code}: #{error_body}"}
      
      {:error, error} ->
        Logger.error("Vertex: Token exchange request failed: #{inspect(error)}")
        {:error, "Token exchange request failed: #{inspect(error)}"}
    end
  end

  defp build_api_url do
    require Logger
    credentials = Config.get_vertex_credentials()
    project_id = credentials && credentials["project_id"]
    model = Config.get_vertex_model()
    
    # Try global location first (as shown in docs), fallback to us-central1
    location = "global"
    url = "https://aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}:generateContent"
    redacted_url = String.replace(url, project_id, "***PROJECT***")
    
    Logger.debug("Vertex: API URL: #{redacted_url}")
    Logger.debug("Vertex: Model: #{model}")
    
    url
  end

  defp build_headers(access_token) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{access_token}"},
      {"User-Agent", "ElixirScope/1.0"}
    ]
    
    Logger.debug("Vertex: Built request headers (access token redacted)")
    headers
  end

  defp build_request_body(prompt) do
    # Match the exact format from the documentation
    request_data = %{
      contents: %{
        role: "user",
        parts: [
          %{
            text: prompt
          }
        ]
      }
    }
    
    body = Jason.encode!(request_data)
    Logger.debug("Vertex: Built request body (#{byte_size(body)} bytes)")
    body
  end

  defp parse_success_response(response_body, analysis_type) do
    require Logger
    Logger.debug("Vertex: Parsing success response for #{analysis_type}")
    
    case Jason.decode(response_body) do
      {:ok, %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}} | _]} = decoded} ->
        Logger.info("Vertex: Successfully extracted text response (length: #{String.length(text)})")
        Logger.debug("Vertex: Decoded response structure: #{inspect(decoded, limit: :infinity)}")
        
        Response.success(
          String.trim(text),
          0.95,
          :vertex,
          %{
            analysis_type: analysis_type,
            response_length: String.length(text)
          }
        )
      
      {:ok, response} ->
        Logger.warning("Vertex: Unexpected response format: #{inspect(response)}")
        Response.error("Unexpected response format from Vertex AI", :vertex, %{
          analysis_type: analysis_type,
          response: response
        })
      
      {:error, error} ->
        Logger.error("Vertex: Failed to parse JSON response: #{inspect(error)}")
        Response.error("Failed to parse Vertex AI response: #{inspect(error)}", :vertex, %{
          analysis_type: analysis_type,
          parse_error: error
        })
    end
  end

  defp parse_error_response(error_body, status_code) do
    case Jason.decode(error_body) do
      {:ok, %{"error" => %{"message" => message}}} ->
        "Vertex AI error (#{status_code}): #{message}"
      {:ok, %{"error" => error}} ->
        "Vertex AI error (#{status_code}): #{inspect(error)}"
      {:error, _} ->
        "Vertex AI error (#{status_code}): #{error_body}"
    end
  end

  defp test_mode_allows_http? do
    # Check if we're in a test environment that allows HTTP calls
    # This is used to determine appropriate timeouts
    System.get_env("VERTEX_JSON_FILE") != nil
  end

  # Prompt building functions (similar to Gemini but adapted for Vertex)

  defp build_code_analysis_prompt(code, context) do
    context_info = if context && is_map(context) && map_size(context) > 0 do
      "\n\nContext: #{inspect(context)}"
    else
      ""
    end

    """
    You are an expert Elixir code analyzer. Please analyze the following Elixir code and provide insights about:

    1. Code structure and organization
    2. Potential issues or improvements
    3. Design patterns used
    4. Performance considerations
    5. Best practices adherence

    Code to analyze:
    ```elixir
    #{code}
    ```#{context_info}

    Please provide a comprehensive analysis with specific recommendations.
    """
  end

  defp build_error_explanation_prompt(error_message, context) do
    context_info = if context && is_map(context) && map_size(context) > 0 do
      "\n\nContext: #{inspect(context)}"
    else
      ""
    end

    """
    You are an expert Elixir developer. Please explain the following error message in detail:

    Error: #{error_message}#{context_info}

    Please provide:
    1. What this error means
    2. Common causes of this error
    3. How to debug and fix it
    4. Best practices to prevent it in the future

    Focus on practical, actionable advice for Elixir developers.
    """
  end

  defp build_fix_suggestion_prompt(problem_description, context) do
    context_info = if context && is_map(context) && map_size(context) > 0 do
      "\n\nContext: #{inspect(context)}"
    else
      ""
    end

    """
    You are an expert Elixir developer. Please suggest fixes for the following problem:

    Problem: #{problem_description}#{context_info}

    Please provide:
    1. Specific code improvements or refactoring suggestions
    2. Alternative approaches to consider
    3. Best practices to follow
    4. Example code snippets if helpful

    Focus on practical, implementable solutions for Elixir applications.
    """
  end
end 