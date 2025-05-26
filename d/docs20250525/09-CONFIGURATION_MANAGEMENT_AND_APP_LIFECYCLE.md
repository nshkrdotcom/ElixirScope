Okay, we've covered a lot of ground: AI planning, AST transformation, the runtime interface (`InstrumentationRuntime`), the capture pipeline (Ingestor, RingBuffer, AsyncWriters), event correlation (`EventCorrelator`), hot storage (`DataAccess`), and Phoenix integration.

A significant piece of the puzzle, especially for a system that aims to operate in diverse environments and manage large data volumes, is **Configuration Management (`ElixirScope.Config`) and overall Application Lifecycle (`ElixirScope.Application`, `ElixirScope` main module)**. This governs how ElixirScope is started, stopped, configured, and how its core components are supervised.

---

**ElixirScope Technical Document: Configuration Management and Application Lifecycle**

**Document Version:** 1.9
**Date:** 2024-05-24
**Authors:** ElixirScope Team (AI Assisted)

**Abstract:**

This document details the configuration management system and the overall application lifecycle of ElixirScope, as primarily implemented in the `ElixirScope.Config`, `ElixirScope.Application`, and the main `ElixirScope` API modules. It covers how ElixirScope loads and validates its settings, how these settings influence the behavior of various components, how runtime configuration updates are handled, and the supervision strategy for ensuring the reliability of ElixirScope's core services. Effective configuration and lifecycle management are essential for adapting ElixirScope to different environments (development, testing, production) and for controlling its performance overhead and data capture granularity.

**Table of Contents:**

1.  Introduction and Purpose
    1.1. Importance of Robust Configuration and Lifecycle Management
    1.2. Design Goals: Flexibility, Reliability, Ease of Use
2.  `ElixirScope.Config` Module
    2.1. Configuration Schema (`ElixirScope.Config` struct)
        2.1.1. AI Configuration (`ai.*`)
        2.1.2. Capture Configuration (`capture.*`)
        2.1.3. Storage Configuration (`storage.*`)
        2.1.4. Interface Configuration (`interface.*`)
        2.1.5. Instrumentation Configuration (`instrumentation.*`)
    2.2. Configuration Loading Mechanism
        2.2.1. Default Values (in struct definition)
        2.2.2. Application Environment (`config/*.exs`)
        2.2.3. Environment Variables (Limited Support)
        2.2.4. Merging Strategy
    2.3. Configuration Validation (`Config.validate/1`)
        2.3.1. Type Checking, Range Validation, Enum Validation
        2.3.2. Handling Invalid Configurations at Startup
    2.4. Runtime Configuration Access (`Config.get/0`, `Config.get/1`)
    2.5. Runtime Configuration Updates (`Config.update/2`)
        2.5.1. Whitelisted Updatable Paths (`updatable_path?/1`)
        2.5.2. Validation of Updated Values
    2.6. `GenServer`-based Implementation of `ElixirScope.Config`
3.  `ElixirScope.Application` Module
    3.1. OTP Application Behaviour (`use Application`)
    3.2. `start/2` Function: Supervision Tree Setup
        3.2.1. Starting `ElixirScope.Config` First
        3.2.2. Starting Core Service Supervisors (e.g., `Capture.PipelineManager`)
        3.2.3. Order of Component Initialization
    3.3. `stop/1` Function: Graceful Shutdown
    3.4. Supervision Strategy (e.g., `:one_for_one`)
4.  Main `ElixirScope` API Module
    4.1. `ElixirScope.start/1`
        4.1.1. Ensuring Application is Started (`Application.ensure_all_started/1`)
        4.1.2. Applying Runtime Options via `Config.update/2`
    4.2. `ElixirScope.stop/0`
        4.2.1. Calling `Application.stop/1`
    4.3. `ElixirScope.status/0`
        4.3.1. Checking `running?/0`
        4.3.2. Aggregating Status from Config, Performance Stats (Placeholder), Storage Stats (Placeholder)
    4.4. `ElixirScope.running?/0`
        4.4.1. Checking Application Status and Supervisor Presence
    4.5. Other API Functions (Querying, AI Triggers)
        4.5.1. Guarding with `running?/0`
        4.5.2. Interaction with underlying service modules
5.  Interaction of Configuration with Core Components
    5.1. AI Layer: `ai.planning.default_strategy`, `ai.planning.sampling_rate`
    5.2. Capture Pipeline: `capture.ring_buffer.*`, `capture.processing.*`
    5.3. Storage Layer: `storage.hot.*`
    5.4. Instrumentation Layer: `instrumentation.*` (Used by AI Planner)
