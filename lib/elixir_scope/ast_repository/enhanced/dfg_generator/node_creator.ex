defmodule ElixirScope.ASTRepository.Enhanced.DFGGenerator.NodeCreator do
  @moduledoc """
  Creates DFG nodes for different AST constructs.
  """

  alias ElixirScope.ASTRepository.Enhanced.{DFGNode, VariableVersion}
  alias ElixirScope.ASTRepository.Enhanced.DFGGenerator.StateManager

  @doc """
  Creates a DFG node and adds it to the state.
  """
  def create_dfg_node(state, type, line, metadata) do
    node_id = "dfg_node_#{state.node_counter + 1}"

    # Create proper DFGNode struct
    node = %DFGNode{
      id: node_id,
      type: type,
      ast_node_id: extract_ast_node_from_metadata(metadata),
      variable: case extract_variable_name_from_metadata(metadata) do
        nil -> nil
        var_name -> %VariableVersion{
          name: var_name,
          version: 0,
          ssa_name: var_name,
          scope_id: StateManager.scope_to_string(state.current_scope),
          definition_node: node_id,
          type_info: nil,
          is_parameter: type == :parameter,
          is_captured: false,
          metadata: %{}
        }
      end,
      operation: case type do
        :call -> Map.get(metadata, :function)
        :pipe_operation -> :pipe
        _ -> nil
      end,
      line: line,
      metadata: metadata
    }

    new_state = %{
      state |
      nodes: Map.put(state.nodes, node_id, node),
      node_counter: state.node_counter + 1
    }

    {new_state, node_id}
  end

  @doc """
  Creates nodes for pattern matching constructs.
  """
  def create_pattern_node(state, pattern_type, line, pattern_info) do
    create_dfg_node(state, :pattern_match, line, %{
      pattern_type: pattern_type,
      pattern: pattern_info
    })
  end

  @doc """
  Creates nodes for control flow constructs.
  """
  def create_control_flow_node(state, control_type, line, control_info) do
    create_dfg_node(state, control_type, line, control_info)
  end

  @doc """
  Creates nodes for function calls.
  """
  def create_call_node(state, function_name, args, line) do
    create_dfg_node(state, :call, line, %{
      function: function_name,
      arguments: args,
      arity: length(args)
    })
  end

  @doc """
  Creates nodes for variable references.
  """
  def create_variable_node(state, var_name, node_type, line) do
    create_dfg_node(state, node_type, line, %{
      variable: var_name
    })
  end

  @doc """
  Adds phi nodes to the state (for SSA form).
  """
  def add_phi_nodes_to_state(state, phi_nodes) do
    # Convert phi nodes to actual DFG nodes and add them to the state
    {state, phi_node_structs} = Enum.reduce(phi_nodes, {state, []}, fn phi_node, {state, acc} ->
      line = Map.get(phi_node, :line, 1)  # Default line if not present
      {new_state, node_id} = create_dfg_node(state, :phi, line, %{
        variable: phi_node.variable,
        branches: phi_node.branches,
        conditional_node: Map.get(phi_node, :conditional_node),
        case_node: Map.get(phi_node, :case_node)
      })
      phi_struct = %{
        node_id: node_id,
        type: :phi,
        line: line,
        variable: phi_node.variable,
        branches: phi_node.branches
      }
      {new_state, [phi_struct | acc]}
    end)
    {state, Enum.reverse(phi_node_structs)}
  end

  @doc """
  Creates nodes for comprehensions.
  """
  def create_comprehension_node(state, comprehension_type, line, comprehension_info) do
    create_dfg_node(state, :comprehension, line, Map.put(comprehension_info, :type, comprehension_type))
  end

  @doc """
  Creates nodes for anonymous functions.
  """
  def create_anonymous_function_node(state, clauses, line) do
    create_dfg_node(state, :anonymous_function, line, %{
      clauses: length(clauses)
    })
  end

  @doc """
  Creates nodes for pipe operations.
  """
  def create_pipe_node(state, left_expr, right_expr, line) do
    create_dfg_node(state, :pipe_operation, line, %{
      left: left_expr,
      right: right_expr
    })
  end

  # Private helper functions

  defp extract_variable_name_from_metadata(metadata) do
    case metadata do
      %{variable: var_name} when is_atom(var_name) -> to_string(var_name)
      %{variable: var_name} when is_binary(var_name) -> var_name
      _ -> nil
    end
  end

  defp extract_ast_node_from_metadata(metadata) do
    case metadata do
      %{source: ast_node} -> ast_node
      %{pattern: ast_node} -> ast_node
      %{expression: ast_node} -> ast_node
      _ -> nil
    end
  end
end
