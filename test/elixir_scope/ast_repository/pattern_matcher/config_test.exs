defmodule ElixirScope.ASTRepository.PatternMatcher.ConfigTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.ASTRepository.PatternMatcher.Config
  
  describe "Config" do
    test "provides default values when no config is set" do
      # Clear any existing config
      Application.delete_env(:elixir_scope, :pattern_matcher)
      
      assert Config.get(:pattern_match_timeout) == 500
      assert Config.get(:default_confidence_threshold) == 0.7
      assert Config.get(:enable_pattern_cache) == true
    end
    
    test "returns configured values when set" do
      Application.put_env(:elixir_scope, :pattern_matcher, 
        pattern_match_timeout: 1000
      )
      
      assert Config.get(:pattern_match_timeout) == 1000
      
      # Cleanup
      Application.delete_env(:elixir_scope, :pattern_matcher)
    end
    
    test "validates configuration correctly" do
      valid_config = %{
        pattern_match_timeout: 500,
        default_confidence_threshold: 0.8
      }
      
      assert :ok = Config.validate_config(valid_config)
      
      invalid_config = %{
        pattern_match_timeout: -1,
        default_confidence_threshold: 0.8
      }
      
      assert {:error, :invalid_timeout} = Config.validate_config(invalid_config)
    end
  end
end
