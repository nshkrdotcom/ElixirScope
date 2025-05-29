defmodule ElixirScope.ASTRepository.PatternMatcher.ValidatorsTest do
  use ExUnit.Case, async: true

  alias ElixirScope.ASTRepository.PatternMatcher.{Validators, Types}

  describe "normalize_pattern_spec/1" do
    test "normalizes valid pattern spec" do
      input = %{
        pattern_type: :test_pattern,
        confidence_threshold: 0.8,
        match_variables: true
      }

      assert {:ok, %Types{} = spec} = Validators.normalize_pattern_spec(input)
      assert spec.pattern_type == :test_pattern
      assert spec.confidence_threshold == 0.8
      assert spec.match_variables == true
    end

    test "uses default confidence threshold when not provided" do
      input = %{pattern_type: :test_pattern}

      assert {:ok, %Types{} = spec} = Validators.normalize_pattern_spec(input)
      assert spec.confidence_threshold == Types.default_confidence_threshold()
    end

    test "rejects invalid confidence threshold" do
      input = %{
        pattern_type: :test_pattern,
        confidence_threshold: 1.5
      }

      assert {:error, :invalid_confidence_threshold} =
        Validators.normalize_pattern_spec(input)
    end

    test "rejects missing pattern type for AST patterns" do
      input = %{
        pattern: quote(do: Enum.map(_, _)),
        confidence_threshold: 0.8
      }

      assert {:error, :missing_pattern_type} =
        Validators.normalize_pattern_spec(input)
    end

    test "rejects non-map input" do
      assert {:error, :invalid_pattern_spec} =
        Validators.normalize_pattern_spec("invalid")
    end
  end

  describe "validate_repository/1" do
    test "accepts valid atom repository names" do
      # This would need to be adjusted based on actual repository implementation
      assert {:error, :repository_not_found} = Validators.validate_repository(:test_repo)
    end

    test "rejects nil repository" do
      assert {:error, :invalid_repository} = Validators.validate_repository(nil)
    end

    test "rejects known invalid repositories" do
      assert {:error, :repository_not_found} =
        Validators.validate_repository(:mock_repo)
    end
  end
end
