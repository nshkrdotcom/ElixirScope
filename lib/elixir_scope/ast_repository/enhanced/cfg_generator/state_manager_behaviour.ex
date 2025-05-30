defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManagerBehaviour do
  @moduledoc """
  Behaviour for state management functions in the CFG generator.
  """

  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.State

  @doc """
  Initializes the initial state for CFG generation.
  """
  @callback initialize_state(function_ast :: term(), opts :: keyword()) :: State.t()

  @doc """
  Generates a unique node ID with optional state update.
  Returns either just the ID (when state is nil) or a tuple {id, new_state}.
  """
  @callback generate_node_id(prefix :: String.t(), state :: State.t() | nil) ::
    String.t() | {String.t(), State.t()}

  @doc """
  Generates a unique scope ID.
  """
  @callback generate_scope_id(prefix :: String.t(), state :: State.t()) :: String.t()
end
