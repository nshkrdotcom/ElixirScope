defmodule MyApp.UserServer do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_cast({:set, key, value}, state) do
    new_state = Map.put(state, key, value)
    {:noreply, new_state}
  end
end 