#!/bin/bash

echo "🎬 ElixirScope Cinema Demo - Complete Showcase"
echo "=============================================="
echo ""

# Check if we're in the right directory
if [ ! -f "mix.exs" ]; then
    echo "❌ Error: Please run this script from the test_apps/cinema_demo directory"
    echo "   cd test_apps/cinema_demo && ./run_showcase.sh"
    exit 1
fi

echo "📦 Installing dependencies..."
mix deps.get

echo ""
echo "🔨 Compiling application..."
mix compile

echo ""
echo "🎬 Running complete Cinema Demo showcase..."
echo "   This will demonstrate all ElixirScope features"
echo "   Expected runtime: ~1 minute"
echo ""

mix run showcase_script.exs

echo ""
echo "✅ Showcase completed!"
echo ""
echo "📖 For more details, see:"
echo "   - FULLY_BLOWN.md - Complete feature documentation"
echo "   - README.md - Application overview"
echo "   - showcase_script.exs - The demo script source" 