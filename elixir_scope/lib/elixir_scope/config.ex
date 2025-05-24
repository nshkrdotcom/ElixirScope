defmodule ElixirScope.Config do
  @moduledoc """
  Provides access to ElixirScope application configuration.

  Configuration values are retrieved from the application environment.
  This allows for overrides via Mix config files (e.g., `config/config.exs`).
  """

  @doc """
  Retrieves a configuration value for the given `key`.

  If the key is not found in the application environment, `default_value` is returned.

  ## Examples

      iex> ElixirScope.Config.get(:ai_backend_url)
      "http://localhost:8080/v1/chat/completions"

      iex> ElixirScope.Config.get(:non_existent_key, "my_default")
      "my_default"
  """
  def get(key, default_value \\ nil) do
    Application.get_env(:elixir_scope, key, default_value)
  end

  # --- Default values for common keys ---
  # These calls ensure that if these keys are accessed without a default,
  # they still return a sensible value. The actual default is provided here
  # as the third argument to Application.get_env/3 if not set in config files.

  def ai_backend_url, do: get(:ai_backend_url, "http://localhost:8080/v1/chat/completions")
  def max_trace_events, do: get(:max_trace_events, 1_000_000)
  def default_log_level, do: get(:default_log_level, :info)
end
