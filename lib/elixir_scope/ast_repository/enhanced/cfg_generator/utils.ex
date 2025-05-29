defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.Utils do
  @moduledoc """
  Utility functions for CFGGenerator.
  """

  def generate_node_id(prefix, state \\ nil) do
    if state do
      id = "#{prefix}_#{state.next_node_id}"
      {id, %{state | next_node_id: state.next_node_id + 1}}
    else
      "#{prefix}_#{:erlang.unique_integer([:positive])}"
    end
  end

  def generate_scope_id(prefix, state) do
    "#{prefix}_#{state.scope_counter + 1}"
  end

  def get_ast_node_id(meta) do
    Keyword.get(meta, :ast_node_id)
  end

  def get_line_number(meta) do
    Keyword.get(meta, :line, 1)
  end

  def get_entry_nodes(nodes) when map_size(nodes) == 0, do: []
  def get_entry_nodes(nodes) do
    # Find nodes with no predecessors
    nodes
    |> Map.values()
    |> Enum.filter(fn node -> length(node.predecessors) == 0 end)
    |> Enum.map(& &1.id)
    |> case do
      [] -> [nodes |> Map.keys() |> List.first()]  # Fallback to first node
      entry_nodes -> entry_nodes
    end
  end

  def extract_function_key({:def, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    {UnknownModule, name, arity}
  end

  def extract_function_key({:defp, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    {UnknownModule, name, arity}
  end

  def extract_function_key(_), do: {UnknownModule, :unknown, 0}

  def extract_function_parameters({_name, _meta, args}) when is_list(args) do
    Enum.map(args, fn
      {var, _meta, nil} when is_atom(var) -> Atom.to_string(var)
      _ -> "unknown_param"
    end)
  end

  def extract_function_parameters(_), do: []

  def extract_pattern_variables(pattern) do
    # Extract variable names from pattern
    case pattern do
      {var, _meta, nil} when is_atom(var) -> [Atom.to_string(var)]
      {_constructor, _meta, args} when is_list(args) ->
        Enum.flat_map(args, &extract_pattern_variables/1)
      _ -> []
    end
  end

  def calculate_pattern_probability(_pattern) do
    # Simplified probability - could be more sophisticated
    0.5
  end

  def estimate_lines_of_code(nodes) do
    # Estimate lines of code from nodes
    nodes
    |> Map.values()
    |> Enum.map(& &1.line)
    |> Enum.max(fn -> 1 end)
  end

  def create_fake_ast_from_nodes(nodes) do
    # Create a minimal AST representation for ComplexityMetrics
    # This is a temporary workaround
    node_count = map_size(nodes)

    # Create a simple function AST with appropriate complexity
    case node_count do
      0 ->
        # Empty function
        {:def, [], [{:empty_function, [], []}, [do: nil]]}
      n when n <= 5 ->
        {:def, [], [{:simple_function, [], [{:x, [], nil}]}, [do: {:x, [], nil}]]}
      n when n <= 10 ->
        {:def, [], [{:medium_function, [], [{:x, [], nil}]},
          [do: {:if, [], [{:>, [], [{:x, [], nil}, 0]}, [do: {:x, [], nil}, else: 0]]}]]}
      _ ->
        {:def, [], [{:complex_function, [], [{:x, [], nil}]},
          [do: {:case, [], [{:x, [], nil},
            [do: [{:->, [], [[1], :one]}, {:->, [], [[2], :two]}, {:->, [], [[{:_, [], nil}], :other]}]]]}]]}
    end
  end

  def calculate_max_nesting_depth(scopes) do
    # Calculate maximum nesting depth from scopes
    scopes
    |> Map.values()
    |> Enum.map(&calculate_scope_depth(&1, scopes, 0))
    |> Enum.max(fn -> 1 end)
  end

  def calculate_scope_depth(scope, all_scopes, current_depth) do
    case scope.parent_scope do
      nil -> current_depth
      parent_id ->
        parent_scope = Map.get(all_scopes, parent_id)
        if parent_scope do
          calculate_scope_depth(parent_scope, all_scopes, current_depth + 1)
        else
          current_depth
        end
    end
  end

  def get_scope_nesting_level(scope_id, scopes) do
    case Map.get(scopes, scope_id) do
      nil -> 0
      scope -> calculate_scope_depth(scope, scopes, 0)
    end
  end

  def get_literal_type(literal) do
    cond do
      is_atom(literal) -> :atom
      is_number(literal) -> :number
      is_binary(literal) -> :string
      is_list(literal) -> :list
      true -> :unknown
    end
  end
end 