defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.PathAnalyzer do
  @moduledoc """
  Handles path analysis for CFGGenerator.
  """

  alias ElixirScope.ASTRepository.Enhanced.{
    PathAnalysis,
    LoopAnalysis,
    BranchCoverage
  }

  def create_empty_path_analysis do
    %PathAnalysis{
      all_paths: [],
      critical_paths: [],
      unreachable_nodes: [],
      loop_analysis: %LoopAnalysis{loops: [], loop_nesting_depth: 0, infinite_loop_risk: :low, loop_complexity: 0},
      branch_coverage: %BranchCoverage{total_branches: 0, covered_branches: 0, uncovered_branches: [], coverage_percentage: 0.0, critical_uncovered: []},
      path_conditions: %{}
    }
  end

  def analyze_paths(nodes, edges, entry_nodes, exits, _opts) do
    # Generate all possible paths from entry to exit nodes
    all_paths = generate_all_paths(nodes, edges, entry_nodes, exits)

    # Identify critical paths (longest paths or paths with highest complexity)
    critical_paths = identify_critical_paths(all_paths, nodes)

    # Find unreachable nodes
    reachable_nodes = find_reachable_nodes(nodes, edges, entry_nodes)
    unreachable_nodes = Map.keys(nodes) -- reachable_nodes

    # Create loop analysis
    loop_analysis = analyze_loops(nodes, edges)

    # Create branch coverage analysis
    branch_coverage = analyze_branch_coverage(nodes, edges)

    # Generate path conditions
    path_conditions = generate_path_conditions(all_paths, nodes)

    %PathAnalysis{
      all_paths: all_paths,
      critical_paths: critical_paths,
      unreachable_nodes: unreachable_nodes,
      loop_analysis: loop_analysis,
      branch_coverage: branch_coverage,
      path_conditions: path_conditions
    }
  end

  defp generate_all_paths(_nodes, edges, entry_nodes, exits) do
    # Generate paths from each entry node to each exit node
    Enum.flat_map(entry_nodes, fn entry ->
      Enum.flat_map(exits, fn exit ->
        find_paths_between(entry, exit, edges, [])
      end)
    end)
    |> Enum.uniq()
    |> Enum.take(100)  # Limit to prevent explosion
  end

  defp find_paths_between(start, target, edges, visited) do
    if start == target do
      [[start]]
    else
      if start in visited or length(visited) > 20 do  # Add depth limit to prevent infinite loops
        []  # Avoid cycles and deep recursion
      else
        new_visited = [start | visited]

        # Find all edges from start
        outgoing_edges = Enum.filter(edges, fn edge -> edge.from_node_id == start end)

        # Limit the number of outgoing edges to prevent explosion
        limited_edges = Enum.take(outgoing_edges, 5)

        Enum.flat_map(limited_edges, fn edge ->
          sub_paths = find_paths_between(edge.to_node_id, target, edges, new_visited)
          Enum.map(sub_paths, fn path -> [start | path] end)
        end)
      end
    end
  end

  defp identify_critical_paths(all_paths, _nodes) do
    # Critical paths are the longest paths or paths through complex nodes
    all_paths
    |> Enum.sort_by(&length/1, :desc)
    |> Enum.take(3)  # Top 3 longest paths
  end

  defp find_reachable_nodes(_nodes, edges, entry_nodes) do
    # Use DFS to find all reachable nodes
    Enum.reduce(entry_nodes, MapSet.new(), fn entry, acc ->
      dfs_reachable(entry, edges, acc)
    end)
    |> MapSet.to_list()
  end

  defp dfs_reachable(node, edges, visited) do
    if MapSet.member?(visited, node) do
      visited
    else
      new_visited = MapSet.put(visited, node)

      # Find all nodes reachable from this node
      outgoing_edges = Enum.filter(edges, fn edge -> edge.from_node_id == node end)

      Enum.reduce(outgoing_edges, new_visited, fn edge, acc ->
        dfs_reachable(edge.to_node_id, edges, acc)
      end)
    end
  end

  defp analyze_loops(nodes, edges) do
    # Simple loop detection - look for back edges
    loops = detect_back_edges(edges)

    %LoopAnalysis{
      loops: loops,
      loop_nesting_depth: calculate_loop_nesting_depth(loops),
      infinite_loop_risk: assess_infinite_loop_risk(loops, nodes),
      loop_complexity: length(loops)
    }
  end

  defp detect_back_edges(edges) do
    # A back edge is an edge that points to a node that appears earlier in a DFS
    # For simplicity, detect cycles in the edge graph
    Enum.filter(edges, fn edge ->
      # Check if there's a path from to_node back to from_node
      has_cycle_through_edge?(edge, edges)
    end)
  end

  defp has_cycle_through_edge?(edge, edges) do
    # Simple cycle detection - check if we can get back to from_node from to_node
    # Use a limited search to prevent infinite loops
    paths = find_paths_between_limited(edge.to_node_id, edge.from_node_id, edges, [], 5)
    length(paths) > 0
  end

  # Limited path finding for cycle detection
  defp find_paths_between_limited(start, target, edges, visited, max_depth) do
    if max_depth <= 0 or start == target do
      if start == target, do: [[start]], else: []
    else
      if start in visited do
        []  # Avoid cycles
      else
        new_visited = [start | visited]

        # Find all edges from start (limit to 3 to prevent explosion)
        outgoing_edges = Enum.filter(edges, fn edge -> edge.from_node_id == start end)
        |> Enum.take(3)

        Enum.flat_map(outgoing_edges, fn edge ->
          sub_paths = find_paths_between_limited(edge.to_node_id, target, edges, new_visited, max_depth - 1)
          Enum.map(sub_paths, fn path -> [start | path] end)
        end)
      end
    end
  end

  defp calculate_loop_nesting_depth(loops) do
    # For simplicity, return the number of nested loops
    min(length(loops), 3)
  end

  defp assess_infinite_loop_risk(loops, _nodes) do
    case length(loops) do
      0 -> :low
      1 -> :medium
      _ -> :high
    end
  end

  defp analyze_branch_coverage(nodes, _edges) do
    # Count conditional nodes and their branches
    conditional_nodes = Map.values(nodes)
    |> Enum.filter(fn node ->
      node.type in [:conditional, :case, :cond_entry, :guard_check]
    end)

    total_branches = Enum.reduce(conditional_nodes, 0, fn node, acc ->
      case node.type do
        :conditional -> acc + 2  # if/else
        :case ->
          clause_count = Map.get(node.metadata, :clause_count, 2)
          acc + clause_count
        :cond_entry ->
          clause_count = Map.get(node.metadata, :clause_count, 2)
          acc + clause_count
        _ -> acc + 1
      end
    end)

    # For now, assume all branches are covered (would need more sophisticated analysis)
    covered_branches = total_branches

    %BranchCoverage{
      total_branches: total_branches,
      covered_branches: covered_branches,
      uncovered_branches: [],
      coverage_percentage: (if total_branches > 0, do: 100.0, else: 0.0),
      critical_uncovered: []
    }
  end

  defp generate_path_conditions(all_paths, nodes) do
    # Generate conditions for each path
    Enum.reduce(all_paths, %{}, fn path, acc ->
      path_id = "path_#{:erlang.phash2(path)}"
      conditions = extract_conditions_from_path(path, nodes)
      Map.put(acc, path_id, conditions)
    end)
  end

  defp extract_conditions_from_path(path, nodes) do
    # Extract conditions from conditional nodes in the path
    Enum.flat_map(path, fn node_id ->
      case Map.get(nodes, node_id) do
        %{type: :conditional, metadata: %{condition: condition}} ->
          [condition]
        %{type: :case, expression: condition} ->
          [condition]
        _ -> []
      end
    end)
  end
end 