defmodule ElixirScope.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_scope,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ElixirScope.Application, []}
    ]
  end

  defp deps do
    [
      # Testing & Quality
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      
      # Property-based testing for concurrency testing
      {:stream_data, "~> 0.5", only: :test},
      
      # Benchmarking for performance testing
      {:benchee, "~> 1.1", only: :test},
      
      # JSON for configuration and serialization
      {:jason, "~> 1.4"}
    ]
  end
end 