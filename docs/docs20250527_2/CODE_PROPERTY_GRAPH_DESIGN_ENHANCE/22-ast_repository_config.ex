defmodule ElixirScope.ASTRepository.Config do
  @moduledoc """
  Provides centralized configuration management for all components
  within the `ElixirScope.ASTRepository` namespace.

  It fetches configuration values from the application environment
  (e.g., `config/config.exs`) with sensible defaults.
  """

  @app :elixir_scope
  @repo_config_key :ast_repository

  # --- Default Values ---

  # Repository GenServer
  def default_repository_name(), do: ElixirScope.ASTRepository.Repository
  def default_max_memory_mb(), do: 500 # Max ETS memory for the repository
  def default_ets_table_options(), do: [:set, :public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}]
  def default_ets_bag_table_options(), do: [:bag, :public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}]

  # ProjectPopulator
  def default_populator_include_deps(), do: false
  def default_populator_include_test_files(), do: true
  # Reuse from ProjectPopulator to keep defaults consistent
  def default_populator_file_patterns(), do: ElixirScope.ASTRepository.ProjectPopulator.default_file_patterns()
  def default_populator_ignore_patterns(), do: ElixirScope.ASTRepository.ProjectPopulator.default_ignore_patterns()
  def default_populator_parallel_workers(), do: System.schedulers_online()
  def default_populator_file_processing_timeout_ms(), do: 60_000 # 60 seconds

  # FileWatcher
  def default_watcher_debounce_ms(), do: ElixirScope.ASTRepository.FileWatcher.default_debounce_ms() # Reuse
  def default_watcher_name(), do: ElixirScope.ASTRepository.FileWatcher

  # ASTAnalyzer & Generators (General options)
  def default_analysis_timeout_ms(), do: 30_000 # Timeout for analyzing a single complex module/function
  def default_max_ast_nodes_per_function_for_full_cpg(), do: 5000 # Limit for generating full CPG to prevent excessive processing
  def default_ast_node_id_strategy(), do: :path_hash_line # :path | :content_hash | :path_hash_line

  # Querying & Caching
  def default_query_cache_ttl_ms(), do: 60_000 # 1 minute for AST query results
  def default_max_query_cache_size(), do: 1000 # Number of cached query results
  def default_query_execution_timeout_ms(), do: 10_000 # 10 seconds

  # --- Accessor Functions ---

  @doc "Gets a configuration value for the AST Repository."
  def get(key_path, default_value \\ nil) when is_list(key_path) do
    Application.get_env(@app, [@repo_config_key | key_path], default_value)
  end

  def get(key, default_value \\ nil) do
    Application.get_env(@app, [@repo_config_key, key], default_value)
  end

  # --- Specific Configuration Getters with Defaults ---

  # Repository
  def repository_genserver_name(), do: get(:repository_name, default_repository_name())
  def repository_max_memory_mb(), do: get(:max_memory_mb, default_max_memory_mb())
  def repository_ets_table_options(:set), do: get(:ets_set_table_options, default_ets_table_options())
  def repository_ets_table_options(:bag), do: get(:ets_bag_table_options, default_ets_bag_table_options())
  def repository_ets_table_options(_type), do: repository_ets_table_options(:set) # Default

  # ProjectPopulator
  def populator_include_deps?(), do: get(:populator_include_deps, default_populator_include_deps())
  def populator_include_test_files?(), do: get(:populator_include_test_files, default_populator_include_test_files())
  def populator_file_patterns(), do: get(:populator_file_patterns, default_populator_file_patterns())
  def populator_ignore_patterns() do
    base_ignore = get(:populator_ignore_patterns, default_populator_ignore_patterns())
    deps_ignore = if populator_include_deps?(), do: [], else: ["deps/**"]
    test_ignore = if populator_include_test_files?(), do: [], else: ["test/**", "test/**/*_test.exs"] # More specific test ignore
    Enum.uniq(base_ignore ++ deps_ignore ++ test_ignore)
  end
  def populator_parallel_workers(), do: get(:populator_parallel_workers, default_populator_parallel_workers())
  def populator_file_processing_timeout_ms(), do: get(:populator_file_processing_timeout_ms, default_populator_file_processing_timeout_ms())

  # FileWatcher
  def watcher_debounce_ms(), do: get(:watcher_debounce_ms, default_watcher_debounce_ms())
  def watcher_genserver_name(), do: get(:watcher_name, default_watcher_name())
  def watcher_file_patterns(), do: get(:watcher_file_patterns, populator_file_patterns()) # Watcher uses same patterns as populator by default
  def watcher_ignore_patterns(), do: get(:watcher_ignore_patterns, populator_ignore_patterns()) # Watcher uses same ignore patterns

  # Analysis
  def analysis_timeout_ms(), do: get(:analysis_timeout_ms, default_analysis_timeout_ms())
  def max_ast_nodes_for_full_cpg(), do: get(:max_ast_nodes_for_full_cpg, default_max_ast_nodes_per_function_for_full_cpg())
  def ast_node_id_strategy(), do: get(:ast_node_id_strategy, default_ast_node_id_strategy())

  # Querying
  def query_cache_ttl_ms(), do: get(:query_cache_ttl_ms, default_query_cache_ttl_ms())
  def query_max_cache_size(), do: get(:query_max_cache_size, default_max_query_cache_size())
  def query_execution_timeout_ms(), do: get(:query_execution_timeout_ms, default_query_execution_timeout_ms())


  @doc """
  Returns all AST repository configurations.
  Useful for debugging or initializing components that need multiple config values.
  """
  def all_configs do
    %{
      repository_name: repository_genserver_name(),
      max_memory_mb: repository_max_memory_mb(),
      ets_set_table_options: repository_ets_table_options(:set),
      ets_bag_table_options: repository_ets_table_options(:bag),
      populator_include_deps: populator_include_deps?(),
      populator_include_test_files: populator_include_test_files?(),
      populator_file_patterns: populator_file_patterns(),
      populator_ignore_patterns: populator_ignore_patterns(),
      populator_parallel_workers: populator_parallel_workers(),
      populator_file_processing_timeout_ms: populator_file_processing_timeout_ms(),
      watcher_debounce_ms: watcher_debounce_ms(),
      watcher_name: watcher_genserver_name(),
      watcher_file_patterns: watcher_file_patterns(),
      watcher_ignore_patterns: watcher_ignore_patterns(),
      analysis_timeout_ms: analysis_timeout_ms(),
      max_ast_nodes_for_full_cpg: max_ast_nodes_for_full_cpg(),
      ast_node_id_strategy: ast_node_id_strategy(),
      query_cache_ttl_ms: query_cache_ttl_ms(),
      query_max_cache_size: query_max_cache_size(),
      query_execution_timeout_ms: query_execution_timeout_ms()
    }
  end

  @doc """
  Example of how this configuration might be used in `config/config.exs`:

  config :elixir_scope, :ast_repository,
    max_memory_mb: 1024, # Override default 500MB
    populator_ignore_patterns: ElixirScope.ASTRepository.ProjectPopulator.default_ignore_patterns() ++ ["**/generated/**"],
    ast_node_id_strategy: :content_hash, # If we implement this strategy
    query_cache_ttl_ms: 300_000 # 5 minutes for query cache
  """
  def config_example do
    :ok
  end

end
