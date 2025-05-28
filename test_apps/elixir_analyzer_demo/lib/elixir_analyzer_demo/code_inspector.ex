defmodule ElixirAnalyzerDemo.CodeInspector do
  @moduledoc """
  Interactive code inspection and exploration for the Enhanced AST Repository demo.
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def inspect_module(module_name) do
    GenServer.call(__MODULE__, {:inspect_module, module_name})
  end
  
  def init(_opts) do
    {:ok, %{}}
  end
  
  def handle_call({:inspect_module, module_name}, _from, state) do
    result = %{
      module: module_name,
      inspection_time: DateTime.utc_now(),
      summary: "Module inspection completed"
    }
    {:reply, {:ok, result}, state}
  end
end 