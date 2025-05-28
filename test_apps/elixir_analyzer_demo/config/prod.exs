import Config

# Production configuration
config :elixir_analyzer_demo,
  enhanced_repository: [
    memory_limit: 1024 * 1024 * 1024, # 1GB for production
    cache_enabled: true,
    monitoring_enabled: true,
    lazy_loading_enabled: true,
    cache_warming_enabled: true,
    cleanup_interval: 600_000,        # 10 minutes
    compression_interval: 1_800_000,  # 30 minutes
    memory_check_interval: 60_000     # 1 minute
  ],
  
  demo_settings: [
    auto_load_sample_data: false,     # Don't auto-load in production
    default_project_type: :complex,
    enable_performance_monitoring: true,
    enable_debug_interface: false    # Disable debug interface in production
  ]

# Configure logger for production
config :logger, level: :info 