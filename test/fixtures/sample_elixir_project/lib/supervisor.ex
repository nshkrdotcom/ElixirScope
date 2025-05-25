defmodule MyApp.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [
      MyApp.UserServer,
      {MyApp.WorkerPool, pool_size: 5},
      {Phoenix.PubSub, name: MyApp.PubSub}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end 