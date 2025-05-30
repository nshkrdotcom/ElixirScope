defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessorBehaviour do
  @moduledoc """
  Behaviour for main AST processing functions for the CFG generator.
  """

  alias ElixirScope.ASTRepository.Enhanced.{CFGNode, CFGEdge, ScopeInfo}
  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.State

  @type nodes_map :: %{String.t() => CFGNode.t()}
  @type edges_list :: [CFGEdge.t()]
  @type exits_list :: [String.t()]
  @type scopes_map :: %{String.t() => ScopeInfo.t()}
  @type process_result :: {nodes_map(), edges_list(), exits_list(), scopes_map(), State.t()} | {:error, any()}

  @doc """
  Processes a function body AST and returns CFG components.
  """
  @callback process_function_body(function_ast :: term(), state :: State.t()) :: process_result()

  @doc """
  Main AST node processing dispatcher.
  """
  @callback process_ast_node(ast :: term(), state :: State.t()) :: process_result()
end