6.  Testing Configuration and Application Lifecycle
7.  Future Considerations (e.g., Multi-Node Configuration Sync)
8.  Conclusion

---

## 1. Introduction and Purpose

### 1.1. Importance of Robust Configuration and Lifecycle Management

A system as comprehensive as ElixirScope, designed to operate in various modes (e.g., development full-recall, production low-overhead) and interact deeply with user applications, requires a robust configuration system and well-defined application lifecycle.
*   **Configuration** allows users and the AI to tune ElixirScope's behavior, balancing detail of captured data against performance overhead and resource consumption.
*   **Lifecycle Management** (OTP Application and Supervision) ensures that ElixirScope starts, stops, and runs reliably, with its various components correctly initialized and supervised.

### 1.2. Design Goals

*   **Flexibility:** Allow users to configure a wide range of parameters to suit their needs.
*   **Reliability:** Ensure ElixirScope starts correctly with validated configuration and its components are supervised for fault tolerance.
*   **Ease of Use:** Provide sensible defaults and clear ways to override them. Make starting/stopping ElixirScope straightforward.
*   **Dynamic Control:** Allow certain critical parameters (e.g., sampling rate, active instrumentation strategy) to be updated at runtime without restarting the application.

## 2. `ElixirScope.Config` Module

This `GenServer` is the central point for managing ElixirScope's configuration.

### 2.1. Configuration Schema (`ElixirScope.Config` struct)

The `ElixirScope.Config` struct defines the comprehensive schema for all configurable aspects of the system. The `config/config.exs` file provides an example of this structure:

*   **2.1.1. AI Configuration (`ai.*`):**
    *   `provider`, `api_key`, `model`: For future LLM integration.
    *   `analysis.*`: Parameters for code analysis (max file size, timeout, cache TTL).
    *   `planning.*`: `default_strategy` (:minimal, :balanced, :full_trace), `performance_target` (max overhead), `sampling_rate`.
*   **2.1.2. Capture Configuration (`capture.*`):**
    *   `ring_buffer.*`: `size`, `max_events`, `overflow_strategy`, `num_buffers` (e.g., `:schedulers` indicating one per scheduler).
    *   `processing.*`: `batch_size`, `flush_interval`, `max_queue_size` for `AsyncWriter`s.
    *   `vm_tracing.*`: Flags for enabling specific VM-level traces.
*   **2.1.3. Storage Configuration (`storage.*`):**
    *   `hot.*`: Parameters for ETS-based hot storage (`max_events`, `max_age_seconds`, `prune_interval`).
    *   `warm.*`, `cold.*`: Parameters for future disk-based and archival storage.
*   **2.1.4. Interface Configuration (`interface.*`):**
    *   `iex_helpers`: Flag to enable/disable IEx helper functions.
    *   `query_timeout`: Default timeout for data queries.
    *   `web.*`: Parameters for the future "Execution Cinema" web UI.
*   **2.1.5. Instrumentation Configuration (`instrumentation.*`):**
    *   `default_level`: Global instrumentation detail level.
    *   `module_overrides`, `function_overrides`: Specific overrides for AI planning.
    *   `exclude_modules`: List of modules to always exclude from instrumentation.

### 2.2. Configuration Loading Mechanism

Configuration is loaded in layers, with later layers overriding earlier ones:
1.  **Default Values:** Defined directly in the `ElixirScope.Config` struct definition.
2.  **Application Environment (`config/*.exs`):** Values from `config/config.exs`, `config/dev.exs`, etc., are loaded via `Application.get_all_env(:elixir_scope)` and merged. `Config.merge_application_env/1` uses `Config.merge_config/2` and `Config.merge_nested_config/2` to deeply merge these keyword lists/maps into the config struct.
3.  **Environment Variables (Limited Support):** `Config.merge_environment_variables/1` checks for specific environment variables (e.g., `ELIXIR_SCOPE_AI_PROVIDER`) and overrides corresponding config paths if set.
4.  **Runtime Options (via `ElixirScope.start(opts)`):** These are applied *after* initial loading by calling `ElixirScope.Config.update/2`.

### 2.3. Configuration Validation (`Config.validate/1`)

