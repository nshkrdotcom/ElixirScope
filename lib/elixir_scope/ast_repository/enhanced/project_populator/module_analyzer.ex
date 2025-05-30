defmodule ElixirScope.ASTRepository.Enhanced.ProjectPopulator.ModuleAnalyzer do
  @moduledoc """
  Analyzes parsed modules and generates enhanced module data.

  Provides functionality to:
  - Analyze modules with CFG/DFG/CPG generation
  - Calculate complexity and quality metrics
  - Perform security analysis
  - Generate optimization hints
  """

  require Logger

  alias ElixirScope.ASTRepository.Enhanced.{
    EnhancedModuleData,
    EnhancedFunctionData,
    CFGGenerator,
    DFGGenerator,
    CPGBuilder
  }

  alias ElixirScope.ASTRepository.Enhanced.ProjectPopulator.{
    ASTExtractor,
    ComplexityAnalyzer,
    QualityAnalyzer,
    SecurityAnalyzer,
    OptimizationHints
  }

  @doc """
  Analyzes parsed modules with enhanced analysis.
  """
  def analyze_modules(parsed_files, opts \\ []) do
    generate_cfg = Keyword.get(opts, :generate_cfg, true)
    generate_dfg = Keyword.get(opts, :generate_dfg, true)
    generate_cpg = Keyword.get(opts, :generate_cpg, false)
    parallel = Keyword.get(opts, :parallel_processing, true)
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    timeout = Keyword.get(opts, :timeout, 30_000)

    analysis_function = fn parsed_file ->
      analyze_single_module(parsed_file, generate_cfg, generate_dfg, generate_cpg, timeout)
    end

    try do
      analyzed_modules = if parallel do
        parsed_files
        |> Task.async_stream(analysis_function,
           max_concurrency: max_concurrency,
           timeout: timeout,
           on_timeout: :kill_task)
        |> Enum.reduce(%{}, fn
          {:ok, {:ok, {module_name, module_data}}}, acc -> Map.put(acc, module_name, module_data)
          {:ok, {:error, reason}}, acc ->
            Logger.warning("Failed to analyze module: #{inspect(reason)}")
            acc
          {:exit, reason}, acc ->
            Logger.warning("Module analysis timed out: #{inspect(reason)}")
            acc
        end)
      else
        Enum.reduce(parsed_files, %{}, fn parsed_file, acc ->
          case analysis_function.(parsed_file) do
            {:ok, {module_name, module_data}} -> Map.put(acc, module_name, module_data)
            {:error, reason} ->
              Logger.warning("Failed to analyze #{parsed_file.file_path}: #{inspect(reason)}")
              acc
          end
        end)
      end

      Logger.debug("Successfully analyzed #{map_size(analyzed_modules)} modules")
      {:ok, analyzed_modules}
    rescue
      e ->
        {:error, {:module_analysis_failed, Exception.message(e)}}
    end
  end

  @doc """
  Analyzes a single module.
  """
  def analyze_single_module(parsed_file, generate_cfg, generate_dfg, generate_cpg, _timeout) do
    start_time = System.monotonic_time(:microsecond)

    try do
      module_name = parsed_file.module_name

      if module_name do
        # Extract functions from module
        functions = ASTExtractor.extract_functions_from_module(parsed_file.ast)

        # Analyze each function
        analyzed_functions = Enum.reduce(functions, %{}, fn {func_name, arity, func_ast}, acc ->
          case analyze_single_function(module_name, func_name, arity, func_ast,
                                     generate_cfg, generate_dfg, generate_cpg) do
            {:ok, function_data} ->
              Map.put(acc, {func_name, arity}, function_data)

            {:error, reason} ->
              Logger.warning("Failed to analyze function #{module_name}.#{func_name}/#{arity}: #{inspect(reason)}")
              acc
          end
        end)

        # Create enhanced module data
        enhanced_module = %EnhancedModuleData{
          module_name: module_name,
          file_path: parsed_file.file_path,
          ast: parsed_file.ast,
          functions: analyzed_functions,
          dependencies: ASTExtractor.extract_module_dependencies(parsed_file.ast),
          exports: ASTExtractor.extract_module_exports(parsed_file.ast),
          attributes: ASTExtractor.extract_module_attributes(parsed_file.ast),
          complexity_metrics: ComplexityAnalyzer.calculate_module_complexity_metrics(parsed_file.ast, analyzed_functions),
          quality_metrics: QualityAnalyzer.calculate_module_quality_metrics(parsed_file.ast, analyzed_functions),
          security_analysis: SecurityAnalyzer.perform_module_security_analysis(parsed_file.ast, analyzed_functions),
          performance_hints: OptimizationHints.generate_module_performance_hints(parsed_file.ast, analyzed_functions),
          file_size: parsed_file.file_size,
          line_count: parsed_file.line_count,
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }

        end_time = System.monotonic_time(:microsecond)
        Logger.debug("Analyzed module #{module_name} in #{(end_time - start_time) / 1000}ms")

        {:ok, {module_name, enhanced_module}}
      else
        {:error, {:no_module_found, parsed_file.file_path}}
      end
    rescue
      e ->
        {:error, {:module_analysis_crashed, parsed_file.file_path, Exception.message(e)}}
    end
  end

  # Private functions

  defp analyze_single_function(module_name, func_name, arity, func_ast, generate_cfg, generate_dfg, generate_cpg) do
    try do
      # Generate CFG if requested
      cfg_data = if generate_cfg do
        case CFGGenerator.generate_cfg(func_ast) do
          {:ok, cfg} -> cfg
          {:error, reason} ->
            Logger.warning("CFG generation failed for #{func_name}/#{arity}: #{inspect(reason)}")
            nil
        end
      else
        nil
      end

      # Generate DFG if requested
      dfg_data = if generate_dfg do
        case DFGGenerator.generate_dfg(func_ast) do
          {:ok, dfg} -> dfg
          {:error, reason} ->
            Logger.warning("DFG generation failed for #{func_name}/#{arity}: #{inspect(reason)}")
            nil
        end
      else
        nil
      end

      # Generate CPG if requested
      cpg_data = if generate_cpg do
        case CPGBuilder.build_cpg(func_ast) do
          {:ok, cpg} -> cpg
          {:error, reason} ->
            Logger.warning("CPG generation failed for #{func_name}/#{arity}: #{inspect(reason)}")
            nil
        end
      else
        nil
      end

      # Create enhanced function data
      enhanced_function = %EnhancedFunctionData{
        module_name: module_name,
        function_name: func_name,
        arity: arity,
        ast: func_ast,
        cfg_data: cfg_data,
        dfg_data: dfg_data,
        cpg_data: cpg_data,
        complexity_metrics: ComplexityAnalyzer.calculate_function_complexity_metrics(func_ast, cfg_data, dfg_data),
        performance_analysis: ComplexityAnalyzer.analyze_function_performance_characteristics(func_ast, cfg_data, dfg_data),
        security_analysis: SecurityAnalyzer.analyze_function_security_characteristics(func_ast, cpg_data),
        optimization_hints: OptimizationHints.generate_function_optimization_hints(func_ast, cfg_data, dfg_data),
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, enhanced_function}
    rescue
      e ->
        Logger.error("Function analysis crashed for #{func_name}/#{arity}: #{Exception.message(e)}")
        {:error, {:function_analysis_crashed, Exception.message(e)}}
    end
  end
end
