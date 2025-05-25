defmodule ElixirScope.AI.LLM.Config do
  @moduledoc """
  Configuration management for LLM providers.
  
  Handles API keys, provider selection, and other configuration
  options for the LLM integration layer.
  """

  @doc """
  Gets the Gemini API key from configuration or environment.
  
  Checks in order:
  1. Application config: config :elixir_scope, :gemini_api_key
  2. Environment variable: GEMINI_API_KEY
  3. Returns nil if not found
  """
  @spec get_gemini_api_key() :: String.t() | nil
  def get_gemini_api_key do
    Application.get_env(:elixir_scope, :gemini_api_key) ||
      System.get_env("GEMINI_API_KEY")
  end

  @doc """
  Gets the Vertex AI JSON credentials file path.
  
  Checks in order:
  1. Environment variable: VERTEX_JSON_FILE
  2. Application config: config :elixir_scope, :vertex_json_file
  3. Returns nil if not found
  """
  @spec get_vertex_json_file() :: String.t() | nil
  def get_vertex_json_file do
    System.get_env("VERTEX_JSON_FILE") ||
      Application.get_env(:elixir_scope, :vertex_json_file)
  end

  @doc """
  Gets the Vertex AI credentials from the JSON file.
  
  Returns a map with the parsed JSON credentials or nil if file not found/invalid.
  """
  @spec get_vertex_credentials() :: map() | nil
  def get_vertex_credentials do
    case get_vertex_json_file() do
      nil -> nil
      file_path ->
        case File.read(file_path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, credentials} -> credentials
              {:error, _} -> nil
            end
          {:error, _} -> nil
        end
    end
  end

  @doc """
  Gets the primary provider to use.
  
  Returns :vertex if Vertex credentials are available, :gemini if API key is available, otherwise :mock.
  Can be overridden with config or environment variable.
  In test environment, always returns :mock unless explicitly overridden.
  """
  @spec get_primary_provider() :: :vertex | :gemini | :mock
  def get_primary_provider do
    # In test environment, default to mock unless explicitly overridden
    if Mix.env() == :test do
      case Application.get_env(:elixir_scope, :llm_provider) ||
             System.get_env("LLM_PROVIDER") do
        "gemini" -> :gemini
        "vertex" -> :vertex
        _ -> :mock  # Default to mock in tests
      end
    else
      case Application.get_env(:elixir_scope, :llm_provider) ||
             System.get_env("LLM_PROVIDER") do
        "mock" -> :mock
        "gemini" -> :gemini
        "vertex" -> :vertex
        nil ->
          cond do
            get_vertex_credentials() -> :vertex
            get_gemini_api_key() -> :gemini
            true -> :mock
          end
        _ -> :mock
      end
    end
  end

  @doc """
  Gets the fallback provider to use when primary fails.
  """
  @spec get_fallback_provider() :: :mock
  def get_fallback_provider, do: :mock

  @doc """
  Gets the Gemini API base URL.
  """
  @spec get_gemini_base_url() :: String.t()
  def get_gemini_base_url do
    Application.get_env(:elixir_scope, :gemini_base_url) ||
      System.get_env("GEMINI_BASE_URL") ||
      "https://generativelanguage.googleapis.com"
  end

  @doc """
  Gets the Vertex AI base URL.
  """
  @spec get_vertex_base_url() :: String.t()
  def get_vertex_base_url do
    credentials = get_vertex_credentials()
    project_id = credentials && credentials["project_id"]
    
    if project_id do
      "https://us-central1-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/us-central1/publishers/google/models"
    else
      "https://us-central1-aiplatform.googleapis.com/v1/projects/PROJECT_ID/locations/us-central1/publishers/google/models"
    end
  end

  @doc """
  Gets the Gemini model to use.
  """
  @spec get_gemini_model() :: String.t()
  def get_gemini_model do
    Application.get_env(:elixir_scope, :gemini_model) ||
      System.get_env("GEMINI_DEFAULT_MODEL") ||
      System.get_env("GEMINI_MODEL") ||
      "gemini-2.0-flash"
  end

  @doc """
  Gets the Vertex AI model to use.
  """
  @spec get_vertex_model() :: String.t()
  def get_vertex_model do
    System.get_env("VERTEX_MODEL") ||
      System.get_env("VERTEX_DEFAULT_MODEL") ||
      Application.get_env(:elixir_scope, :vertex_model) ||
      "gemini-2.0-flash"
  end

  @doc """
  Gets the request timeout in milliseconds.
  """
  @spec get_request_timeout() :: integer()
  def get_request_timeout do
    case Application.get_env(:elixir_scope, :llm_timeout) ||
           System.get_env("LLM_TIMEOUT") do
      nil -> 30_000
      timeout when is_integer(timeout) -> timeout
      timeout when is_binary(timeout) -> String.to_integer(timeout)
    end
  end

  @doc """
  Checks if the configuration is valid for the given provider.
  """
  @spec valid_config?(atom()) :: boolean()
  def valid_config?(:gemini) do
    get_gemini_api_key() != nil
  end

  def valid_config?(:vertex) do
    get_vertex_credentials() != nil
  end

  def valid_config?(:mock) do
    true
  end

  def valid_config?(_), do: false

  @doc """
  Gets all configuration as a map for debugging.
  Note: API keys and credentials are masked for security.
  """
  @spec debug_config() :: map()
  def debug_config do
    %{
      primary_provider: get_primary_provider(),
      fallback_provider: get_fallback_provider(),
      gemini_api_key_present: get_gemini_api_key() != nil,
      gemini_base_url: get_gemini_base_url(),
      gemini_model: get_gemini_model(),
      vertex_credentials_present: get_vertex_credentials() != nil,
      vertex_base_url: get_vertex_base_url(),
      vertex_model: get_vertex_model(),
      request_timeout: get_request_timeout()
    }
  end
end 