Performed during `ElixirScope.Config.init/1` (`load_and_validate_config/0`).
*   **Mechanism:** A series of private `validate_X_config/1` functions, each checking a subsection of the config. These use helper validators like `validate_required_keys/2`, `validate_positive_integer/2`, `validate_percentage/2`, `validate_ai_provider/1`, etc.
*   **Actions:** Checks for required keys, correct data types, valid enum values, and sensible ranges (e.g., percentages between 0 and 1).
*   **Failure:** If validation fails, `ElixirScope.Config` GenServer fails to start, which in turn prevents `ElixirScope.Application` from starting successfully, providing an early warning of misconfiguration. Error messages indicate the problematic field.

### 2.4. Runtime Configuration Access (`Config.get/0`, `Config.get/1`)

*   `Config.get()`: Returns the entire current configuration struct via `GenServer.call(__MODULE__, :get_config)`.
*   `Config.get(path :: list(atom()))`: Returns a specific value from the configuration struct using a key path (e.g., `[:ai, :planning, :sampling_rate]`) via `GenServer.call(__MODULE__, {:get_config_path, path})`. The `get_config_path/2` helper recursively traverses the config map/struct.

### 2.5. Runtime Configuration Updates (`Config.update/2`)

Allows modifying certain configuration values while ElixirScope is running, via `GenServer.call(__MODULE__, {:update_config, path, value})`.
#### 2.5.1. Whitelisted Updatable Paths (`updatable_path?/1`)
Only specific, "safe" configuration paths are allowed to be updated at runtime to prevent destabilizing the system. The `updatable_path?/1` function defines this whitelist:
    *   `[:ai, :planning, :sampling_rate]`
    *   `[:ai, :planning, :default_strategy]`
    *   `[:capture, :processing, :batch_size]`
    *   `[:capture, :processing, :flush_interval]`
    *   `[:interface, :query_timeout]`
#### 2.5.2. Validation of Updated Values
When an update is attempted:
1.  The path is checked against `updatable_path?/1`.
2.  If allowed, a new candidate configuration struct is created with the updated value (`update_config_path/3`).
3.  This *entire* new configuration struct is then re-validated using `Config.validate/1`.
4.  If validation passes, the `ElixirScope.Config` GenServer updates its state to the new configuration. If validation fails, the update is rejected, and the old configuration is retained.

### 2.6. `GenServer`-based Implementation of `ElixirScope.Config`

Using a `GenServer` for configuration management provides:
*   A single source of truth for the current configuration.
*   Controlled access and updates.
*   Ability to perform actions (like logging) upon successful configuration updates.
*   Integration into the application's supervision tree.

## 3. `ElixirScope.Application` Module

This module implements the OTP `Application` behaviour, defining how ElixirScope starts and stops as part of an Elixir application.

### 3.1. OTP Application Behaviour (`use Application`)

Standard OTP practice for manageable applications.

### 3.2. `start/2` Function: Supervision Tree Setup

1.  **Logging:** Logs "Starting ElixirScope application...".
2.  **Children Definition:** Defines a list of child specifications for ElixirScope's main services. Critically:
    *   `{ElixirScope.Config, []}` is usually the first child to ensure configuration is loaded and validated before other components start.
    *   Other children would include `ElixirScope.Capture.PipelineManager` (which in turn supervises `AsyncWriterPool`, etc.), `ElixirScope.AI.Orchestrator`, and (in the future) `ElixirScope.Storage.QueryCoordinator`. The current `application.ex` shows these as commented out, indicating a phased implementation where `Config` is the primary initial child.
3.  **Supervisor Startup:** Calls `Supervisor.start_link(children, opts)` with `opts = [strategy: :one_for_one, name: ElixirScope.Supervisor]`. This means if one child process dies, only that child is restarted.

### 3.3. `stop/1` Function: Graceful Shutdown

Logs "Stopping ElixirScope application..." and returns `:ok`. Actual shutdown of child processes is handled by the supervisor when the ElixirScope application itself is stopped.

### 3.4. Supervision Strategy

Currently `:one_for_one`. This is suitable if the main service components (like `PipelineManager`, `AI.Orchestrator`) are largely independent. If there are tighter dependencies where failure of one necessitates restarting others, `:one_for_all` or `:rest_for_one` might be considered, but often designing services for independent restartability is preferred.

## 4. Main `ElixirScope` API Module

This module (`lib/elixir_scope.ex`) provides the primary public API for users to interact with ElixirScope.

### 4.1. `ElixirScope.start/1`

