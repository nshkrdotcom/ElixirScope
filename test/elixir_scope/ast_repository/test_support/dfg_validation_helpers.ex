defmodule ElixirScope.ASTRepository.TestSupport.DFGValidationHelpers do
  @moduledoc """
  Helpers for deep DFG validation and data flow analysis.
  
  These helpers provide utilities for validating the semantic correctness
  of Data Flow Graphs, including variable lifetime analysis, dependency
  validation, and phi node verification.
  """
  
  alias ElixirScope.ASTRepository.Enhanced.{DFGGenerator, DFGData, DFGNode, DFGEdge}
  
  @doc """
  Finds nodes in a DFG by their type.
  """
  def find_nodes_by_type(dfg, node_type) do
    dfg.nodes
    |> Enum.filter(&(&1.type == node_type))
  end
  
  @doc """
  Finds a specific call node by function name.
  """
  def find_call_node(dfg, function_name) do
    dfg.nodes
    |> Enum.find(fn node ->
      node.type == :call && 
      (String.contains?(to_string(node.ast_snippet), function_name) ||
       String.contains?(to_string(node.metadata), function_name))
    end)
  end
  
  @doc """
  Finds DFG assignment nodes for a specific variable.
  """
  def find_dfg_assignment_node(dfg, variable_name) do
    dfg.nodes
    |> Enum.find(fn node ->
      node.type == :assignment && 
      (String.contains?(to_string(node.ast_snippet), variable_name) ||
       Map.get(node.metadata, :variable) == variable_name)
    end)
  end
  
  @doc """
  Checks if there's a data flow edge between two nodes or variables.
  """
  def has_data_flow_edge(dfg, source, target) do
    source_id = resolve_node_id(dfg, source)
    target_id = resolve_node_id(dfg, target)
    
    Enum.any?(dfg.edges, fn edge ->
      edge.type == :data_flow && 
      edge.source == source_id && 
      edge.target == target_id
    end)
  end
  
  @doc """
  Checks if there's a capture edge for a variable.
  """
  def has_capture_edge(dfg, variable_name, target_node_id) do
    Enum.any?(dfg.edges, fn edge ->
      edge.type == :capture && 
      edge.target == target_node_id &&
      (String.contains?(to_string(edge.metadata), variable_name) ||
       Map.get(edge.metadata, :variable) == variable_name)
    end)
  end
  
  @doc """
  Finds an edge that targets a specific node with a specific type.
  """
  def find_edge_to_node(dfg, target_node_id, edge_type) do
    Enum.find(dfg.edges, fn edge ->
      edge.target == target_node_id && edge.type == edge_type
    end)
  end
  
  @doc """
  Validates variable lifetime analysis results.
  """
  def validate_variable_lifetime(dfg, variable_name, expected_birth_line, expected_death_line) do
    case Map.get(dfg.variable_lifetimes, variable_name) do
      nil ->
        ExUnit.Assertions.flunk("Variable #{variable_name} not found in lifetime analysis")
        
      lifetime ->
        unless lifetime.birth_line == expected_birth_line do
          ExUnit.Assertions.flunk(
            "Variable #{variable_name} birth line: expected #{expected_birth_line}, got #{lifetime.birth_line}"
          )
        end
        
        unless lifetime.death_line == expected_death_line do
          ExUnit.Assertions.flunk(
            "Variable #{variable_name} death line: expected #{expected_death_line}, got #{lifetime.death_line}"
          )
        end
    end
  end
  
  @doc """
  Validates that a variable is correctly identified as unused.
  """
  def assert_variable_unused(dfg, variable_name) do
    unless variable_name in dfg.unused_variables do
      ExUnit.Assertions.flunk("Expected #{variable_name} to be identified as unused")
    end
  end
  
  @doc """
  Validates that a variable is NOT identified as unused.
  """
  def assert_variable_used(dfg, variable_name) do
    if variable_name in dfg.unused_variables do
      ExUnit.Assertions.flunk("Expected #{variable_name} to NOT be identified as unused")
    end
  end
  
  @doc """
  Validates variable shadowing detection.
  """
  def assert_variable_shadowed(dfg, variable_name, outer_line, inner_line) do
    shadow_info = Enum.find(dfg.shadowed_variables, &(&1.variable == variable_name))
    
    unless shadow_info do
      ExUnit.Assertions.flunk("Expected #{variable_name} to be identified as shadowed")
    end
    
    unless shadow_info.outer_scope_line == outer_line do
      ExUnit.Assertions.flunk(
        "Variable #{variable_name} outer scope line: expected #{outer_line}, got #{shadow_info.outer_scope_line}"
      )
    end
    
    unless shadow_info.inner_scope_line == inner_line do
      ExUnit.Assertions.flunk(
        "Variable #{variable_name} inner scope line: expected #{inner_line}, got #{shadow_info.inner_scope_line}"
      )
    end
  end
  
  @doc """
  Validates phi node structure for conditional variable definitions.
  """
  def validate_phi_node(dfg, variable_name, expected_incoming_count) do
    phi_nodes = find_nodes_by_type(dfg, :phi)
    phi_node = Enum.find(phi_nodes, fn node ->
      Map.get(node.metadata, :variable) == variable_name ||
      String.contains?(to_string(node.ast_snippet), variable_name)
    end)
    
    unless phi_node do
      ExUnit.Assertions.flunk("Expected phi node for variable #{variable_name}")
    end
    
    incoming_definitions = Map.get(phi_node.metadata, :incoming_definitions, [])
    
    unless length(incoming_definitions) == expected_incoming_count do
      ExUnit.Assertions.flunk(
        "Phi node for #{variable_name}: expected #{expected_incoming_count} incoming definitions, got #{length(incoming_definitions)}"
      )
    end
    
    phi_node
  end
  
  @doc """
  Validates data flow through a pipe chain.
  """
  def validate_pipe_data_flow(dfg, steps) do
    for {step, next_step} <- Enum.zip(steps, tl(steps)) do
      step_node = find_call_node(dfg, step)
      next_step_node = find_call_node(dfg, next_step)
      
      unless step_node do
        ExUnit.Assertions.flunk("Could not find call node for #{step}")
      end
      
      unless next_step_node do
        ExUnit.Assertions.flunk("Could not find call node for #{next_step}")
      end
      
      unless has_data_flow_edge(dfg, step_node.id, next_step_node.id) do
        ExUnit.Assertions.flunk("Expected data flow edge from #{step} to #{next_step}")
      end
    end
  end
  
  @doc """
  Validates captured variables in closures.
  """
  def validate_captured_variables(dfg, expected_captured, expected_not_captured \\ []) do
    captured = dfg.captured_variables || []
    
    for variable <- expected_captured do
      unless variable in captured do
        ExUnit.Assertions.flunk("Expected #{variable} to be captured")
      end
    end
    
    for variable <- expected_not_captured do
      if variable in captured do
        ExUnit.Assertions.flunk("Expected #{variable} to NOT be captured")
      end
    end
  end
  
  @doc """
  Validates variable mutations are correctly detected.
  """
  def validate_mutations(dfg, variable_name, expected_mutation_count) do
    mutations = dfg.mutations || []
    variable_mutations = Enum.filter(mutations, fn mutation ->
      Map.get(mutation, :variable) == variable_name ||
      String.contains?(to_string(mutation), variable_name)
    end)
    
    unless length(variable_mutations) == expected_mutation_count do
      ExUnit.Assertions.flunk(
        "Variable #{variable_name}: expected #{expected_mutation_count} mutations, got #{length(variable_mutations)}"
      )
    end
    
    variable_mutations
  end
  
  @doc """
  Validates dependency analysis results.
  """
  def validate_dependencies(dfg, target_variable, expected_dependencies) do
    # This would use DFGGenerator.get_dependencies/2 if available
    # For now, we'll implement a basic dependency check
    dependencies = get_variable_dependencies(dfg, target_variable)
    
    for expected_dep <- expected_dependencies do
      unless expected_dep in dependencies do
        ExUnit.Assertions.flunk(
          "Variable #{target_variable} should depend on #{expected_dep}, but dependency not found"
        )
      end
    end
    
    dependencies
  end
  
  @doc """
  Validates that circular dependencies are detected.
  """
  def assert_circular_dependency_detected(result) do
    case result do
      {:error, :circular_dependency} -> :ok
      {:error, reason} when is_atom(reason) ->
        if String.contains?(to_string(reason), "circular") do
          :ok
        else
          ExUnit.Assertions.flunk("Expected circular dependency error, got #{reason}")
        end
      {:ok, _} ->
        ExUnit.Assertions.flunk("Expected circular dependency to be detected")
      other ->
        ExUnit.Assertions.flunk("Unexpected result: #{inspect(other)}")
    end
  end
  
  # Private helper functions
  
  defp resolve_node_id(dfg, node_or_variable) do
    case node_or_variable do
      id when is_binary(id) ->
        # Check if it's already a node ID
        if Enum.any?(dfg.nodes, &(&1.id == id)) do
          id
        else
          # Try to find a node for this variable name
          node = Enum.find(dfg.nodes, fn node ->
            String.contains?(to_string(node.ast_snippet), node_or_variable) ||
            Map.get(node.metadata, :variable) == node_or_variable
          end)
          
          if node, do: node.id, else: node_or_variable
        end
        
      %{id: id} -> id
      _ -> to_string(node_or_variable)
    end
  end
  
  defp get_variable_dependencies(dfg, variable_name) do
    # Basic dependency analysis - find all variables that this variable depends on
    target_nodes = Enum.filter(dfg.nodes, fn node ->
      String.contains?(to_string(node.ast_snippet), variable_name) ||
      Map.get(node.metadata, :variable) == variable_name
    end)
    
    dependencies = 
      for target_node <- target_nodes,
          edge <- dfg.edges,
          edge.target == target_node.id,
          edge.type == :data_flow do
        
        source_node = Enum.find(dfg.nodes, &(&1.id == edge.source))
        if source_node do
          extract_variable_name_from_node(source_node)
        end
      end
    
    dependencies
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end
  
  defp extract_variable_name_from_node(node) do
    cond do
      Map.has_key?(node.metadata, :variable) ->
        node.metadata.variable
        
      is_binary(node.ast_snippet) ->
        # Try to extract variable name from AST snippet
        case Regex.run(~r/(\w+)\s*=/, node.ast_snippet) do
          [_, var_name] -> var_name
          _ -> nil
        end
        
      true -> nil
    end
  end
end 