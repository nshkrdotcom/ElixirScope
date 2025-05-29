defmodule ElixirScope.ASTRepository.PatternMatcher.TypesTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.ASTRepository.PatternMatcher.Types
  
  describe "Types" do
    test "provides default confidence threshold" do
      assert Types.default_confidence_threshold() == 0.7
    end
    
    test "pattern_spec struct has expected fields" do
      spec = %Types{}
      
      assert Map.has_key?(spec, :pattern_type)
      assert Map.has_key?(spec, :pattern_ast)
      assert Map.has_key?(spec, :confidence_threshold)
      assert Map.has_key?(spec, :match_variables)
      assert Map.has_key?(spec, :context_sensitive)
      assert Map.has_key?(spec, :custom_rules)
      assert Map.has_key?(spec, :metadata)
    end
  end
end
