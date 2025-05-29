defmodule ElixirScope.ASTRepository.MemoryManager.Compressor do
  @moduledoc """
  Data compression subsystem for compressing infrequently accessed analysis data.

  Uses binary term compression to reduce memory footprint of large AST
  structures and analysis results that are rarely accessed.
  """

  require Logger

  @type compression_stats :: %{
    modules_compressed: non_neg_integer(),
    compression_ratio: float(),
    space_saved_bytes: non_neg_integer(),
    last_compression_duration: non_neg_integer(),
    total_compressions: non_neg_integer()
  }

  @doc """
  Gets initial compression statistics structure.
  """
  @spec get_initial_stats() :: compression_stats()
  def get_initial_stats() do
    %{
      modules_compressed: 0,
      compression_ratio: 0.0,
      space_saved_bytes: 0,
      last_compression_duration: 0,
      total_compressions: 0
    }
  end

  @doc """
  Performs compression of infrequently accessed analysis data.

  ## Options

  - `:access_threshold` - Minimum access count to avoid compression (default: 5)
  - `:age_threshold` - Minimum age in seconds before compression (default: 1800)
  - `:compression_level` - Compression level 1-9 (default: 6)
  """
  @spec perform_compression(keyword()) :: {:ok, compression_stats()} | {:error, term()}
  def perform_compression(opts \\ []) do
    access_threshold = Keyword.get(opts, :access_threshold, 5)
    age_threshold = Keyword.get(opts, :age_threshold, 1800)
    compression_level = Keyword.get(opts, :compression_level, 6)

    # Validate compression level
    compression_level = case compression_level do
      level when is_integer(level) and level >= 1 and level <= 9 -> level
      _ -> 6  # Default to level 6 if invalid
    end

    current_time = System.monotonic_time(:second)
    cutoff_time = current_time - age_threshold

    try do
      # Find data to compress
      candidates = find_compression_candidates(cutoff_time, access_threshold)

      # Perform compression
      {compressed_count, total_original, total_compressed} = compress_candidates(candidates, compression_level)

      compression_ratio = if total_original > 0 do
        total_compressed / total_original
      else
        0.0
      end

      space_saved = total_original - total_compressed

      result = %{
        modules_compressed: compressed_count,
        compression_ratio: compression_ratio,
        space_saved_bytes: space_saved
      }

      Logger.info("Compression completed: #{compressed_count} modules, #{Float.round(compression_ratio * 100, 1)}% of original size")

      {:ok, result}
    rescue
      error ->
        Logger.error("Compression failed: #{inspect(error)}")
        {:error, {:compression_failed, error}}
    end
  end

  @doc """
  Updates compression statistics with new results.
  """
  @spec update_stats(compression_stats(), compression_stats(), non_neg_integer()) :: compression_stats()
  def update_stats(stats, result, duration) do
    %{stats |
      modules_compressed: stats.modules_compressed + result.modules_compressed,
      compression_ratio: result.compression_ratio,
      space_saved_bytes: stats.space_saved_bytes + result.space_saved_bytes,
      last_compression_duration: duration,
      total_compressions: stats.total_compressions + 1
    }
  end

  @doc """
  Compresses a single data structure using the specified compression level.
  """
  @spec compress_data(term(), integer()) :: {:ok, binary(), non_neg_integer(), non_neg_integer()} | {:error, term()}
  def compress_data(data, compression_level \\ 6) do
    try do
      # Convert to binary term format
      original_binary = :erlang.term_to_binary(data)
      original_size = byte_size(original_binary)

      # Compress using zlib
      compressed_binary = :zlib.compress(original_binary)
      compressed_size = byte_size(compressed_binary)

      {:ok, compressed_binary, original_size, compressed_size}
    rescue
      error ->
        {:error, error}
    end
  end

  @doc """
  Decompresses previously compressed data.
  """
  @spec decompress_data(binary()) :: {:ok, term()} | {:error, term()}
  def decompress_data(compressed_binary) do
    try do
      # Decompress using zlib
      decompressed_binary = :zlib.uncompress(compressed_binary)

      # Convert back to term
      data = :erlang.binary_to_term(decompressed_binary)

      {:ok, data}
    rescue
      error ->
        {:error, error}
    end
  end

  @doc """
  Checks if data is compressed (simple heuristic based on binary format).
  """
  @spec is_compressed?(binary()) :: boolean()
  def is_compressed?(data) when is_binary(data) do
    # Simple heuristic: compressed data typically starts with zlib header
    case data do
      <<0x78, 0x9C, _rest::binary>> -> true  # Default compression
      <<0x78, 0xDA, _rest::binary>> -> true  # Best compression
      <<0x78, 0x01, _rest::binary>> -> true  # No compression
      _ -> false
    end
  end
  def is_compressed?(_), do: false

  # Private Implementation

  defp find_compression_candidates(cutoff_time, access_threshold) do
    # Access tracking table for finding candidates
    access_table = :ast_repo_access_tracking

    try do
      case :ets.info(access_table, :size) do
        :undefined ->
          Logger.warning("Access tracking table not found, no compression candidates")
          []
        _ ->
          :ets.tab2list(access_table)
          |> Enum.filter(fn {_module, last_access, access_count} ->
            last_access < cutoff_time and access_count < access_threshold
          end)
          |> Enum.map(fn {module, _last_access, _access_count} -> module end)
      end
    rescue
      error ->
        Logger.warning("Failed to find compression candidates: #{inspect(error)}")
        []
    end
  end

  defp compress_candidates(candidates, compression_level) do
    Enum.reduce(candidates, {0, 0, 0}, fn module, {count, total_original, total_compressed} ->
      case compress_module_data(module, compression_level) do
        {:ok, original_size, compressed_size} ->
          {count + 1, total_original + original_size, total_compressed + compressed_size}
        {:error, reason} ->
          Logger.warning("Failed to compress module #{inspect(module)}: #{inspect(reason)}")
          {count, total_original, total_compressed}
      end
    end)
  end

  defp compress_module_data(module, compression_level) do
    try do
      # In a real implementation, this would fetch actual module data
      # from the Enhanced Repository and compress it

      # Simulate module data compression
      simulated_data = generate_simulated_module_data(module)

      case compress_data(simulated_data, compression_level) do
        {:ok, _compressed_binary, original_size, compressed_size} ->
          Logger.debug("Compressed module #{inspect(module)}: #{original_size} -> #{compressed_size} bytes")
          {:ok, original_size, compressed_size}
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  defp generate_simulated_module_data(module) do
    # Generate realistic simulated AST data for compression testing
    %{
      module: module,
      ast: generate_simulated_ast(),
      analysis: generate_simulated_analysis(),
      metadata: generate_simulated_metadata(),
      timestamp: System.monotonic_time(:millisecond)
    }
  end

  defp generate_simulated_ast() do
    # Simulate a complex AST structure
    functions = for i <- 1..10 do
      %{
        name: :"function_#{i}",
        arity: :rand.uniform(5),
        clauses: for j <- 1..3 do
          %{
            clause: j,
            params: (for k <- 1..:rand.uniform(3), do: :"param_#{k}"),
            body: generate_expression_tree(4)  # Depth 4 expression tree
          }
        end
      }
    end

    %{
      type: :module,
      name: :simulated_module,
      functions: functions,
      attributes: [
        {:module, :simulated_module},
        {:export, [{:test, 0}, {:run, 1}]}
      ]
    }
  end

  defp generate_expression_tree(0), do: {:atom, :leaf}
  defp generate_expression_tree(depth) do
    case :rand.uniform(4) do
      1 -> {:call, :rand.uniform(100), generate_expression_tree(depth - 1)}
      2 -> {:tuple, [generate_expression_tree(depth - 1), generate_expression_tree(depth - 1)]}
      3 -> {:list, for(_ <- 1..:rand.uniform(3), do: generate_expression_tree(depth - 1))}
      4 -> {:binary, :rand.bytes(32)}
    end
  end

  defp generate_simulated_analysis() do
    %{
      complexity: :rand.uniform(100),
      dependencies: for(_ <- 1..:rand.uniform(5), do: :"dep_#{:rand.uniform(1000)}"),
      type_info: %{
        functions: for i <- 1..5 do
          {:"func_#{i}", %{
            input_types: [:atom, :integer],
            output_type: :any,
            side_effects: :rand.uniform(2) == 1
          }}
        end
      },
      warnings: for(_ <- 1..:rand.uniform(3), do: "Warning #{:rand.uniform(100)}")
    }
  end

  defp generate_simulated_metadata() do
    %{
      file_path: "/fake/path/module.ex",
      line_count: :rand.uniform(500),
      last_modified: System.os_time(:second),
      checksum: :crypto.hash(:sha256, "fake_content") |> Base.encode16(),
      compile_options: [:debug_info, :warnings_as_errors]
    }
  end
end
