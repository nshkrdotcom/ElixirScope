import Config

# Configuration for ElixirAnalyzerDemo
config :elixir_analyzer_demo,
  # Enhanced AST Repository configuration
  enhanced_repository: [
    memory_limit: 512 * 1024 * 1024,  # 512MB
    cache_enabled: true,
    monitoring_enabled: true,
    lazy_loading_enabled: true,
    cache_warming_enabled: true,
    cleanup_interval: 300_000,         # 5 minutes
    compression_interval: 600_000,     # 10 minutes
    memory_check_interval: 30_000      # 30 seconds
  ],
  
  # Phoenix configuration (disabled by default)
  phoenix_enabled: false,
  
  # Demo configuration
  demo_settings: [
    auto_load_sample_data: true,
    default_project_type: :medium,
    enable_performance_monitoring: true,
    enable_debug_interface: true
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs" 