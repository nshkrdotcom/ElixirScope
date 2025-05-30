defmodule ElixirScope.ASTRepository.Enhanced.ProjectPopulator do
  @moduledoc """
  Enhanced project populator for comprehensive AST analysis and repository population.

  Provides functionality to:
  - Discover and parse all Elixir files in a project
  - Generate enhanced module and function data with CFG/DFG/CPG analysis
  - Populate the enhanced repository with analyzed data
  - Track dependencies and build project-wide analysis
  - Support parallel processing for large projects
  """

  require Logger

  alias ElixirScope.ASTRepository.Enhanced.{
    Repository,
    EnhancedModuleData,
    EnhancedFunctionData,
    CFGGenerator,
    DFGGenerator,
    CPGBuilder
  }

  alias ElixirScope.ASTRepository.Enhanced.ProjectPopulator.{
    FileDiscovery,
    FileParser,
    ModuleAnalyzer,
    DependencyAnalyzer,
    PerformanceMetrics
  }

  @default_opts [
    include_patterns: ["**/*.ex", "**/*.exs"],
    exclude_patterns: ["**/deps/**", "**/build/**", "**/_build/**", "**/node_modules/**"],
    max_file_size: 1_000_000,  # 1MB
    parallel_processing: true,
    max_concurrency: System.schedulers_online(),
    timeout: 30_000,
    generate_cfg: true,
    generate_dfg: true,
    generate_cpg: false,  # CPG is expensive, opt-in
    validate_syntax: true,
    track_dependencies: true
  ]

  @doc """
  Populates the repository with all Elixir files in a project.

  Returns {:ok, results} or {:error, reason}
  """
  def populate_project(repo, project_path, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    Logger.info("Starting project population for: #{project_path}")
    start_time = System.monotonic_time(:microsecond)

    try do
      with {:ok, files} <- FileDiscovery.discover_elixir_files(project_path, opts),
           {:ok, parsed_files} <- FileParser.parse_files(files, opts),
           {:ok, analyzed_modules} <- ModuleAnalyzer.analyze_modules(parsed_files, opts),
           {:ok, dependency_graph} <- DependencyAnalyzer.build_dependency_graph(analyzed_modules, opts) do

        # Store modules in repository
        try do
          Enum.each(analyzed_modules, fn {_module_name, module_data} ->
            Repository.store_module(repo, module_data)

            # Store functions
            Enum.each(module_data.functions, fn {_key, function_data} ->
              Repository.store_function(repo, function_data)
            end)
          end)
        rescue
          e ->
            Logger.error("Failed to store modules in repository: #{Exception.message(e)}")
            throw({:repository_storage_failed, Exception.message(e)})
        catch
          :exit, reason ->
            Logger.error("Repository process exited during storage: #{inspect(reason)}")
            throw({:repository_unavailable, reason})
        end

        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time

        results = %{
          project_path: project_path,
          files_discovered: length(files),
          files_parsed: length(parsed_files),
          modules: analyzed_modules,
          total_functions: count_total_functions(analyzed_modules),
          dependency_graph: dependency_graph,
          duration_microseconds: duration,
          performance_metrics: PerformanceMetrics.calculate_performance_metrics(parsed_files, analyzed_modules, duration)
        }

        Logger.info("Project population completed: #{length(analyzed_modules)} modules, #{results.total_functions} functions in #{duration / 1000}ms")
        {:ok, results}
      else
        {:error, reason} = error ->
          Logger.error("Project population failed: #{inspect(reason)}")
          error
      end
    rescue
      e ->
        Logger.error("Project population crashed: #{Exception.message(e)}")
        {:error, {:population_crashed, Exception.message(e)}}
    catch
      {:repository_storage_failed, message} ->
        {:error, {:repository_storage_failed, message}}
      {:repository_unavailable, reason} ->
        {:error, {:repository_unavailable, reason}}
    end
  end

  @doc """
  Parses and analyzes a single file (used by Synchronizer).
  """
  def parse_and_analyze_file(file_path) do
    try do
      with {:ok, parsed_file} <- FileParser.parse_single_file(file_path, true, 30_000),
           {:ok, {_module_name, module_data}} <- ModuleAnalyzer.analyze_single_module(parsed_file, true, true, false, 30_000) do
        {:ok, module_data}
      else
        {:error, reason} -> {:error, reason}
      end
    rescue
      e ->
        {:error, {:parse_and_analyze_failed, Exception.message(e)}}
    end
  end

  @doc """
  Discovers all Elixir files in a project directory.
  Delegates to FileDiscovery for backward compatibility.
  """
  def discover_elixir_files(project_path, opts \\ []) do
    FileDiscovery.discover_elixir_files(project_path, opts)
  end

  # Utility functions

  defp count_total_functions(analyzed_modules) do
    analyzed_modules
    |> Map.values()
    |> Enum.map(fn module -> map_size(module.functions) end)
    |> Enum.sum()
  end
end
