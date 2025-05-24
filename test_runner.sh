#!/bin/bash

# ElixirScope Test Runner
# Prevents stdout/stderr pipe issues when running tests

echo "🧪 ElixirScope Test Runner"
echo "=========================="

# Function to run tests without pipe issues
run_tests() {
    if [ "$1" = "--summary" ]; then
        echo "Running tests with summary output..."
        mix test 2>&1 | grep -E "(test|failure|Finished|Running)" | tail -20
    elif [ "$1" = "--quick" ]; then
        echo "Running single-threaded tests..."
        mix test --max-cases 1 2>&1
    elif [ "$1" = "--specific" ]; then
        echo "Running specific test file: $2"
        mix test "$2" 2>&1
    else
        echo "Running all tests..."
        mix test 2>&1
    fi
}

# Parse command line arguments
case "$1" in
    --summary)
        run_tests --summary
        ;;
    --quick)
        run_tests --quick
        ;;
    --specific)
        if [ -z "$2" ]; then
            echo "Usage: $0 --specific <test_file>"
            exit 1
        fi
        run_tests --specific "$2"
        ;;
    --help)
        echo "Usage: $0 [--summary|--quick|--specific <file>|--help]"
        echo ""
        echo "Options:"
        echo "  --summary     Show test summary with key results"
        echo "  --quick       Run with max-cases 1 (sequential)"
        echo "  --specific    Run specific test file"
        echo "  --help        Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Run all tests"
        echo "  $0 --summary                         # Show summary"
        echo "  $0 --quick                           # Sequential execution"
        echo "  $0 --specific test/elixir_scope/config_test.exs"
        ;;
    *)
        run_tests
        ;;
esac 