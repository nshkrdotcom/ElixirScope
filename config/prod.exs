import Config

# Production configuration
config :elixir_scope,
  # Minimal logging in production
  log_level: :info,
  
  # Production AI configuration
  ai: [
    planning: [
      default_strategy: :balanced,  # Balanced approach in production
      performance_target: 0.005,   # 0.5% max overhead in production
      sampling_rate: 0.1            # 10% sampling to reduce overhead
    ]
  ],

  # Conservative capture settings for production
  capture: [
    ring_buffer: [
      size: 1_048_576,              # 1MB buffer in production
      max_events: 50_000            # Smaller event limit
    ],
    processing: [
      batch_size: 2000,             # Larger batches for efficiency
      flush_interval: 500           # Less frequent flushing
    ]
  ],

  # Conservative storage for production
  storage: [
    hot: [
      max_events: 500_000,          # 500K events in production
      max_age_seconds: 1800,        # 30 minutes in production
      prune_interval: 300_000       # Prune every 5 minutes
    ]
  ],

  # Production interface configuration
  interface: [
    iex_helpers: false,             # Disable IEx helpers in production
    query_timeout: 3000             # Shorter timeout for production
  ] 