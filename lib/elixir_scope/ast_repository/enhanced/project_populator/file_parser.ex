defmodule ElixirScope.ASTRepository.Enhanced.ProjectPopulator.FileParser do
  @moduledoc """
  Handles parsing of Elixir files into AST format.

  Provides functionality to:
  - Parse single files with validation
  - Parse multiple files with parallel processing
  - Extract module names and metadata
  """

  require Logger

  alias ElixirScope.ASTRepository.Enhanced.ProjectPopulator.ASTExtractor

  @doc """
  Parses AST from discovered files.
  """
  def parse_files(files, opts \\ []) do
    parallel = Keyword.get(opts, :parallel_processing, true)
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    validate_syntax = Keyword.get(opts, :validate_syntax, true)
    timeout = Keyword.get(opts, :timeout, 30_000)

    parse_function = fn file ->
      parse_single_file(file, validate_syntax, timeout)
    end

    try do
      parsed_files = if parallel do
        files
        |> Task.async_stream(parse_function,
           max_concurrency: max_concurrency,
           timeout: timeout,
           on_timeout: :kill_task)
        |> Enum.reduce([], fn
          {:ok, {:ok, parsed_file}}, acc -> [parsed_file | acc]
          {:ok, {:error, reason}}, acc ->
            Logger.warning("Failed to parse file: #{inspect(reason)}")
            acc
          {:exit, reason}, acc ->
            Logger.warning("File parsing timed out: #{inspect(reason)}")
            acc
        end)
        |> Enum.reverse()
      else
        Enum.reduce(files, [], fn file, acc ->
          case parse_function.(file) do
            {:ok, parsed_file} -> [parsed_file | acc]
            {:error, reason} ->
              Logger.warning("Failed to parse #{file}: #{inspect(reason)}")
              acc
          end
        end)
        |> Enum.reverse()
      end

      Logger.debug("Successfully parsed #{length(parsed_files)} files")
      {:ok, parsed_files}
    rescue
      e ->
        {:error, {:file_parsing_failed, Exception.message(e)}}
    end
  end

  @doc """
  Parses a single file into AST format.
  """
  def parse_single_file(file_path, validate_syntax, _timeout) do
    start_time = System.monotonic_time(:microsecond)

    try do
      case File.read(file_path) do
        {:ok, content} ->
          case Code.string_to_quoted(content, file: file_path) do
            {:ok, ast} ->
              if validate_syntax do
                case validate_ast_syntax(ast) do
                  :ok ->
                    end_time = System.monotonic_time(:microsecond)
                    parsed_file = %{
                      file_path: file_path,
                      content: content,
                      ast: ast,
                      module_name: ASTExtractor.extract_module_name(ast),
                      parse_time: end_time - start_time,
                      file_size: byte_size(content),
                      line_count: count_lines(content)
                    }
                    {:ok, parsed_file}

                  {:error, reason} ->
                    {:error, {:syntax_validation_failed, file_path, reason}}
                end
              else
                end_time = System.monotonic_time(:microsecond)
                parsed_file = %{
                  file_path: file_path,
                  content: content,
                  ast: ast,
                  module_name: ASTExtractor.extract_module_name(ast),
                  parse_time: end_time - start_time,
                  file_size: byte_size(content),
                  line_count: count_lines(content)
                }
                {:ok, parsed_file}
              end

            {:error, reason} ->
              {:error, {:ast_parsing_failed, file_path, reason}}
          end

        {:error, reason} ->
          {:error, {:file_read_failed, file_path, reason}}
      end
    rescue
      e ->
        {:error, {:file_processing_crashed, file_path, Exception.message(e)}}
    end
  end

  # Private functions

  defp validate_ast_syntax(ast) do
    # Basic AST validation
    case ast do
      nil -> {:error, :nil_ast}
      {:__block__, _, []} -> {:error, :empty_block}
      _ -> :ok
    end
  end

  defp count_lines(content) do
    content
    |> String.split("\n")
    |> length()
  end
end
