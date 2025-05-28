defmodule ElixirAnalyzerDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Enhanced AST Repository Core Components
      {ElixirScope.ASTRepository.EnhancedRepository, [
        memory_limit: get_config(:memory_limit, 512 * 1024 * 1024),  # 512MB default
        cache_enabled: get_config(:cache_enabled, true),
        monitoring_enabled: get_config(:monitoring_enabled, true)
      ]},
      
      # Memory Manager with demo-friendly settings
      {ElixirScope.ASTRepository.MemoryManager, [
        monitoring_enabled: get_config(:monitoring_enabled, true),
        cleanup_interval: get_config(:cleanup_interval, 300_000),      # 5 minutes
        compression_interval: get_config(:compression_interval, 600_000), # 10 minutes
        memory_check_interval: get_config(:memory_check_interval, 30_000)  # 30 seconds
      ]},
      
      # Performance Optimizer
      {ElixirScope.ASTRepository.PerformanceOptimizer, [
        lazy_loading_enabled: get_config(:lazy_loading_enabled, true),
        cache_warming_enabled: get_config(:cache_warming_enabled, true)
      ]},
      
      # Demo Application Components
      ElixirAnalyzerDemo.AnalysisEngine,
      ElixirAnalyzerDemo.CodeInspector,
      ElixirAnalyzerDemo.RuntimeCorrelation,
      ElixirAnalyzerDemo.DebugInterface,
      ElixirAnalyzerDemo.PerformanceMonitor,
      ElixirAnalyzerDemo.QualityAnalyzer,
      
      # Sample Data Manager
      ElixirAnalyzerDemo.SampleDataManager,
      
      # Telemetry supervisor for metrics
      ElixirAnalyzerDemo.Telemetry,
      
      # Phoenix Endpoint (if web interface is enabled)
      maybe_phoenix_endpoint()
    ]
    |> Enum.filter(& &1)  # Remove nil entries

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirAnalyzerDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    if phoenix_enabled?() do
      ElixirAnalyzerDemo.Endpoint.config_change(changed, removed)
    end
    :ok
  end

  defp get_config(key, default) do
    Application.get_env(:elixir_analyzer_demo, :enhanced_repository, [])
    |> Keyword.get(key, default)
  end

  defp maybe_phoenix_endpoint do
    if phoenix_enabled?() do
      ElixirAnalyzerDemo.Endpoint
    else
      nil
    end
  end

  defp phoenix_enabled? do
    Application.get_env(:elixir_analyzer_demo, :phoenix_enabled, false)
  end
end
