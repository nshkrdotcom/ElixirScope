import Config

# Test configuration
config :elixir_analyzer_demo,
  enhanced_repository: [
    memory_limit: 64 * 1024 * 1024,   # 64MB for testing
    cache_enabled: false,             # Disable cache for consistent tests
    monitoring_enabled: false,        # Disable monitoring for tests
    cleanup_interval: 5_000,          # 5 seconds for fast tests
    compression_interval: 10_000,     # 10 seconds for fast tests
    memory_check_interval: 1_000      # 1 second for fast tests
  ],
  
  demo_settings: [
    auto_load_sample_data: false,     # Don't auto-load in tests
    default_project_type: :simple,
    enable_performance_monitoring: false,
    enable_debug_interface: false
  ]

# Configure logger for testing
config :logger, level: :warning 