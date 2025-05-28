defmodule ElixirAnalyzerDemo.Telemetry do
  @moduledoc """
  Telemetry and metrics collection for the Enhanced AST Repository demo.
  """
  
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    children = [
      # Add telemetry handlers here if needed
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end 