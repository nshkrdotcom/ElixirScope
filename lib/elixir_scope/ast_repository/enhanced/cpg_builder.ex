defmodule ElixirScope.ASTRepository.Enhanced.CPGBuilder do
  @moduledoc """
  Code Property Graph builder for comprehensive AST analysis.

  Combines Control Flow Graphs (CFG) and Data Flow Graphs (DFG) into a unified
  representation that enables advanced analysis including:
  - Security vulnerability detection
  - Code quality analysis and metrics
  - Performance bottleneck identification
  - Pattern matching for code analysis
  - Cross-function dependency analysis

  Performance targets:
  - CPG building: <500ms for modules with <50 functions
  - Memory efficient: <5MB per module CPG

  This module serves as the main interface and delegates to specialized
  sub-modules for different aspects of CPG building and analysis.
  """

  alias ElixirScope.ASTRepository.Enhanced.CPGBuilder.{
    Core, QueryProcessor, PatternDetector
  }

  @doc """
  Builds a unified Code Property Graph from AST.

  Returns {:ok, cpg} or {:error, reason}
  """
  defdelegate build_cpg(ast, opts \\ []), to: Core

  @doc """
  Performs complex queries across all graph dimensions.
  """
  defdelegate query_cpg(cpg, query), to: QueryProcessor

  @doc """
  Finds code patterns for analysis.
  """
  defdelegate find_pattern(cpg, pattern), to: PatternDetector

  @doc """
  Updates CPG with modified AST (incremental analysis).
  """
  defdelegate update_cpg(original_cpg, modified_ast, opts \\ []), to: Core
end
