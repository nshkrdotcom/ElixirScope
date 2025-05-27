defmodule CinemaDemo.Application do
  @moduledoc """
  Application module for CinemaDemo.
  
  Starts ElixirScope services for temporal debugging and Cinema Debugger functionality.
  """
  
  use Application
  
  def start(_type, _args) do
    children = [
      # Start ElixirScope TemporalStorage
      {ElixirScope.Capture.TemporalStorage, []},
      
      # Start ElixirScope TemporalBridge
      {ElixirScope.Capture.TemporalBridge, [name: :cinema_demo_bridge]},
      
      # Start our demo GenServer
      {CinemaDemo.TaskManager, []},
      
      # Start our demo worker
      {CinemaDemo.DataProcessor, []}
    ]
    
    opts = [strategy: :one_for_one, name: CinemaDemo.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Register the TemporalBridge for automatic event forwarding
        ElixirScope.Capture.TemporalBridge.register_as_handler(:cinema_demo_bridge)
        {:ok, pid}
      error ->
        error
    end
  end
end 