# ==============================================================================
# AST Analysis Component
# ==============================================================================

defmodule ElixirScope.ASTRepository.ModuleData.ASTAnalyzer do
  @moduledoc """
  Analyzes AST structures to extract module types, exports, and callbacks.
  """

  @doc """
  Detects the module type based on AST patterns.
  """
  @spec detect_module_type(term()) :: atom()
  def detect_module_type(ast) do
    cond do
      has_use_directive?(ast, GenServer) -> :genserver
      has_use_directive?(ast, Supervisor) -> :supervisor
      has_use_directive?(ast, Agent) -> :agent
      has_use_directive?(ast, Task) -> :task
      has_phoenix_controller_pattern?(ast) -> :phoenix_controller
      has_phoenix_live_view_pattern?(ast) -> :phoenix_live_view
      has_ecto_schema_pattern?(ast) -> :ecto_schema
      true -> :module
    end
  end

  @doc """
  Extracts public function definitions from AST.
  """
  @spec extract_exports(term()) :: [{atom(), non_neg_integer()}]
  def extract_exports(ast) do
    case ast do
      {:defmodule, _, [_module_name, [do: body]]} ->
        extract_function_definitions(body, :public)
      _ ->
        []
    end
  end

  @doc """
  Extracts OTP callback implementations from AST.
  """
  @spec extract_callbacks(term()) :: [map()]
  def extract_callbacks(ast) do
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        extract_callback_functions(body)
      _ ->
        []
    end
  end

  # Private implementation
  defp has_use_directive?(ast, target_module) do
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        find_use_directive(body, target_module)
      _ ->
        false
    end
  end

  defp find_use_directive({:__block__, _, statements}, target_module) do
    Enum.any?(statements, &check_use_statement(&1, target_module))
  end

  defp find_use_directive(statement, target_module) do
    check_use_statement(statement, target_module)
  end

  defp check_use_statement({:use, _, [{:__aliases__, _, modules}]}, target_module) do
    ast_module = List.last(modules)
    target_atom = case target_module do
      atom when is_atom(atom) ->
        atom |> Module.split() |> List.last() |> String.to_atom()
      _ -> target_module
    end
    ast_module == target_atom
  end

  defp check_use_statement({:use, _, [module]}, target_module) when is_atom(module) do
    module == target_module
  end

  defp check_use_statement(_, _), do: false

  defp has_phoenix_controller_pattern?(ast) do
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_controller_use_directive?(body) or has_controller_functions?(body)
      _ ->
        false
    end
  end

  defp has_controller_use_directive?({:__block__, _, statements}) do
    Enum.any?(statements, &is_controller_use_statement?/1)
  end

  defp has_controller_use_directive?(statement) do
    is_controller_use_statement?(statement)
  end

  defp is_controller_use_statement?({:use, _, [{:__aliases__, _, modules}]}) do
    case modules do
      [_, "Web"] -> true
      ["Phoenix", "Controller"] -> true
      _ -> false
    end
  end

  defp is_controller_use_statement?({:use, _, [module, :controller]}) when is_atom(module) do
    true
  end

  defp is_controller_use_statement?(_), do: false

  defp has_controller_functions?({:__block__, _, statements}) do
    Enum.any?(statements, &is_controller_function?/1)
  end

  defp has_controller_functions?(statement) do
    is_controller_function?(statement)
  end

  defp is_controller_function?({:def, _, [{name, _, _} | _]}) when name in [:index, :show, :new, :create, :edit, :update, :delete] do
    true
  end

  defp is_controller_function?(_), do: false

  defp has_phoenix_live_view_pattern?(ast) do
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_live_view_use_directive?(body) or has_live_view_functions?(body)
      _ ->
        false
    end
  end

  defp has_live_view_use_directive?({:__block__, _, statements}) do
    Enum.any?(statements, &is_live_view_use_statement?/1)
  end

  defp has_live_view_use_directive?(statement) do
    is_live_view_use_statement?(statement)
  end

  defp is_live_view_use_statement?({:use, _, [{:__aliases__, _, modules}]}) do
    case modules do
      ["Phoenix", "LiveView"] -> true
      [_, "Web", "LiveView"] -> true
      _ -> false
    end
  end

  defp is_live_view_use_statement?(_), do: false

  defp has_live_view_functions?({:__block__, _, statements}) do
    Enum.any?(statements, &is_live_view_function?/1)
  end

  defp has_live_view_functions?(statement) do
    is_live_view_function?(statement)
  end

  defp is_live_view_function?({:def, _, [{name, _, _} | _]}) when name in [:mount, :handle_event, :handle_info, :handle_params, :render] do
    true
  end

  defp is_live_view_function?(_), do: false

  defp has_ecto_schema_pattern?(ast) do
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_ecto_use_directive?(body) or has_schema_definition?(body)
      _ ->
        false
    end
  end

  defp has_ecto_use_directive?({:__block__, _, statements}) do
    Enum.any?(statements, &is_ecto_use_statement?/1)
  end

  defp has_ecto_use_directive?(statement) do
    is_ecto_use_statement?(statement)
  end

  defp is_ecto_use_statement?({:use, _, [{:__aliases__, _, modules}]}) do
    case modules do
      ["Ecto", "Schema"] -> true
      [_, "Schema"] -> true
      _ -> false
    end
  end

  defp is_ecto_use_statement?(_), do: false

  defp has_schema_definition?({:__block__, _, statements}) do
    Enum.any?(statements, &is_schema_statement?/1)
  end

  defp has_schema_definition?(statement) do
    is_schema_statement?(statement)
  end

  defp is_schema_statement?({:schema, _, _}), do: true
  defp is_schema_statement?({:embedded_schema, _, _}), do: true
  defp is_schema_statement?(_), do: false

  defp extract_callback_functions({:__block__, _, statements}) do
    statements
    |> Enum.filter(&is_callback_function?/1)
    |> Enum.map(&extract_callback_info/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_callback_functions(statement) do
    if is_callback_function?(statement) do
      case extract_callback_info(statement) do
        nil -> []
        callback -> [callback]
      end
    else
      []
    end
  end

  defp is_callback_function?({:def, _, [{name, _, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0

    case {name, arity} do
      {:init, 1} -> true
      {:handle_call, 3} -> true
      {:handle_cast, 2} -> true
      {:handle_info, 2} -> true
      {:terminate, 2} -> true
      {:code_change, 3} -> true
      {:handle_continue, 2} -> true
      {:mount, 3} -> true
      {:handle_event, 3} -> true
      {:handle_params, 3} -> true
      {:render, 1} -> true
      {:action, 2} -> true
      {:run, 1} -> true
      _ -> false
    end
  end

  defp is_callback_function?(_), do: false

  defp extract_callback_info({:def, _, [{name, _, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0

    %{
      name: name,
      arity: arity,
      type: determine_callback_type(name, arity)
    }
  end

  defp extract_callback_info(_), do: nil

  defp determine_callback_type(name, arity) do
    case {name, arity} do
      {:init, 1} -> :genserver
      {:handle_call, 3} -> :genserver
      {:handle_cast, 2} -> :genserver
      {:handle_info, 2} -> :genserver
      {:terminate, 2} -> :genserver
      {:code_change, 3} -> :genserver
      {:handle_continue, 2} -> :genserver
      {:mount, 3} -> :live_view
      {:handle_event, 3} -> :live_view
      {:handle_params, 3} -> :live_view
      {:render, 1} -> :live_view
      {:action, 2} -> :controller
      {:run, 1} -> :task
      _ -> :unknown
    end
  end

  defp extract_function_definitions(_body, _visibility) do
    # TODO: Implement function definition extraction
    []
  end
end