1.  Calls `Application.ensure_all_started(:elixir_scope)` to start the OTP application (and thus `ElixirScope.Config` and other supervised children).
2.  If successful, it iterates through `opts` passed to `start/1` and applies them as runtime configuration updates using `ElixirScope.Config.update/2` via the private `configure_runtime_options/1` helper. This allows for easy overriding of defaults at startup (e.g., `ElixirScope.start(strategy: :full_trace)`).
3.  Logs success or failure.

### 4.2. `ElixirScope.stop/0`

1.  Calls `Application.stop(:elixir_scope)` to stop the OTP application.
2.  Logs the action. It gracefully handles cases where the application might not have been fully started.

### 4.3. `ElixirScope.status/0`

1.  Checks `ElixirScope.running?/0`.
2.  If running, it fetches the current configuration (`ElixirScope.Config.get/0` via `get_current_config/0`, which simplifies it) and placeholder stats for performance and storage.
3.  Returns a map summarizing the current state.

### 4.4. `ElixirScope.running?/0`

Determines if ElixirScope is active by:
1.  Checking if the `:elixir_scope` application is listed by `Application.get_application/1`.
2.  Verifying that the main supervisor `ElixirScope.Supervisor` is registered (`Process.whereis(ElixirScope.Supervisor)`).
This provides a robust check.

### 4.5. Other API Functions (Querying, AI Triggers)

Functions like `get_events/1`, `get_state_history/1`, `analyze_codebase/1`, `update_instrumentation/1` are currently placeholders returning `{:error, :not_implemented_yet}`. They all correctly first check `running?/0` and return `{:error, :not_running}` if ElixirScope is not active. This is good practice.

## 5. Interaction of Configuration with Core Components

The configuration loaded by `ElixirScope.Config` is accessed by various components to tailor their behavior:

*   **AI Layer (`AI.Orchestrator`, `AI.CodeAnalyzer`):** Uses `ai.planning.default_strategy`, `ai.planning.sampling_rate`, `ai.analysis.*` to guide instrumentation plan generation.
*   **Capture Pipeline:**
    *   `RingBuffer`: `capture.ring_buffer.size`, `overflow_strategy`, `num_buffers`.
    *   `AsyncWriterPool/AsyncWriter`: `capture.processing.batch_size`, `flush_interval`.
*   **Storage Layer (`DataAccess`):** Uses `storage.hot.*` settings for pruning and managing ETS table limits.
*   **Instrumentation (via AI Plan):** `instrumentation.default_level`, `module_overrides`, `function_overrides`, `exclude_modules` are inputs to the AI planning phase, influencing the generated instrumentation plan that the AST Transformer uses.

## 6. Testing Configuration and Application Lifecycle

*   **`ElixirScope.ConfigTest`:**
    *   Tests validation logic for various config sections (AI, capture, storage).
    *   Verifies default values and rejection of invalid values.
    *   Tests runtime updates: getting config by path, updating allowed paths, rejecting updates to non-allowed paths, validation of updated values.
*   **`ElixirScopeTest` (Main API tests):**
    *   Tests application `start/stop` lifecycle, including with custom options.
    *   Verifies `status/0` and `running?/0` reflect the correct state.
    *   Tests `get_config/0` and `update_config/2` through the main API.
    *   Includes performance tests for basic API calls (start, status, config access).
    *   Checks robustness with rapid start/stop cycles.

## 7. Future Considerations

*   **Multi-Node Configuration Sync:** For distributed ElixirScope, ensuring consistent configuration (or node-specific overrides with a global view) across the cluster will be important. This might involve `NodeCoordinator` playing a role.
*   **Schema Evolution:** As ElixirScope evolves, the configuration schema will change. Mechanisms for migrating old configurations or handling deprecated keys gracefully will be needed.
*   **More Sophisticated Environment Variable Mapping:** Allow more configuration options to be set via environment variables for easier deployment in containerized environments.

## 8. Conclusion

ElixirScope's configuration management and application lifecycle are built on standard OTP principles, providing a solid foundation. The `ElixirScope.Config` GenServer offers a centralized, validated source of truth for settings, with support for runtime updates of key parameters. The `ElixirScope.Application` module ensures a clean startup and shutdown sequence for core services. The main `ElixirScope` API module provides user-friendly functions for controlling and interacting with the system. The existing tests for these components cover critical aspects of their functionality. This setup is well-prepared to support the complex and configurable nature of the "Execution Cinema" debugger as more features are implemented.