# ==============================================================================
# Attribute Extraction Component
# ==============================================================================

defmodule ElixirScope.ASTRepository.ModuleData.AttributeExtractor do
  @moduledoc """
  Extracts module attributes from AST structures.
  """

  @doc """
  Extracts all module attributes from the AST.
  """
  @spec extract_attributes(term()) :: [map()]
  def extract_attributes(ast) do
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        extract_attribute_statements(body)
      _ ->
        []
    end
  end

  # Private implementation
  defp extract_attribute_statements({:__block__, _, statements}) do
    statements
    |> Enum.filter(&is_attribute_statement?/1)
    |> Enum.map(&extract_attribute_info/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_attribute_statements(statement) do
    if is_attribute_statement?(statement) do
      case extract_attribute_info(statement) do
        nil -> []
        attribute -> [attribute]
      end
    else
      []
    end
  end

  defp is_attribute_statement?({:@, _, [{name, _, _}]}) when is_atom(name) do
    true
  end

  defp is_attribute_statement?(_), do: false

  defp extract_attribute_info({:@, _, [{name, _, [value]}]}) do
    %{
      name: name,
      value: value,
      type: determine_attribute_type(name)
    }
  end

  defp extract_attribute_info({:@, _, [{name, _, _}]}) do
    %{
      name: name,
      value: nil,
      type: determine_attribute_type(name)
    }
  end

  defp extract_attribute_info(_), do: nil

  defp determine_attribute_type(name) do
    case name do
      :moduledoc -> :documentation
      :doc -> :documentation
      :behaviour -> :behaviour
      :behavior -> :behaviour
      :impl -> :implementation
      :spec -> :typespec
      :type -> :typespec
      :typep -> :typespec
      :opaque -> :typespec
      :callback -> :callback
      :macrocallback -> :callback
      :optional_callbacks -> :callback
      :derive -> :protocol
      :protocol -> :protocol
      :fallback_to_any -> :protocol
      _ -> :custom
    end
  end
end
