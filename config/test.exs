import Config

# Configure Logger to only show errors during tests (reduce noise)
config :logger, level: :error

# Test configuration
config :elixir_scope,
  # Minimal logging in tests
  log_level: :error,
  
  # Test-friendly AI configuration
  ai: [
    provider: :mock,                # Always use mock in tests
    planning: [
      default_strategy: :minimal,   # Minimal instrumentation in tests
      performance_target: 0.5,     # Accept higher overhead in tests
      sampling_rate: 1.0            # Full sampling for predictable tests
    ]
  ],
  
  # Force mock provider in tests (overrides auto-detection)
  llm_provider: "mock",

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
  ],

  state_manager: ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager,
  ast_utilities: ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities,  
  ast_processor: ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessor









config :elixir_scope, :pattern_matcher,
  # Faster execution for tests
  pattern_match_timeout: 100,
  function_analysis_timeout: 5,
  
  # Disable caching for predictable tests
  enable_pattern_cache: false,
  
  # Test-specific settings
  log_level: :warning

# Exclude live API tests by default
# To run live tests: mix test --only live_api
# To include all tests: mix test --include live_api
ExUnit.configure(
  exclude: [:live_api],
  formatters: [ExUnit.CLIFormatter],
  colors: [
    enabled: true,
    success: :green,
    invalid: :yellow,
    failure: :red,
    error: :red,
    extra_info: :cyan,
    diff_delete: :red,
    diff_insert: :green
  ],
  trace: true,  # Show each test as it runs
  max_cases: 1, # Force trace mode (shows individual tests)
  timeout: 60_000,
  max_failures: :infinity
) 
