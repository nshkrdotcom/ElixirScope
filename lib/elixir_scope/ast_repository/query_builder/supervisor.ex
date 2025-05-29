defmodule ElixirScope.ASTRepository.QueryBuilder.Supervisor do
  @moduledoc """
  Supervisor for the QueryBuilder system components.
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [
      # Start the cache first since QueryBuilder depends on it
      {ElixirScope.ASTRepository.QueryBuilder.Cache, []},
      # Then start the main QueryBuilder
      {ElixirScope.ASTRepository.QueryBuilder, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
