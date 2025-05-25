defmodule ElixirScope.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_scope,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      
      # Test configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "test.trace": :test,
        "test.live": :test,
        "test.all": :test,
        "test.fast": :test
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
      # Core Dependencies
      {:telemetry, "~> 1.0"},
      {:plug, "~> 1.14", optional: true},
      {:phoenix, "~> 1.7", optional: true},
      {:phoenix_live_view, "~> 0.18", optional: true},
      
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
      {:jason, "~> 1.4"},
      
      # HTTP client for LLM providers
      {:httpoison, "~> 2.0"},
      
      # JSON Web Token library
      {:joken, "~> 2.6"}
    ]
  end

  defp aliases do
    [
      # Custom test aliases for better output
      "test.trace": ["test --trace --exclude live_api"],
      "test.live": ["test --only live_api"],
      "test.all": ["test --include live_api"],
      "test.fast": ["test --exclude live_api --max-cases 48"],
      
      # Provider-specific test aliases
      "test.gemini": ["test --trace test/elixir_scope/ai/llm/providers/gemini_live_test.exs"],
      "test.vertex": ["test --trace test/elixir_scope/ai/llm/providers/vertex_live_test.exs"],
      "test.mock": ["test --trace test/elixir_scope/ai/llm/providers/mock_test.exs"],
      
      # LLM-focused test aliases
      "test.llm": ["test --trace --exclude live_api test/elixir_scope/ai/llm/"],
      "test.llm.live": ["test --trace --only live_api test/elixir_scope/ai/llm/"]
    ]
  end
  
  def cli do
    [
      preferred_envs: [
        "test.trace": :test,
        "test.live": :test,
        "test.all": :test,
        "test.fast": :test,
        "test.gemini": :test,
        "test.vertex": :test,
        "test.mock": :test,
        "test.llm": :test,
        "test.llm.live": :test
      ]
    ]
  end
end 