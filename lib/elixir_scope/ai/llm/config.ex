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
  Gets the primary provider to use.
  
  Returns :gemini if API key is available, otherwise :mock.
  Can be overridden with config or environment variable.
  """
  @spec get_primary_provider() :: :gemini | :mock
  def get_primary_provider do
    case Application.get_env(:elixir_scope, :llm_provider) ||
           System.get_env("LLM_PROVIDER") do
      "mock" -> :mock
      "gemini" -> :gemini
      nil ->
        if get_gemini_api_key(), do: :gemini, else: :mock
      _ -> :mock
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
  Gets the Gemini model to use.
  """
  @spec get_gemini_model() :: String.t()
  def get_gemini_model do
    Application.get_env(:elixir_scope, :gemini_model) ||
      System.get_env("GEMINI_DEFAULT_MODEL") ||
      System.get_env("GEMINI_MODEL") ||
      "gemini-1.5-flash"
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

  def valid_config?(:mock) do
    true
  end

  def valid_config?(_), do: false

  @doc """
  Gets all configuration as a map for debugging.
  Note: API keys are masked for security.
  """
  @spec debug_config() :: map()
  def debug_config do
    %{
      primary_provider: get_primary_provider(),
      fallback_provider: get_fallback_provider(),
      gemini_api_key_present: get_gemini_api_key() != nil,
      gemini_base_url: get_gemini_base_url(),
      gemini_model: get_gemini_model(),
      request_timeout: get_request_timeout()
    }
  end
end 