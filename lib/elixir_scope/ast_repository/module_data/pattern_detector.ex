# ==============================================================================
# Pattern Detection Component
# ==============================================================================

defmodule ElixirScope.ASTRepository.ModuleData.PatternDetector do
  @moduledoc """
  Detects architectural patterns in AST structures.
  """

  @doc """
  Detects architectural patterns in the given AST.
  """
  @spec detect_patterns(term()) :: [atom()]
  def detect_patterns(ast) do
    []
    |> maybe_add_pattern(:singleton, has_singleton_pattern?(ast))
    |> maybe_add_pattern(:factory, has_factory_pattern?(ast))
    |> maybe_add_pattern(:observer, has_observer_pattern?(ast))
    |> maybe_add_pattern(:state_machine, has_state_machine_pattern?(ast))
  end

  # Private implementation
  defp maybe_add_pattern(patterns, pattern, true), do: [pattern | patterns]
  defp maybe_add_pattern(patterns, _pattern, false), do: patterns

  defp has_singleton_pattern?(ast) do
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_singleton_indicators?(body)
      _ ->
        false
    end
  end

  defp has_factory_pattern?(ast) do
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_factory_indicators?(body)
      _ ->
        false
    end
  end

  defp has_observer_pattern?(ast) do
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_observer_indicators?(body)
      _ ->
        false
    end
  end

  defp has_state_machine_pattern?(ast) do
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_state_machine_indicators?(body)
      _ ->
        false
    end
  end

  defp has_singleton_indicators?({:__block__, _, statements}) do
    Enum.any?(statements, &is_singleton_function?/1)
  end

  defp has_singleton_indicators?(statement) do
    is_singleton_function?(statement)
  end

  defp is_singleton_function?({:def, _, [{name, _, _} | _]}) when name in [:instance, :get_instance, :singleton] do
    true
  end

  defp is_singleton_function?(_), do: false

  defp has_factory_indicators?({:__block__, _, statements}) do
    Enum.any?(statements, &is_factory_function?/1)
  end

  defp has_factory_indicators?(statement) do
    is_factory_function?(statement)
  end

  defp is_factory_function?({:def, _, [{name, _, _} | _]}) when name in [:create, :build, :make, :new] do
    true
  end

  defp is_factory_function?(_), do: false

  defp has_observer_indicators?({:__block__, _, statements}) do
    Enum.any?(statements, &is_observer_function?/1)
  end

  defp has_observer_indicators?(statement) do
    is_observer_function?(statement)
  end

  defp is_observer_function?({:def, _, [{name, _, _} | _]}) when name in [:notify, :subscribe, :unsubscribe, :add_observer, :remove_observer] do
    true
  end

  defp is_observer_function?(_), do: false

  defp has_state_machine_indicators?({:__block__, _, statements}) do
    Enum.any?(statements, &is_state_machine_function?/1)
  end

  defp has_state_machine_indicators?(statement) do
    is_state_machine_function?(statement)
  end

  defp is_state_machine_function?({:def, _, [{name, _, _} | _]}) when name in [:transition, :change_state, :next_state, :current_state] do
    true
  end

  defp is_state_machine_function?(_), do: false
end
