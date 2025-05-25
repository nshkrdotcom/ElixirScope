import Config

# Test configuration
config :elixir_scope,
  # Minimal logging in tests
  log_level: :warning,
  
  # Test-friendly AI configuration
  ai: [
    provider: :mock,                # Always use mock in tests
    planning: [
      default_strategy: :minimal,   # Minimal instrumentation in tests
      performance_target: 0.5,     # Accept higher overhead in tests
      sampling_rate: 1.0            # Full sampling for predictable tests
    ]
  ],

  # Smaller buffers for faster tests
  capture: [
    ring_buffer: [
      size: 65_536,                 # 64KB buffer for tests
      max_events: 1000
    ],
    processing: [
      batch_size: 10,               # Small batches for quick processing
      flush_interval: 1             # Immediate flushing in tests
    ]
  ],

  # Minimal storage for tests
  storage: [
    hot: [
      max_events: 10_000,           # 10K events max in tests
      max_age_seconds: 60,          # 1 minute max age
      prune_interval: 1000          # Prune every second
    ]
  ],

  # Test interface configuration
  interface: [
    iex_helpers: false,             # Disable IEx helpers in tests
    query_timeout: 1000             # Quick timeout for tests
  ]

# Exclude live API tests by default
# To run live tests: mix test --only live_api
# To include all tests: mix test --include live_api
ExUnit.configure(exclude: [:live_api]) 