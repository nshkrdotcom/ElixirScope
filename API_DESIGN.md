# ElixirScope Unified API Design

## 🎯 **Overview**

This document defines the exact API contracts for ElixirScope's unified tracing system that seamlessly integrates runtime and compile-time AST instrumentation. These contracts serve as the implementation blueprint for the unified system.

---

## 📋 **Table of Contents**

1. [Unified Interface API](#1-unified-interface-api)
2. [Event Correlation Mechanisms](#2-event-correlation-mechanisms)
3. [Configuration System Integration](#3-configuration-system-integration)
4. [Mode Selection Logic](#4-mode-selection-logic)
5. [Data Types & Structures](#5-data-types--structures)
6. [Error Handling](#6-error-handling)
7. [Implementation Contracts](#7-implementation-contracts)

---

## 1. **Unified Interface API**

### **1.1 Core Module: `ElixirScope.Unified`**

```elixir
defmodule ElixirScope.Unified do
  @moduledoc """
  Unified interface for ElixirScope tracing that automatically selects
  the optimal tracing mode (runtime, compile-time, or hybrid) based on
  the target, environment, and user requirements.
  """

  @type trace_target :: 
    module() | 
    {module(), atom()} | 
    {module(), atom(), arity()} | 
    pid() | 
    [trace_target()]

  @type trace_mode :: :runtime | :compile_time | :hybrid | :auto

  @type trace_options :: [
    # Mode control
    mode: trace_mode(),
    force_runtime: boolean(),
    force_compile_time: boolean(),
    
    # Granularity control
    granularity: :function | :expression | :line | :variable,
    capture_locals: [atom()],
    trace_lines: [pos_integer()],
    
    # Runtime-specific options
    include: [:calls | :returns | :messages | :state_changes],
    sampling_rate: float(),
    
    # Compile-time specific options
    custom_injections: [{pos_integer(), :before | :after, Macro.t()}],
    conditional_compilation: keyword(),
    
    # Hybrid options
    correlation_window: pos_integer(),
    auto_escalate: boolean(),
    
    # General options
    timeout: pos_integer(),
    metadata: map()
  ]

  @type trace_session :: %{
    session_id: reference(),
    mode: trace_mode(),
    targets: [trace_target()],
    options: trace_options(),
    started_at: DateTime.t(),
    runtime_refs: [reference()],
    compile_time_refs: [reference()],
    status: :active | :paused | :stopped | :error
  }

  @type trace_result :: 
    {:ok, trace_session()} | 
    {:error, :mode_unavailable | :target_invalid | :compilation_required | atom()}

  # ============================================================================
  # PRIMARY API FUNCTIONS
  # ============================================================================

  @doc """
  Start tracing with automatic mode selection.
  
  ## Examples
  
      # Simple function tracing (auto-selects runtime mode)
      {:ok, session} = ElixirScope.Unified.trace(MyModule.my_function/2)
      
      # Deep debugging (likely selects compile-time or hybrid)
      {:ok, session} = ElixirScope.Unified.trace(
        MyModule.complex_algorithm/1,
        granularity: :variable,
        capture_locals: [:temp_result, :iteration_count]
      )
      
      # Process monitoring (runtime mode)
      {:ok, session} = ElixirScope.Unified.trace(
        some_pid,
        include: [:messages, :state_changes]
      )
      
      # Hybrid tracing for comprehensive analysis
      {:ok, session} = ElixirScope.Unified.trace(
        [MyModule.entry_point/1, MyModule.helper/2],
        mode: :hybrid,
        correlation_window: 100
      )
  """
  @spec trace(trace_target(), trace_options()) :: trace_result()
  def trace(target, opts \\ [])

  @doc """
  Stop an active trace session.
  """
  @spec stop_trace(reference() | trace_session()) :: :ok | {:error, :not_found}
  def stop_trace(session_or_ref)

  @doc """
  Pause an active trace session (if supported by the mode).
  """
  @spec pause_trace(reference()) :: :ok | {:error, :not_supported | :not_found}
  def pause_trace(session_ref)

  @doc """
  Resume a paused trace session.
  """
  @spec resume_trace(reference()) :: :ok | {:error, :not_paused | :not_found}
  def resume_trace(session_ref)

  @doc """
  List all active trace sessions.
  """
  @spec list_traces() :: [trace_session()]
  def list_traces()

  @doc """
  Get detailed information about a trace session.
  """
  @spec get_trace_info(reference()) :: {:ok, trace_session()} | {:error, :not_found}
  def get_trace_info(session_ref)

  @doc """
  Switch the mode of an active trace session (if possible).
  """
  @spec switch_mode(reference(), trace_mode(), trace_options()) :: 
    :ok | {:error, :mode_unavailable | :compilation_required | atom()}
  def switch_mode(session_ref, new_mode, opts \\ [])

  # ============================================================================
  # MODE SELECTION API
  # ============================================================================

  @doc """
  Determine the optimal tracing mode for given targets and options.
  Does not start tracing, just returns the recommended mode and reasoning.
  """
  @spec determine_mode(trace_target(), trace_options()) :: 
    {:ok, trace_mode(), reason :: String.t()} | 
    {:error, :target_invalid | atom()}
  def determine_mode(target, opts \\ [])

  @doc """
  Check if a specific mode is available for the given targets.
  """
  @spec mode_available?(trace_target(), trace_mode()) :: boolean()
  def mode_available?(target, mode)

  @doc """
  Get capabilities for each available mode for the given targets.
  """
  @spec get_mode_capabilities(trace_target()) :: %{
    runtime: [atom()],
    compile_time: [atom()],
    hybrid: [atom()]
  }
  def get_mode_capabilities(target)
end
```

### **1.2 Mode-Specific Delegation APIs**

```elixir
defmodule ElixirScope.Unified.Runtime do
  @moduledoc """
  Runtime-specific tracing operations delegated from the unified interface.
  """

  @spec start_runtime_trace(ElixirScope.Unified.trace_target(), keyword()) :: 
    {:ok, reference()} | {:error, atom()}
  def start_runtime_trace(target, opts)

  @spec stop_runtime_trace(reference()) :: :ok | {:error, atom()}
  def stop_runtime_trace(ref)
end

defmodule ElixirScope.Unified.CompileTime do
  @moduledoc """
  Compile-time specific tracing operations delegated from the unified interface.
  """

  @spec start_compile_time_trace(ElixirScope.Unified.trace_target(), keyword()) :: 
    {:ok, reference()} | {:error, atom()}
  def start_compile_time_trace(target, opts)

  @spec trigger_recompilation([module()], keyword()) :: 
    :ok | {:error, :compilation_failed | atom()}
  def trigger_recompilation(modules, instrumentation_plan)
end

defmodule ElixirScope.Unified.Hybrid do
  @moduledoc """
  Hybrid tracing coordination between runtime and compile-time systems.
  """

  @spec start_hybrid_session(ElixirScope.Unified.trace_target(), keyword()) :: 
    {:ok, reference()} | {:error, atom()}
  def start_hybrid_session(target, opts)

  @spec correlate_session_events(reference()) :: :ok
  def correlate_session_events(session_ref)
end
```

---

## 2. **Event Correlation Mechanisms**

### **2.1 Core Correlation Module**

```elixir
defmodule ElixirScope.Events.Correlator do
  @moduledoc """
  Handles correlation of events from different tracing sources (runtime vs AST)
  to provide a unified view of execution flow.
  """

  @type correlation_id :: String.t()
  @type event_source :: :runtime | :ast | :hybrid
  @type correlation_strategy :: 
    :timestamp_window | 
    :call_stack_matching | 
    :process_correlation | 
    :message_sequence

  @type correlation_config :: %{
    strategy: correlation_strategy(),
    window_ms: pos_integer(),
    max_events_per_correlation: pos_integer(),
    timeout_ms: pos_integer()
  }

  @type correlated_event :: %{
    correlation_id: correlation_id(),
    primary_event: ElixirScope.Events.Event.t(),
    related_events: [ElixirScope.Events.Event.t()],
    correlation_confidence: float(),
    correlation_metadata: map()
  }

  # ============================================================================
  # CORRELATION API
  # ============================================================================

  @doc """
  Start a correlation session for a trace session.
  """
  @spec start_correlation_session(reference(), correlation_config()) :: 
    {:ok, reference()} | {:error, atom()}
  def start_correlation_session(trace_session_ref, config \\ default_config())

  @doc """
  Correlate a new event with existing events in the session.
  """
  @spec correlate_event(reference(), ElixirScope.Events.Event.t()) :: 
    {:ok, correlated_event()} | 
    {:pending, correlation_id()} | 
    {:error, atom()}
  def correlate_event(correlation_session_ref, event)

  @doc """
  Get all correlated events for a specific correlation ID.
  """
  @spec get_correlated_events(correlation_id()) :: [correlated_event()]
  def get_correlated_events(correlation_id)

  @doc """
  Force correlation of pending events (useful at session end).
  """
  @spec flush_pending_correlations(reference()) :: [correlated_event()]
  def flush_pending_correlations(correlation_session_ref)

  # ============================================================================
  # CORRELATION STRATEGIES
  # ============================================================================

  @doc """
  Correlate events based on timestamp proximity.
  """
  @spec correlate_by_timestamp(ElixirScope.Events.Event.t(), [ElixirScope.Events.Event.t()], pos_integer()) :: 
    [correlated_event()]
  def correlate_by_timestamp(target_event, candidate_events, window_ms)

  @doc """
  Correlate events based on call stack matching.
  """
  @spec correlate_by_call_stack(ElixirScope.Events.Event.t(), [ElixirScope.Events.Event.t()]) :: 
    [correlated_event()]
  def correlate_by_call_stack(target_event, candidate_events)

  @doc """
  Correlate events based on process/PID relationships.
  """
  @spec correlate_by_process(ElixirScope.Events.Event.t(), [ElixirScope.Events.Event.t()]) :: 
    [correlated_event()]
  def correlate_by_process(target_event, candidate_events)

  @doc """
  Generate a correlation ID that links related events.
  """
  @spec generate_correlation_id(ElixirScope.Events.Event.t()) :: correlation_id()
  def generate_correlation_id(event)

  @doc """
  Calculate correlation confidence between two events.
  """
  @spec calculate_confidence(ElixirScope.Events.Event.t(), ElixirScope.Events.Event.t()) :: float()
  def calculate_confidence(event1, event2)
end
```

### **2.2 Enhanced Event Structure for Correlation**

```elixir
defmodule ElixirScope.Events.Event do
  @moduledoc """
  Enhanced event structure that supports correlation across tracing modes.
  """

  @type t :: %__MODULE__{
    # Core event identification
    event_id: String.t(),
    correlation_id: String.t() | nil,
    session_id: reference(),
    
    # Source and timing
    source: :runtime | :ast,
    timestamp: integer(),
    monotonic_time: integer(),
    
    # Event classification
    type: atom(),
    category: :function_call | :variable_change | :message | :state_change | :custom,
    
    # Context information
    process_id: pid(),
    module: module(),
    function: atom(),
    arity: non_neg_integer(),
    line: pos_integer() | nil,
    
    # Event-specific data
    data: map(),
    metadata: map(),
    
    # Correlation helpers
    call_stack: [String.t()],
    sequence_number: pos_integer(),
    parent_event_id: String.t() | nil,
    
    # Performance data
    duration_ns: pos_integer() | nil,
    memory_delta: integer() | nil
  }

  defstruct [
    :event_id, :correlation_id, :session_id,
    :source, :timestamp, :monotonic_time,
    :type, :category,
    :process_id, :module, :function, :arity, :line,
    :data, :metadata,
    :call_stack, :sequence_number, :parent_event_id,
    :duration_ns, :memory_delta
  ]

  @doc """
  Create a new event with automatic ID generation and correlation setup.
  """
  @spec new(atom(), map(), keyword()) :: t()
  def new(type, data, opts \\ [])

  @doc """
  Add correlation metadata to an event.
  """
  @spec add_correlation_metadata(t(), map()) :: t()
  def add_correlation_metadata(event, metadata)

  @doc """
  Check if two events can be correlated based on their properties.
  """
  @spec correlatable?(t(), t()) :: boolean()
  def correlatable?(event1, event2)
end
```

---

## 3. **Configuration System Integration**

### **3.1 Unified Configuration Structure**

```elixir
defmodule ElixirScope.Config.Unified do
  @moduledoc """
  Unified configuration system that manages settings for all tracing modes
  and provides intelligent defaults based on environment and usage patterns.
  """

  @type unified_config :: %{
    # Global unified settings
    unified: %{
      default_mode: :auto | :runtime | :compile_time | :hybrid,
      environment_overrides: %{
        dev: keyword(),
        test: keyword(),
        prod: keyword()
      },
      auto_mode_thresholds: %{
        complexity_for_ast: pos_integer(),
        detail_level_for_hybrid: pos_integer(),
        performance_threshold_for_runtime: float()
      },
      feature_flags: %{
        enable_ast_local_variables: boolean(),
        enable_expression_tracing: boolean(),
        enable_on_demand_compilation: boolean(),
        enable_ai_mode_selection: boolean()
      }
    },
    
    # Runtime-specific configuration
    runtime: %{
      safety_limits: %{
        max_traced_processes: pos_integer(),
        max_events_per_second: pos_integer(),
        memory_limit_mb: pos_integer(),
        cpu_threshold_percent: pos_integer()
      },
      tracing: %{
        default_flags: [atom()],
        sampling_rate: float(),
        buffer_size: pos_integer(),
        flush_interval_ms: pos_integer()
      },
      coordination: %{
        coordinate_with_ast: boolean(),
        shared_session_management: boolean(),
        event_correlation_enabled: boolean()
      }
    },
    
    # Compile-time/AST configuration
    compile_time: %{
      instrumentation: %{
        default_level: :function | :expression | :line | :variable,
        environments: [atom()],
        custom_transformations: [module()],
        optimization_level: :none | :basic | :aggressive
      },
      compilation: %{
        plan_storage_path: String.t(),
        plan_cache_ttl_seconds: pos_integer(),
        enable_targeted_recompilation: boolean(),
        recompile_timeout_ms: pos_integer(),
        parallel_compilation: boolean()
      },
      runtime_integration: %{
        register_with_runtime: boolean(),
        shared_correlation_ids: boolean(),
        runtime_control_enabled: boolean()
      }
    },
    
    # Hybrid mode configuration
    hybrid: %{
      correlation: %{
        strategy: :timestamp_window | :call_stack | :process | :message_sequence,
        window_ms: pos_integer(),
        max_events_per_correlation: pos_integer(),
        confidence_threshold: float()
      },
      session_management: %{
        max_concurrent_sessions: pos_integer(),
        session_timeout_ms: pos_integer(),
        auto_cleanup_enabled: boolean()
      },
      mode_switching: %{
        enable_auto_escalation: boolean(),
        escalation_thresholds: %{
          events_per_second: pos_integer(),
          correlation_failures: pos_integer(),
          detail_requests: pos_integer()
        }
      }
    },
    
    # AI integration configuration
    ai: %{
      mode_selection: %{
        enabled: boolean(),
        provider: atom(),
        analysis_timeout_ms: pos_integer(),
        confidence_threshold: float()
      },
      instrumentation_planning: %{
        enabled: boolean(),
        complexity_analysis: boolean(),
        historical_data_weight: float(),
        user_preference_weight: float()
      }
    }
  }

  # ============================================================================
  # CONFIGURATION API
  # ============================================================================

  @doc """
  Get the complete unified configuration.
  """
  @spec get_config() :: unified_config()
  def get_config()

  @doc """
  Get configuration for a specific mode.
  """
  @spec get_mode_config(:runtime | :compile_time | :hybrid) :: map()
  def get_mode_config(mode)

  @doc """
  Update configuration for a specific path.
  """
  @spec update_config([atom()], any()) :: :ok | {:error, :invalid_path | :invalid_value}
  def update_config(path, value)

  @doc """
  Get environment-specific configuration overrides.
  """
  @spec get_environment_config(atom()) :: keyword()
  def get_environment_config(env \\ Mix.env())

  @doc """
  Validate a configuration structure.
  """
  @spec validate_config(map()) :: :ok | {:error, [String.t()]}
  def validate_config(config)

  @doc """
  Merge user configuration with defaults.
  """
  @spec merge_config(map(), map()) :: unified_config()
  def merge_config(user_config, defaults)

  @doc """
  Get configuration value with fallback chain.
  """
  @spec get_with_fallback([atom()], any()) :: any()
  def get_with_fallback(path, default)

  # ============================================================================
  # DYNAMIC CONFIGURATION
  # ============================================================================

  @doc """
  Enable/disable a feature flag at runtime.
  """
  @spec set_feature_flag(atom(), boolean()) :: :ok
  def set_feature_flag(flag, enabled)

  @doc """
  Update mode-specific configuration at runtime.
  """
  @spec update_mode_config(:runtime | :compile_time | :hybrid, map()) :: :ok | {:error, atom()}
  def update_mode_config(mode, config_updates)

  @doc """
  Reset configuration to defaults.
  """
  @spec reset_to_defaults() :: :ok
  def reset_to_defaults()
end
```

### **3.2 Configuration Validation & Defaults**

```elixir
defmodule ElixirScope.Config.Defaults do
  @moduledoc """
  Default configuration values and validation rules for the unified system.
  """

  @doc """
  Get default configuration for all modes.
  """
  @spec default_config() :: ElixirScope.Config.Unified.unified_config()
  def default_config()

  @doc """
  Get environment-specific defaults.
  """
  @spec environment_defaults(atom()) :: keyword()
  def environment_defaults(env)

  @doc """
  Validate configuration values and return errors.
  """
  @spec validate_unified_config(map()) :: :ok | {:error, [String.t()]}
  def validate_unified_config(config)
end
```

---

## 4. **Mode Selection Logic**

### **4.1 Core Mode Selection Engine**

```elixir
defmodule ElixirScope.ModeSelection.Engine do
  @moduledoc """
  Intelligent mode selection engine that determines the optimal tracing mode
  based on target analysis, environment, user preferences, and AI recommendations.
  """

  @type selection_context :: %{
    target: ElixirScope.Unified.trace_target(),
    options: ElixirScope.Unified.trace_options(),
    environment: atom(),
    user_preferences: map(),
    historical_data: map(),
    system_resources: map()
  }

  @type selection_result :: %{
    recommended_mode: ElixirScope.Unified.trace_mode(),
    confidence: float(),
    reasoning: String.t(),
    alternatives: [ElixirScope.Unified.trace_mode()],
    requirements: map(),
    warnings: [String.t()]
  }

  @type selection_strategy :: 
    :rule_based | 
    :ai_assisted | 
    :performance_optimized | 
    :user_preference | 
    :hybrid_strategy

  # ============================================================================
  # MODE SELECTION API
  # ============================================================================

  @doc """
  Select the optimal tracing mode for given context.
  """
  @spec select_mode(selection_context(), selection_strategy()) :: selection_result()
  def select_mode(context, strategy \\ :hybrid_strategy)

  @doc """
  Validate that a mode is available and suitable for the target.
  """
  @spec validate_mode_availability(ElixirScope.Unified.trace_target(), ElixirScope.Unified.trace_mode()) :: 
    :ok | {:error, :unavailable | :unsuitable | :compilation_required}
  def validate_mode_availability(target, mode)

  @doc """
  Get detailed capabilities for each mode given the target.
  """
  @spec analyze_mode_capabilities(ElixirScope.Unified.trace_target()) :: %{
    runtime: %{
      available: boolean(),
      capabilities: [atom()],
      limitations: [String.t()],
      performance_impact: :low | :medium | :high
    },
    compile_time: %{
      available: boolean(),
      capabilities: [atom()],
      limitations: [String.t()],
      compilation_required: boolean(),
      performance_impact: :low | :medium | :high
    },
    hybrid: %{
      available: boolean(),
      capabilities: [atom()],
      limitations: [String.t()],
      complexity: :low | :medium | :high,
      performance_impact: :low | :medium | :high
    }
  }
  def analyze_mode_capabilities(target)

  # ============================================================================
  # SELECTION STRATEGIES
  # ============================================================================

  @doc """
  Rule-based mode selection using predefined logic.
  """
  @spec rule_based_selection(selection_context()) :: selection_result()
  def rule_based_selection(context)

  @doc """
  AI-assisted mode selection using code analysis and ML.
  """
  @spec ai_assisted_selection(selection_context()) :: selection_result()
  def ai_assisted_selection(context)

  @doc """
  Performance-optimized selection prioritizing minimal overhead.
  """
  @spec performance_optimized_selection(selection_context()) :: selection_result()
  def performance_optimized_selection(context)

  @doc """
  User preference-based selection with intelligent fallbacks.
  """
  @spec user_preference_selection(selection_context()) :: selection_result()
  def user_preference_selection(context)

  # ============================================================================
  # TARGET ANALYSIS
  # ============================================================================

  @doc """
  Analyze target complexity to inform mode selection.
  """
  @spec analyze_target_complexity(ElixirScope.Unified.trace_target()) :: %{
    complexity_score: pos_integer(),
    function_count: pos_integer(),
    cyclomatic_complexity: pos_integer(),
    dependency_depth: pos_integer(),
    estimated_execution_frequency: :low | :medium | :high,
    recommended_granularity: :function | :expression | :line | :variable
  }
  def analyze_target_complexity(target)

  @doc """
  Check if target requires compilation for AST instrumentation.
  """
  @spec compilation_required?(ElixirScope.Unified.trace_target()) :: boolean()
  def compilation_required?(target)

  @doc """
  Estimate performance impact for each mode on the given target.
  """
  @spec estimate_performance_impact(ElixirScope.Unified.trace_target(), ElixirScope.Unified.trace_mode()) :: 
    %{
      cpu_overhead_percent: float(),
      memory_overhead_mb: pos_integer(),
      latency_impact_ms: float(),
      throughput_impact_percent: float()
    }
  def estimate_performance_impact(target, mode)
end
```

### **4.2 Mode Selection Rules Engine**

```elixir
defmodule ElixirScope.ModeSelection.Rules do
  @moduledoc """
  Rule-based mode selection logic with configurable rules and priorities.
  """

  @type rule :: %{
    name: String.t(),
    condition: (ElixirScope.ModeSelection.Engine.selection_context() -> boolean()),
    recommendation: ElixirScope.Unified.trace_mode(),
    priority: pos_integer(),
    reasoning: String.t()
  }

  @type rule_result :: %{
    rule: rule(),
    matched: boolean(),
    confidence: float()
  }

  # ============================================================================
  # RULES ENGINE API
  # ============================================================================

  @doc """
  Evaluate all rules against the selection context.
  """
  @spec evaluate_rules(ElixirScope.ModeSelection.Engine.selection_context()) :: [rule_result()]
  def evaluate_rules(context)

  @doc """
  Get the highest priority matching rule.
  """
  @spec get_primary_recommendation(ElixirScope.ModeSelection.Engine.selection_context()) :: 
    {:ok, rule_result()} | {:error, :no_matching_rules}
  def get_primary_recommendation(context)

  @doc """
  Add a custom rule to the rules engine.
  """
  @spec add_rule(rule()) :: :ok | {:error, :invalid_rule}
  def add_rule(rule)

  @doc """
  Remove a rule by name.
  """
  @spec remove_rule(String.t()) :: :ok | {:error, :rule_not_found}
  def remove_rule(rule_name)

  # ============================================================================
  # DEFAULT RULES
  # ============================================================================

  @doc """
  Get the default set of mode selection rules.
  """
  @spec default_rules() :: [rule()]
  def default_rules()

  # Example rules:
  # 1. Production environment -> Runtime mode
  # 2. Granular debugging requested -> Compile-time mode
  # 3. Process monitoring -> Runtime mode
  # 4. Local variable access needed -> Compile-time mode
  # 5. High-frequency functions -> Runtime mode with sampling
  # 6. Complex algorithms with debugging -> Hybrid mode
  # 7. Force flags override all other rules
end
```

### **4.3 AI-Assisted Mode Selection**

```elixir
defmodule ElixirScope.ModeSelection.AI do
  @moduledoc """
  AI-powered mode selection using code analysis and machine learning.
  """

  @type ai_analysis :: %{
    code_complexity: map(),
    execution_patterns: map(),
    debugging_context: map(),
    performance_predictions: map(),
    confidence_scores: map()
  }

  # ============================================================================
  # AI SELECTION API
  # ============================================================================

  @doc """
  Perform AI-assisted mode selection analysis.
  """
  @spec analyze_for_mode_selection(ElixirScope.ModeSelection.Engine.selection_context()) :: 
    {:ok, ElixirScope.ModeSelection.Engine.selection_result()} | 
    {:error, :ai_unavailable | :analysis_failed}
  def analyze_for_mode_selection(context)

  @doc """
  Get AI analysis of the target code without mode recommendation.
  """
  @spec analyze_target(ElixirScope.Unified.trace_target()) :: 
    {:ok, ai_analysis()} | {:error, atom()}
  def analyze_target(target)

  @doc """
  Train the AI model with historical mode selection outcomes.
  """
  @spec train_with_feedback(ElixirScope.ModeSelection.Engine.selection_context(), 
                           ElixirScope.Unified.trace_mode(), 
                           :successful | :failed | :suboptimal) :: :ok
  def train_with_feedback(context, selected_mode, outcome)
end
```

---

## 5. **Data Types & Structures**

### **5.1 Core Data Types**

```elixir
defmodule ElixirScope.Types do
  @moduledoc """
  Core data types used throughout the unified ElixirScope system.
  """

  # Session management
  @type session_id :: reference()
  @type correlation_id :: String.t()
  @type event_id :: String.t()

  # Tracing targets
  @type module_target :: module()
  @type function_target :: {module(), atom()} | {module(), atom(), arity()}
  @type process_target :: pid()
  @type trace_target :: module_target() | function_target() | process_target() | [trace_target()]

  # Event classification
  @type event_type :: 
    :function_entry | :function_exit | :function_exception |
    :variable_assignment | :variable_access |
    :expression_evaluation | :line_execution |
    :message_send | :message_receive |
    :state_change | :process_spawn | :process_exit |
    :custom

  @type event_category :: 
    :function_call | :variable_change | :message | :state_change | :process_lifecycle | :custom

  # Tracing modes and granularity
  @type trace_mode :: :runtime | :compile_time | :hybrid | :auto
  @type granularity_level :: :function | :expression | :line | :variable

  # Performance and resource tracking
  @type performance_metrics :: %{
    cpu_usage_percent: float(),
    memory_usage_mb: pos_integer(),
    event_rate_per_second: pos_integer(),
    correlation_success_rate: float()
  }

  # Configuration and options
  @type feature_flag :: atom()
  @type environment :: :dev | :test | :prod | atom()
end
```

### **5.2 Event Data Structures**

```elixir
defmodule ElixirScope.Events.Types do
  @moduledoc """
  Detailed event data structures for different event types.
  """

  @type function_call_data :: %{
    arguments: [any()],
    return_value: any() | nil,
    exception: any() | nil,
    duration_ns: pos_integer() | nil,
    memory_before: pos_integer() | nil,
    memory_after: pos_integer() | nil
  }

  @type variable_change_data :: %{
    variable_name: atom(),
    old_value: any() | :undefined,
    new_value: any(),
    scope: :local | :module | :process,
    binding_context: map()
  }

  @type message_data :: %{
    from_pid: pid(),
    to_pid: pid(),
    message: any(),
    message_size_bytes: pos_integer(),
    delivery_time_ns: pos_integer() | nil
  }

  @type state_change_data :: %{
    component: :genserver | :agent | :ets | :process | atom(),
    old_state: any() | :undefined,
    new_state: any(),
    change_reason: atom() | String.t()
  }
end
```

---

## 6. **Error Handling**

### **6.1 Error Types and Recovery**

```elixir
defmodule ElixirScope.Errors do
  @moduledoc """
  Comprehensive error handling for the unified ElixirScope system.
  """

  @type error_category :: 
    :configuration | :mode_selection | :compilation | :runtime | :correlation | :system

  @type error_severity :: :info | :warning | :error | :critical

  @type elixir_scope_error :: %{
    category: error_category(),
    severity: error_severity(),
    code: atom(),
    message: String.t(),
    details: map(),
    recovery_suggestions: [String.t()],
    timestamp: DateTime.t()
  }

  # Common error codes
  @type error_code :: 
    # Mode selection errors
    :mode_unavailable | :compilation_required | :target_invalid |
    # Configuration errors  
    :invalid_config | :config_validation_failed | :feature_disabled |
    # Runtime errors
    :trace_limit_exceeded | :resource_exhausted | :permission_denied |
    # Compilation errors
    :compilation_failed | :ast_transformation_failed | :module_not_found |
    # Correlation errors
    :correlation_timeout | :correlation_failed | :session_not_found |
    # System errors
    :system_overload | :dependency_unavailable | :internal_error

  # ============================================================================
  # ERROR HANDLING API
  # ============================================================================

  @doc """
  Create a standardized error structure.
  """
  @spec create_error(error_category(), error_code(), String.t(), map()) :: elixir_scope_error()
  def create_error(category, code, message, details \\ %{})

  @doc """
  Handle an error with appropriate recovery actions.
  """
  @spec handle_error(elixir_scope_error()) :: :ok | :retry | {:fallback, any()} | :abort
  def handle_error(error)

  @doc """
  Get recovery suggestions for an error.
  """
  @spec get_recovery_suggestions(error_code()) :: [String.t()]
  def get_recovery_suggestions(error_code)

  @doc """
  Check if an error is recoverable.
  """
  @spec recoverable?(elixir_scope_error()) :: boolean()
  def recoverable?(error)
end
```

---

## 7. **Implementation Contracts**

### **7.1 Module Implementation Requirements**

```elixir
defmodule ElixirScope.Contracts do
  @moduledoc """
  Implementation contracts and behavior definitions for unified system components.
  """

  # ============================================================================
  # UNIFIED INTERFACE CONTRACT
  # ============================================================================

  @doc """
  Contract for the main unified interface implementation.
  Must provide seamless mode selection and delegation.
  """
  defmacro __using__(:unified_interface) do
    quote do
      @behaviour ElixirScope.Behaviours.UnifiedInterface
      
      # Required callbacks
      @callback trace(ElixirScope.Unified.trace_target(), ElixirScope.Unified.trace_options()) :: 
        ElixirScope.Unified.trace_result()
      @callback stop_trace(reference()) :: :ok | {:error, atom()}
      @callback determine_mode(ElixirScope.Unified.trace_target(), ElixirScope.Unified.trace_options()) :: 
        {:ok, ElixirScope.Unified.trace_mode(), String.t()} | {:error, atom()}
    end
  end

  # ============================================================================
  # EVENT CORRELATION CONTRACT
  # ============================================================================

  @doc """
  Contract for event correlation implementations.
  Must handle cross-system event matching and timing.
  """
  defmacro __using__(:event_correlator) do
    quote do
      @behaviour ElixirScope.Behaviours.EventCorrelator
      
      @callback correlate_event(reference(), ElixirScope.Events.Event.t()) :: 
        {:ok, ElixirScope.Events.Correlator.correlated_event()} | 
        {:pending, ElixirScope.Events.Correlator.correlation_id()} | 
        {:error, atom()}
      @callback flush_pending_correlations(reference()) :: 
        [ElixirScope.Events.Correlator.correlated_event()]
    end
  end

  # ============================================================================
  # MODE SELECTION CONTRACT
  # ============================================================================

  @doc """
  Contract for mode selection implementations.
  Must provide intelligent mode recommendations.
  """
  defmacro __using__(:mode_selector) do
    quote do
      @behaviour ElixirScope.Behaviours.ModeSelector
      
      @callback select_mode(ElixirScope.ModeSelection.Engine.selection_context()) :: 
        ElixirScope.ModeSelection.Engine.selection_result()
      @callback validate_mode_availability(ElixirScope.Unified.trace_target(), ElixirScope.Unified.trace_mode()) :: 
        :ok | {:error, atom()}
    end
  end

  # ============================================================================
  # CONFIGURATION CONTRACT
  # ============================================================================

  @doc """
  Contract for configuration implementations.
  Must provide unified configuration management.
  """
  defmacro __using__(:config_manager) do
    quote do
      @behaviour ElixirScope.Behaviours.ConfigManager
      
      @callback get_config() :: ElixirScope.Config.Unified.unified_config()
      @callback update_config([atom()], any()) :: :ok | {:error, atom()}
      @callback validate_config(map()) :: :ok | {:error, [String.t()]}
    end
  end
end
```

### **7.2 Integration Points**

```elixir
defmodule ElixirScope.Integration do
  @moduledoc """
  Defines integration points between different system components.
  """

  # ============================================================================
  # RUNTIME-AST INTEGRATION
  # ============================================================================

  @doc """
  Integration contract between runtime and AST systems.
  """
  @spec runtime_ast_integration_points() :: [
    {:event_forwarding, module(), atom()},
    {:correlation_id_sharing, module(), atom()},
    {:session_coordination, module(), atom()},
    {:configuration_sync, module(), atom()}
  ]
  def runtime_ast_integration_points()

  # ============================================================================
  # EVENT PIPELINE INTEGRATION
  # ============================================================================

  @doc """
  Integration contract for the unified event pipeline.
  """
  @spec event_pipeline_integration() :: %{
    ingestion: module(),
    correlation: module(),
    storage: module(),
    querying: module()
  }
  def event_pipeline_integration()

  # ============================================================================
  # CONFIGURATION INTEGRATION
  # ============================================================================

  @doc """
  Integration contract for configuration propagation.
  """
  @spec configuration_integration() :: %{
    unified_config: module(),
    mode_configs: %{
      runtime: module(),
      compile_time: module(),
      hybrid: module()
    },
    validation: module()
  }
  def configuration_integration()
end
```

---

## 🎯 **Implementation Priority**

### **Phase 1: Core Contracts (Immediate)**
1. Implement `ElixirScope.Unified` with basic mode selection
2. Create `ElixirScope.Events.Correlator` foundation
3. Implement `ElixirScope.Config.Unified` structure
4. Build `ElixirScope.ModeSelection.Engine` core

### **Phase 2: Integration (Next)**
1. Runtime-AST event correlation
2. Hybrid session management
3. Configuration propagation
4. Error handling and recovery

### **Phase 3: Advanced Features (Future)**
1. AI-assisted mode selection
2. Performance optimization
3. Advanced correlation strategies
4. Production hardening

---

This API design provides the complete blueprint for implementing the unified ElixirScope system. Each contract is designed to be implementable incrementally while maintaining backward compatibility with the existing runtime system. 