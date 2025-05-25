defmodule ElixirScope.AI.LLM.Provider do
  @moduledoc """
  Behaviour defining the common interface for all LLM providers in ElixirScope.
  
  This ensures all providers (Gemini, Mock, future providers) implement
  the same API, allowing for easy switching and fallback between providers.
  """

  alias ElixirScope.AI.LLM.Response

  @doc """
  Analyzes code using the provider's LLM.
  
  ## Parameters
  - `code`: The Elixir code to analyze
  - `context`: Additional context for the analysis (metadata, file info, etc.)
  
  ## Returns
  - `Response.t()`: Standardized response with analysis results
  """
  @callback analyze_code(String.t(), map()) :: Response.t()

  @doc """
  Explains an error using the provider's LLM.
  
  ## Parameters
  - `error_message`: The error message to explain
  - `context`: Additional context (code, stack trace, etc.)
  
  ## Returns
  - `Response.t()`: Standardized response with error explanation
  """
  @callback explain_error(String.t(), map()) :: Response.t()

  @doc """
  Suggests a fix for a problem using the provider's LLM.
  
  ## Parameters
  - `problem_description`: Description of the problem to fix
  - `context`: Additional context (code, error details, etc.)
  
  ## Returns
  - `Response.t()`: Standardized response with fix suggestions
  """
  @callback suggest_fix(String.t(), map()) :: Response.t()

  @doc """
  Returns the provider's name as an atom.
  
  ## Returns
  - `atom()`: Provider identifier (e.g., :gemini, :mock, :anthropic)
  """
  @callback provider_name() :: atom()

  @doc """
  Checks if the provider is properly configured and ready to use.
  
  ## Returns
  - `boolean()`: true if provider is configured, false otherwise
  """
  @callback configured?() :: boolean()

  @doc """
  Tests the provider's connectivity and basic functionality.
  
  ## Returns
  - `Response.t()`: Response indicating success or failure of connection test
  """
  @callback test_connection() :: Response.t()
end 