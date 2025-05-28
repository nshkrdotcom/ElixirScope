defmodule ElixirAnalyzerDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_analyzer_demo,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :observer, :wx, :runtime_tools],
      mod: {ElixirAnalyzerDemo.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Enhanced AST Repository (local dependency)
      {:elixir_scope, path: "../.."},
      
      # Phoenix for web interface
      {:phoenix, "~> 1.7.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      
      # Telemetry for metrics
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      
      # JSON handling
      {:jason, "~> 1.2"},
      
      # HTTP client for external integrations
      {:finch, "~> 0.13"},
      
      # Plotting and visualization
      {:vega_lite, "~> 0.1.6"},
      {:kino_vega_lite, "~> 0.1.7"},
      
      # Development and testing
      {:floki, ">= 0.30.0", only: :test},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      test: ["test"],
      "test.performance": ["test --only performance"],
      "test.memory": ["test --only memory"],
      "test.integration": ["test --only integration"]
    ]
  end
end
