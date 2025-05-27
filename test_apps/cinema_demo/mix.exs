defmodule CinemaDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :cinema_demo,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:elixir_scope] ++ Mix.compilers(),
      elixir_scope: [
        enabled: true,
        instrumentation: [
          functions: true,
          variables: true,
          expressions: true,
          temporal_correlation: true
        ],
        cinema_debugger: [
          enabled: true,
          buffer_size: 10_000
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {CinemaDemo.Application, []}
    ]
  end

  # Run "mix help deps.get" to learn about dependencies.
  defp deps do
    [
      {:elixir_scope, path: "../.."},
      {:jason, "~> 1.4"}
    ]
  end
end
