defmodule ElixirScope.ASTRepository.Enhanced.DFGGenerator.EdgeCreator do
  @moduledoc """
  Creates DFG edges representing data flow relationships.
  """

  alias ElixirScope.ASTRepository.Enhanced.DFGEdge

  @doc """
  Creates a data flow edge between nodes.
  """
  def create_data_flow_edge(source, target, type, line, state) do
    edge_id = "dfg_edge_#{length(state.edges) + 1}"

    edge = %DFGEdge{
      id: edge_id,
      type: type,
      from_node: extract_node_id(source),
      to_node: extract_node_id(target),
      label: case type do
        :data_flow -> "data"
        :mutation -> "mutates"
        :conditional_flow -> "conditional"
        :call_flow -> "call"
        :pipe_flow -> "pipe"
        :capture -> "capture"
        :assignment -> "assigns"
        :destructuring -> "destructures"
        :pin_match -> "pin match"
        :guard_dependency -> "guard"
        _ -> to_string(type)
      end,
      condition: nil,
      metadata: %{
        source: source,
        target: target,
        line_number: line,
        variable_name: extract_variable_name(target)
      }
    }

    %{state | edges: [edge | state.edges]}
  end

  @doc """
  Creates assignment edges for variable assignments.
  """
  def create_assignment_edge(source, target, line, state) do
    create_data_flow_edge(source, target, :assignment, line, state)
  end

  @doc """
  Creates mutation edges for variable reassignments.
  """
  def create_mutation_edge(old_value, new_value, line, state) do
    create_data_flow_edge(old_value, new_value, :mutation, line, state)
  end

  @doc """
  Creates conditional flow edges.
  """
  def create_conditional_edge(condition, branch, line, state) do
    create_data_flow_edge(condition, branch, :conditional_flow, line, state)
  end

  @doc """
  Creates pipe flow edges.
  """
  def create_pipe_edge(left, right, line, state) do
    create_data_flow_edge(left, right, :pipe_flow, line, state)
  end

  @doc """
  Creates call flow edges from arguments to function calls.
  """
  def create_call_edge(arg, function, line, state) do
    create_data_flow_edge(arg, function, :call_flow, line, state)
  end

  @doc """
  Creates capture edges for closures.
  """
  def create_capture_edge(captured_var, closure, line, state) do
    create_data_flow_edge(captured_var, closure, :capture, line, state)
  end

  @doc """
  Creates destructuring edges for pattern matching.
  """
  def create_destructuring_edge(source, target, line, state) do
    create_data_flow_edge(source, target, :destructuring, line, state)
  end

  @doc """
  Generates data flow edges based on variable dependencies.
  """
  def generate_data_flow_edges(state) do
    # Generate edges that represent data dependencies between variables
    variables = state.variables

    edges = Enum.flat_map(variables, fn {{var_name, _scope}, var_info} ->
      case var_info.source do
        {op, _, args} when is_list(args) ->
          # Create edges from each argument variable to this variable
          Enum.flat_map(args, fn arg ->
            case extract_variable_name(arg) do
              nil -> []
              source_var ->
                [%DFGEdge{
                  id: "data_flow_#{:erlang.phash2({source_var, var_name})}",
                  type: :data_flow,
                  from_node: "var_#{source_var}",
                  to_node: "var_#{var_name}",
                  label: "data dependency",
                  condition: nil,
                  metadata: %{
                    operation: op,
                    source_variable: source_var,
                    target_variable: to_string(var_name)
                  }
                }]
            end
          end)
        _ -> []
      end
    end)

    edges
  end

  @doc """
  Creates edges for control flow dependencies.
  """
  def create_control_flow_edges(state, control_nodes) do
    # Create edges between control flow nodes and their dependent variables
    Enum.reduce(control_nodes, state, fn control_node, acc_state ->
      case control_node.type do
        :case ->
          create_case_flow_edges(control_node, acc_state)
        :conditional ->
          create_conditional_flow_edges(control_node, acc_state)
        :try_expression ->
          create_try_flow_edges(control_node, acc_state)
        _ ->
          acc_state
      end
    end)
  end

  # Private helper functions

  defp extract_node_id(expr) do
    # Generate a simple node ID from expression
    case expr do
      {var_name, _, nil} when is_atom(var_name) -> "var_#{var_name}"
      {func, _, _} when is_atom(func) -> "call_#{func}"
      node_id when is_binary(node_id) -> node_id  # Already a node ID
      _ -> "expr_#{:erlang.phash2(expr)}"
    end
  end

  defp extract_variable_name(expr) do
    case expr do
      {var_name, _, nil} when is_atom(var_name) -> to_string(var_name)
      {var_name, _, _context} when is_atom(var_name) -> to_string(var_name)
      var_name when is_atom(var_name) -> to_string(var_name)
      var_name when is_binary(var_name) -> var_name
      _ -> nil
    end
  end

  defp create_case_flow_edges(case_node, state) do
    # Create edges from case expression to each branch
    case case_node.metadata do
      %{expression: expr, branches: _branch_count} ->
        # Find variables defined in case branches
        case_variables = find_case_branch_variables(state, case_node)

        Enum.reduce(case_variables, state, fn var_name, acc_state ->
          create_data_flow_edge(expr, var_name, :case_flow, case_node.line, acc_state)
        end)
      _ ->
        state
    end
  end

  defp create_conditional_flow_edges(conditional_node, state) do
    # Create edges from condition to variables defined in branches
    case conditional_node.metadata do
      %{condition: condition} ->
        conditional_variables = find_conditional_branch_variables(state, conditional_node)

        Enum.reduce(conditional_variables, state, fn var_name, acc_state ->
          create_data_flow_edge(condition, var_name, :conditional_flow, conditional_node.line, acc_state)
        end)
      _ ->
        state
    end
  end

  defp create_try_flow_edges(try_node, state) do
    # Create edges for try/rescue/catch flow
    try_variables = find_try_block_variables(state, try_node)

    Enum.reduce(try_variables, state, fn var_name, acc_state ->
      create_data_flow_edge(:try_block, var_name, :try_flow, try_node.line, acc_state)
    end)
  end

  defp find_case_branch_variables(state, _case_node) do
    # Find variables that were defined in case branches
    # This is a simplified implementation
    state.variables
    |> Enum.filter(fn {{_var_name, _scope}, var_info} ->
      var_info.type == :pattern_match
    end)
    |> Enum.map(fn {{var_name, _scope}, _var_info} -> to_string(var_name) end)
    |> Enum.take(3)  # Limit to avoid too many edges
  end

  defp find_conditional_branch_variables(state, _conditional_node) do
    # Find variables assigned in conditional branches
    state.variables
    |> Enum.filter(fn {{_var_name, _scope}, var_info} ->
      var_info.type == :assignment
    end)
    |> Enum.map(fn {{var_name, _scope}, _var_info} -> to_string(var_name) end)
    |> Enum.take(2)  # Limit for if/else branches
  end

  defp find_try_block_variables(state, _try_node) do
    # Find variables defined in try blocks
    state.variables
    |> Enum.filter(fn {{_var_name, scope}, _var_info} ->
      case scope do
        {:rescue_clause, _} -> true
        {:catch_clause, _} -> true
        _ -> false
      end
    end)
    |> Enum.map(fn {{var_name, _scope}, _var_info} -> to_string(var_name) end)
  end
end
