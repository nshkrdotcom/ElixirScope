defmodule ElixirScope.ASTRepository.TestSupport.CFGValidationHelpers do
  @moduledoc """
  Helpers for deep CFG validation and path analysis.
  
  These helpers provide utilities for validating the semantic correctness
  of Control Flow Graphs, including path analysis, reachability validation,
  and structural verification.
  """
  
  alias ElixirScope.ASTRepository.Enhanced.{CFGGenerator, CFGData, CFGNode, CFGEdge}
  
  @doc """
  Asserts that two sets of paths are equivalent, ignoring order and minor variations.
  """
  def assert_paths_equivalent(expected_paths, actual_paths) do
    normalized_expected = normalize_paths(expected_paths)
    normalized_actual = normalize_paths(actual_paths)
    
    expected_set = MapSet.new(normalized_expected)
    actual_set = MapSet.new(normalized_actual)
    
    unless MapSet.equal?(expected_set, actual_set) do
      missing = MapSet.difference(expected_set, actual_set) |> MapSet.to_list()
      extra = MapSet.difference(actual_set, expected_set) |> MapSet.to_list()
      
      message = """
      Path sets are not equivalent:
      
      Expected paths: #{inspect(normalized_expected)}
      Actual paths:   #{inspect(normalized_actual)}
      
      Missing paths: #{inspect(missing)}
      Extra paths:   #{inspect(extra)}
      """
      
      ExUnit.Assertions.flunk(message)
    end
  end
  
  @doc """
  Finds all execution paths from entry to exit nodes in a CFG.
  """
  def find_all_execution_paths(cfg) do
    if cfg.exit_nodes && length(cfg.exit_nodes) > 0 do
      Enum.flat_map(cfg.exit_nodes, fn exit_node ->
        find_paths_between(cfg, cfg.entry_node, exit_node)
      end)
    else
      # If no exit nodes defined, find all possible paths from entry
      find_all_paths_from_entry(cfg)
    end
  end
  
  @doc """
  Validates that a path exists between two nodes.
  """
  def validate_path_reachability(cfg, from_node, to_node) do
    paths = find_paths_between(cfg, from_node, to_node)
    
    unless length(paths) > 0 do
      ExUnit.Assertions.flunk("No path found from #{from_node} to #{to_node}")
    end
    
    paths
  end
  
  @doc """
  Asserts that specific nodes are correctly identified as unreachable.
  """
  def assert_unreachable_code_detected(cfg, expected_unreachable_nodes) do
    # For now, we'll implement a basic unreachable detection
    # This should be enhanced when CFGGenerator.detect_unreachable_code/1 is implemented
    reachable_nodes = find_all_reachable_nodes(cfg)
    all_nodes = Map.keys(cfg.nodes)
    unreachable_nodes = all_nodes -- reachable_nodes
    
    for node <- expected_unreachable_nodes do
      unless node in unreachable_nodes do
        ExUnit.Assertions.flunk("Expected #{node} to be unreachable, but it is reachable")
      end
    end
    
    unreachable_nodes
  end
  
  @doc """
  Finds paths that lead to a specific outcome or contain a specific pattern.
  """
  def find_paths_with_outcome(paths, outcome_pattern) do
    Enum.filter(paths, fn path ->
      path_contains_pattern(path, outcome_pattern)
    end)
  end
  
  @doc """
  Finds a path that contains a specific sequence of patterns.
  """
  def find_path_with_pattern(paths, pattern_sequence) do
    Enum.find(paths, fn path ->
      contains_sequence(path, pattern_sequence)
    end)
  end
  
  @doc """
  Checks if a path contains a specific function call.
  """
  def path_contains_call(path, function_name) do
    Enum.any?(path, fn node_id ->
      String.contains?(to_string(node_id), function_name)
    end)
  end
  
  @doc """
  Finds nodes in a CFG by their type.
  """
  def find_nodes_by_type(cfg, node_type) do
    if cfg.nodes do
      cfg.nodes
      |> Map.values()
      |> Enum.filter(fn node ->
        Map.get(node, :type) == node_type ||
        Map.get(node, :node_type) == node_type
      end)
    else
      []
    end
  end
  
  @doc """
  Finds a path that leads to a specific outcome.
  """
  def find_path_to_outcome(cfg, outcome) do
    paths = find_all_execution_paths(cfg)
    
    Enum.find(paths, fn path ->
      path_leads_to_outcome(cfg, path, outcome)
    end)
  end
  
  @doc """
  Asserts that a path leads to a specific outcome.
  """
  def assert_path_leads_to_outcome(paths, outcome) do
    matching_path = Enum.find(paths, fn path ->
      path_contains_pattern(path, outcome)
    end)
    
    unless matching_path do
      ExUnit.Assertions.flunk("No path found leading to outcome: #{outcome}")
    end
    
    matching_path
  end
  
  @doc """
  Filters paths by their outcome.
  """
  def filter_paths_by_outcome(cfg, paths, outcome_pattern) do
    Enum.filter(paths, fn path ->
      path_contains_outcome_in_cfg(cfg, path, outcome_pattern)
    end)
  end
  
  @doc """
  Checks if a CFG node is in a specific branch of a conditional.
  """
  def cfg_node_in_branch(cfg, node_id, branch_type) do
    # This is a simplified implementation
    # In a real implementation, we'd trace back from the node to find the conditional
    node = cfg.nodes[node_id]
    
    case node do
      nil -> false
      %CFGNode{metadata: metadata} ->
        Map.get(metadata, :branch_type) == branch_type
      _ -> false
    end
  end
  
  @doc """
  Finds all nodes reachable from the entry node.
  """
  def find_all_reachable_nodes(cfg) do
    find_reachable_nodes_recursive(cfg, cfg.entry_node, MapSet.new())
    |> MapSet.to_list()
  end
  
  # Private helper functions
  
  defp normalize_paths(paths) do
    paths
    |> Enum.map(&normalize_path/1)
    |> Enum.sort()
  end
  
  defp normalize_path(path) do
    path
    |> Enum.map(&normalize_node_id/1)
    |> Enum.reject(&is_nil/1)
  end
  
  defp normalize_node_id(node_id) when is_binary(node_id) do
    # Remove UUIDs and timestamps to focus on semantic content
    node_id
    |> String.replace(~r/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/, "UUID")
    |> String.replace(~r/\d{13,}/, "TIMESTAMP")
  end
  
  defp normalize_node_id(node_id), do: to_string(node_id)
  
  defp find_paths_between(cfg, start_node, end_node) do
    find_paths_recursive(cfg, start_node, end_node, [], MapSet.new())
  end
  
  defp find_paths_recursive(cfg, current_node, target_node, current_path, visited) do
    if current_node == target_node do
      [current_path ++ [current_node]]
    else
      if MapSet.member?(visited, current_node) do
        # Avoid infinite loops
        []
      else
        new_visited = MapSet.put(visited, current_node)
        new_path = current_path ++ [current_node]
        
        outgoing_edges = get_outgoing_edges(cfg, current_node)
        
        Enum.flat_map(outgoing_edges, fn edge ->
          find_paths_recursive(cfg, edge.to_node_id, target_node, new_path, new_visited)
        end)
      end
    end
  end
  
  defp find_all_paths_from_entry(cfg) do
    # Find all leaf nodes (nodes with no outgoing edges)
    all_nodes = if cfg.nodes, do: Map.keys(cfg.nodes), else: []
    
    leaf_nodes = Enum.filter(all_nodes, fn node_id ->
      outgoing_edges = get_outgoing_edges(cfg, node_id)
      length(outgoing_edges) == 0
    end)
    
    # Find paths to all leaf nodes
    Enum.flat_map(leaf_nodes, fn leaf_node ->
      find_paths_between(cfg, cfg.entry_node, leaf_node)
    end)
  end
  
  defp get_outgoing_edges(cfg, node_id) do
    Enum.filter(cfg.edges, fn edge -> edge.from_node_id == node_id end)
  end
  
  defp find_reachable_nodes_recursive(cfg, current_node, visited) do
    if MapSet.member?(visited, current_node) do
      visited
    else
      new_visited = MapSet.put(visited, current_node)
      
      outgoing_edges = get_outgoing_edges(cfg, current_node)
      
      Enum.reduce(outgoing_edges, new_visited, fn edge, acc ->
        find_reachable_nodes_recursive(cfg, edge.to_node_id, acc)
      end)
    end
  end
  
  defp path_contains_pattern(path, pattern) do
    path_string = Enum.join(path, " -> ")
    String.contains?(path_string, to_string(pattern))
  end
  
  defp contains_sequence(path, pattern_sequence) do
    path_string = Enum.join(path, " -> ")
    sequence_string = Enum.join(pattern_sequence, " -> ")
    String.contains?(path_string, sequence_string)
  end
  
  defp path_leads_to_outcome(cfg, path, outcome) do
    # Check if the last few nodes in the path contain the outcome
    last_nodes = Enum.take(path, -3)
    
    Enum.any?(last_nodes, fn node_id ->
      case cfg.nodes[node_id] do
        %CFGNode{expression: expression} when not is_nil(expression) ->
          String.contains?(to_string(expression), to_string(outcome))
        %CFGNode{metadata: metadata} ->
          metadata
          |> Map.values()
          |> Enum.any?(fn value ->
            String.contains?(to_string(value), to_string(outcome))
          end)
        _ -> false
      end
    end)
  end
  
  defp path_contains_outcome_in_cfg(cfg, path, outcome_pattern) do
    Enum.any?(path, fn node_id ->
      case cfg.nodes[node_id] do
        %CFGNode{expression: expression} when not is_nil(expression) ->
          expression_string = inspect(expression)
          String.contains?(expression_string, to_string(outcome_pattern))
        %CFGNode{metadata: metadata} ->
          metadata
          |> Map.values()
          |> Enum.any?(fn value ->
            value_string = if is_binary(value), do: value, else: inspect(value)
            String.contains?(value_string, to_string(outcome_pattern))
          end)
        _ -> 
          # Fallback to checking node ID
          String.contains?(to_string(node_id), to_string(outcome_pattern))
      end
    end)
  end
  
  defp path_contains_outcome(path, outcome_pattern) do
    Enum.any?(path, fn node_id ->
      String.contains?(to_string(node_id), to_string(outcome_pattern)) ||
      node_contains_pattern(node_id, outcome_pattern)
    end)
  end
  
  defp node_contains_pattern(node_id, pattern) do
    # This is a simplified pattern matching
    # In a real implementation, you might want to look up the actual node
    # and check its content, AST snippet, etc.
    String.contains?(to_string(node_id), to_string(pattern))
  end
end 