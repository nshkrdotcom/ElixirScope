defmodule ElixirScope.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_scope,
      version: "0.0.1",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :dev,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      aliases: aliases(),

      # Test configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        test: :test,
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

  defp description() do
    "ElixirScope is a next-generation debugging and observability platform for Elixir applications, designed to provide an Execution Cinema experience through deep, compile-time AST instrumentation guided by AI-powered analysis."
  end

  defp package do
    [
      name: "elixir_scope",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/nshkrdotcom/ElixirScope"},
      maintainers: ["NSHkr"],
      files: ~w(lib mix.exs README.md LICENSE)
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

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "PUBLIC_DOCS.md"],
      before_closing_head_tag: &before_closing_head_tag/1,
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js"></script>
    <script>
      let initialized = false;

      window.addEventListener("exdoc:loaded", () => {
        if (!initialized) {
          mermaid.initialize({
            startOnLoad: false,
            theme: document.body.className.includes("dark") ? "dark" : "default"
          });
          initialized = true;
        }

        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
            graphEl.innerHTML = svg;
            bindFunctions?.(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp before_closing_head_tag(:epub), do: ""

  defp before_closing_body_tag(:html), do: ""

  defp before_closing_body_tag(:epub), do: ""

  defp aliases do
    [
      # Default test command excludes live API tests and shows full names
      test: ["test --trace --exclude live_api"],

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
        test: :test,
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
