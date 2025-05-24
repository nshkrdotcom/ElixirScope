import Config

# ElixirScope Configuration
config :elixir_scope,
  # AI Configuration
  ai: [
    # AI provider configuration (future LLM integration)
    provider: :mock,
    api_key: nil,
    model: "gpt-4",
    
    # Code analysis settings
    analysis: [
      max_file_size: 1_000_000,  # 1MB max file size for analysis
      timeout: 30_000,           # 30 second timeout for analysis
      cache_ttl: 3600           # 1 hour cache TTL for analysis results
    ],
    
    # Instrumentation planning
    planning: [
      default_strategy: :balanced,  # :minimal, :balanced, :full_trace
      performance_target: 0.01,     # 1% max overhead target
      sampling_rate: 1.0            # 100% sampling by default (total recall)
    ]
  ],

  # Event Capture Configuration
  capture: [
    # Ring buffer settings
    ring_buffer: [
      size: 1_048_576,           # 1MB buffer size
      max_events: 100_000,       # Max events before overflow
      overflow_strategy: :drop_oldest,
      num_buffers: :schedulers   # One buffer per scheduler by default
    ],
    
    # Event processing
    processing: [
      batch_size: 1000,          # Events per batch
      flush_interval: 100,       # Flush every 100ms
      max_queue_size: 10_000     # Max queued events before backpressure
    ],
    
    # VM tracing configuration
    vm_tracing: [
      enable_spawn_trace: true,
      enable_exit_trace: true,
      enable_message_trace: false,  # Can be very noisy
      trace_children: true
    ]
  ],

  # Storage Configuration
  storage: [
    # Hot storage (ETS) - recent events
    hot: [
      max_events: 1_000_000,     # 1M events in hot storage
      max_age_seconds: 3600,     # 1 hour max age
      prune_interval: 60_000     # Prune every minute
    ],
    
    # Warm storage (disk) - archived events
    warm: [
      enable: false,             # Disable warm storage initially
      path: "./elixir_scope_data",
      max_size_mb: 1000,         # 1GB max warm storage
      compression: :zstd
    ],
    
    # Cold storage (future) - long-term archival
    cold: [
      enable: false
    ]
  ],

  # Developer Interface
  interface: [
    # IEx helpers
    iex_helpers: true,
    
    # Query timeouts
    query_timeout: 5000,         # 5 second default query timeout
    
    # Web interface (future)
    web: [
      enable: false,
      port: 4000
    ]
  ],

  # Instrumentation Configuration
  instrumentation: [
    # Default instrumentation levels
    default_level: :function_boundaries,  # :none, :function_boundaries, :full_trace
    
    # Module-specific overrides
    module_overrides: %{
      # Example: MyApp.ImportantModule => :full_trace
    },
    
    # Function-specific overrides  
    function_overrides: %{
      # Example: {MyApp.FastModule, :critical_function, 2} => :minimal
    },
    
    # Automatic exclusions
    exclude_modules: [
      ElixirScope,               # Don't instrument ourselves
      :logger,
      :gen_server,
      :supervisor
    ]
  ]

# Environment-specific configuration
import_config "#{config_env()}.exs" 