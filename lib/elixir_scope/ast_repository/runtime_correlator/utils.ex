defmodule ElixirScope.ASTRepository.RuntimeCorrelator.Utils do
  @moduledoc """
  Utility functions for the RuntimeCorrelator system.

  Contains common helper functions used across multiple RuntimeCorrelator
  modules for consistency and reusability.
  """

  @doc """
  Generates a unique identifier with a given prefix.
  """
  @spec generate_id(String.t()) :: String.t()
  def generate_id(prefix) do
    "#{prefix}_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  @doc """
  Generates a short unique identifier with a given prefix.
  """
  @spec generate_short_id(String.t()) :: String.t()
  def generate_short_id(prefix) do
    "#{prefix}_" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end

  @doc """
  Safely extracts a field from a map or returns a default value.
  """
  @spec safe_extract(map(), atom() | String.t(), any()) :: any()
  def safe_extract(map, key, default \\ nil) when is_map(map) do
    case Map.get(map, key) do
      nil -> Map.get(map, to_string(key), default)
      value -> value
    end
  end

  def safe_extract(_, _, default), do: default

  @doc """
  Validates that required fields are present in a map.
  """
  @spec validate_required_fields(map(), list(atom() | String.t())) :: :ok | {:error, {:missing_fields, list()}}
  def validate_required_fields(map, required_fields) when is_map(map) do
    missing_fields = Enum.filter(required_fields, fn field ->
      is_nil(safe_extract(map, field))
    end)

    case missing_fields do
      [] -> :ok
      _ -> {:error, {:missing_fields, missing_fields}}
    end
  end

  def validate_required_fields(_, _), do: {:error, :invalid_input}

  @doc """
  Converts a module atom to a short name (last part after dots).
  """
  @spec module_to_short_name(atom()) :: String.t()
  def module_to_short_name(module) when is_atom(module) do
    case to_string(module) do
      "Elixir." <> rest ->
        rest |> String.split(".") |> List.last()
      module_str ->
        module_str |> String.split(".") |> List.last()
    end
  end

  def module_to_short_name(_), do: "Unknown"

  @doc """
  Safely converts a value to an integer with a default.
  """
  @spec safe_to_integer(any(), integer()) :: integer()
  def safe_to_integer(value, default \\ 0)
  def safe_to_integer(value, default) when is_integer(value), do: value
  def safe_to_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
  def safe_to_integer(_, default), do: default

  @doc """
  Calculates basic statistics for a list of numbers.
  """
  @spec calculate_stats(list(number())) :: map() | {:error, :empty_list}
  def calculate_stats([]), do: {:error, :empty_list}
  def calculate_stats(numbers) when is_list(numbers) do
    count = length(numbers)
    sum = Enum.sum(numbers)
    avg = sum / count
    min_val = Enum.min(numbers)
    max_val = Enum.max(numbers)

    # Calculate median
    sorted = Enum.sort(numbers)
    median = case rem(count, 2) do
      0 ->
        mid_idx = div(count, 2)
        (Enum.at(sorted, mid_idx - 1) + Enum.at(sorted, mid_idx)) / 2
      1 ->
        Enum.at(sorted, div(count, 2))
    end

    %{
      count: count,
      sum: sum,
      average: avg,
      minimum: min_val,
      maximum: max_val,
      median: median,
      range: max_val - min_val
    }
  end

  @doc """
  Merges two maps recursively, with the second map taking precedence.
  """
  @spec deep_merge(map(), map()) :: map()
  def deep_merge(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _key, val1, val2 ->
      if is_map(val1) and is_map(val2) do
        deep_merge(val1, val2)
      else
        val2
      end
    end)
  end

  def deep_merge(map1, map2) when is_map(map1), do: map2
  def deep_merge(_map1, map2) when is_map(map2), do: map2
  def deep_merge(_map1, _map2), do: %{}

  @doc """
  Formats a timestamp for human-readable display.
  """
  @spec format_timestamp(integer(), atom()) :: String.t()
  def format_timestamp(timestamp, unit \\ :nanosecond) do
    # Convert to microseconds for DateTime
    microseconds = case unit do
      :nanosecond -> div(timestamp, 1000)
      :microsecond -> timestamp
      :millisecond -> timestamp * 1000
      :second -> timestamp * 1_000_000
    end

    case DateTime.from_unix(microseconds, :microsecond) do
      {:ok, datetime} -> DateTime.to_iso8601(datetime)
      {:error, _} -> "Invalid timestamp"
    end
  end

  @doc """
  Truncates a string to a maximum length with ellipsis.
  """
  @spec truncate_string(String.t(), pos_integer()) :: String.t()
  def truncate_string(str, max_length) when is_binary(str) and max_length > 3 do
    if String.length(str) <= max_length do
      str
    else
      String.slice(str, 0, max_length - 3) <> "..."
    end
  end

  def truncate_string(str, _) when is_binary(str), do: str
  def truncate_string(_, _), do: ""

  @doc """
  Safely applies a function to a value, returning the original value on error.
  """
  @spec safe_apply(any(), (any() -> any())) :: any()
  def safe_apply(value, func) when is_function(func, 1) do
    try do
      func.(value)
    rescue
      _ -> value
    catch
      _ -> value
    end
  end

  def safe_apply(value, _), do: value

  @doc """
  Groups items by a key function and applies an aggregation function.
  """
  @spec group_and_aggregate(list(), (any() -> any()), (list() -> any())) :: map()
  def group_and_aggregate(items, key_func, agg_func) when is_list(items) do
    items
    |> Enum.group_by(key_func)
    |> Enum.map(fn {key, values} -> {key, agg_func.(values)} end)
    |> Enum.into(%{})
  end

  def group_and_aggregate(_, _, _), do: %{}

  @doc """
  Filters a map by key patterns.
  """
  @spec filter_map_by_keys(map(), (any() -> boolean())) :: map()
  def filter_map_by_keys(map, key_filter) when is_map(map) and is_function(key_filter, 1) do
    map
    |> Enum.filter(fn {key, _value} -> key_filter.(key) end)
    |> Enum.into(%{})
  end

  def filter_map_by_keys(map, _) when is_map(map), do: map
  def filter_map_by_keys(_, _), do: %{}
end
