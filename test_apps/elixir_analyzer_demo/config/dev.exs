import Config

# Development configuration
config :elixir_analyzer_demo,
  enhanced_repository: [
    memory_limit: 256 * 1024 * 1024,  # 256MB for development
    cache_enabled: true,
    monitoring_enabled: true,
    cleanup_interval: 60_000,         # 1 minute for faster demo
    compression_interval: 120_000,    # 2 minutes for faster demo
    memory_check_interval: 10_000     # 10 seconds for faster demo
  ],
  
  demo_settings: [
    auto_load_sample_data: true,
    default_project_type: :simple,   # Smaller dataset for development
    enable_performance_monitoring: true,
    enable_debug_interface: true
  ]

# Configure logger for development
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id] 