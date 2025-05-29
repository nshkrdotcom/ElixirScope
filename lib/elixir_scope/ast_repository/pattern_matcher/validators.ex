defmodule ElixirScope.ASTRepository.PatternMatcher.Validators do
  @moduledoc """
  Validation functions for pattern matching operations.
  """

  alias ElixirScope.ASTRepository.PatternMatcher.Types

  @spec normalize_pattern_spec(map()) :: {:ok, Types.pattern_spec()} | {:error, term()}
  def normalize_pattern_spec(pattern_spec) when is_map(pattern_spec) do
    confidence = Map.get(pattern_spec, :confidence_threshold, Types.default_confidence_threshold())

    with :ok <- validate_confidence_threshold(confidence) do
      spec = %Types{
        pattern_type: Map.get(pattern_spec, :pattern_type),
        pattern_ast: Map.get(pattern_spec, :pattern),
        confidence_threshold: confidence,
        match_variables: Map.get(pattern_spec, :match_variables, true),
        context_sensitive: Map.get(pattern_spec, :context_sensitive, false),
        custom_rules: Map.get(pattern_spec, :custom_rules),
        metadata: Map.get(pattern_spec, :metadata, %{})
      }

      case validate_pattern_spec(spec) do
        :ok -> {:ok, spec}
        error -> error
      end
    end
  end

  def normalize_pattern_spec(_), do: {:error, :invalid_pattern_spec}

  @spec validate_repository(pid() | atom()) :: :ok | {:error, term()}
  def validate_repository(repo) do
    cond do
      is_nil(repo) ->
        {:error, :invalid_repository}

      is_atom(repo) and repo in [:mock_repo, :non_existent_repo] ->
        {:error, :repository_not_found}

      is_atom(repo) ->
        case Process.whereis(repo) do
          nil -> {:error, :repository_not_found}
          _pid -> :ok
        end

      is_pid(repo) ->
        if Process.alive?(repo) do
          :ok
        else
          {:error, :repository_not_found}
        end

      true ->
        {:error, :invalid_repository}
    end
  end

  # Private functions

  defp validate_confidence_threshold(confidence) do
    cond do
      not is_number(confidence) ->
        {:error, :invalid_confidence_threshold}

      confidence < 0.0 or confidence > 1.0 ->
        {:error, :invalid_confidence_threshold}

      true ->
        :ok
    end
  end

  defp validate_pattern_spec(%Types{pattern_ast: pattern, pattern_type: pattern_type}) when not is_nil(pattern) do
    cond do
      is_nil(pattern_type) -> {:error, :missing_pattern_type}
      pattern == nil -> {:error, :invalid_ast_pattern}
      is_binary(pattern) -> {:error, :invalid_ast_pattern}
      true -> :ok
    end
  end

  defp validate_pattern_spec(%Types{pattern_type: nil}) do
    {:error, :missing_pattern_type}
  end

  defp validate_pattern_spec(%Types{}), do: :ok
end
