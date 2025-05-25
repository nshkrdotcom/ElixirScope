defmodule ElixirScope.AI.LLM.Response do
  @moduledoc """
  Standardized response format for LLM providers.
  
  This module defines a common response structure that all providers
  (Gemini, Mock, future providers) must return, ensuring consistent
  handling throughout ElixirScope.
  """

  @type t :: %__MODULE__{
          text: String.t(),
          confidence: float(),
          provider: atom(),
          metadata: map(),
          timestamp: DateTime.t(),
          success: boolean(),
          error: String.t() | nil
        }

  defstruct [
    :text,
    :confidence,
    :provider,
    :metadata,
    :timestamp,
    :success,
    :error
  ]

  @doc """
  Creates a successful response.
  
  ## Examples
  
      iex> ElixirScope.AI.LLM.Response.success("Analysis complete", 0.95, :gemini)
      %ElixirScope.AI.LLM.Response{
        text: "Analysis complete",
        confidence: 0.95,
        provider: :gemini,
        success: true,
        error: nil
      }
  """
  @spec success(String.t(), float(), atom(), map()) :: t()
  def success(text, confidence \\ 1.0, provider, metadata \\ %{}) do
    %__MODULE__{
      text: text,
      confidence: confidence,
      provider: provider,
      metadata: metadata,
      timestamp: DateTime.utc_now(),
      success: true,
      error: nil
    }
  end

  @doc """
  Creates an error response.
  
  ## Examples
  
      iex> ElixirScope.AI.LLM.Response.error("API timeout", :gemini)
      %ElixirScope.AI.LLM.Response{
        text: "",
        confidence: 0.0,
        provider: :gemini,
        success: false,
        error: "API timeout"
      }
  """
  @spec error(String.t(), atom(), map()) :: t()
  def error(error_message, provider, metadata \\ %{}) do
    %__MODULE__{
      text: "",
      confidence: 0.0,
      provider: provider,
      metadata: metadata,
      timestamp: DateTime.utc_now(),
      success: false,
      error: error_message
    }
  end

  @doc """
  Checks if the response is successful.
  """
  @spec success?(t()) :: boolean()
  def success?(%__MODULE__{success: success}), do: success

  @doc """
  Gets the response text, returning empty string for errors.
  """
  @spec get_text(t()) :: String.t()
  def get_text(%__MODULE__{success: true, text: text}), do: text
  def get_text(%__MODULE__{success: false}), do: ""

  @doc """
  Gets the error message, returning nil for successful responses.
  """
  @spec get_error(t()) :: String.t() | nil
  def get_error(%__MODULE__{success: false, error: error}), do: error
  def get_error(%__MODULE__{success: true}), do: nil
end 