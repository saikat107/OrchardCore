#!/usr/bin/env bash
# test.sh – Run a specific test class with code-coverage collection.
#
# Usage:
#   ./scripts/deeptest/test.sh <fully-qualified-class-name> [output-dir] [configuration]
#
# Examples:
#   ./scripts/deeptest/test.sh OrchardCore.Tests.Workflows.WorkflowManagerTests
#   ./scripts/deeptest/test.sh OrchardCore.Tests.Workflows.WorkflowManagerTests ./MyCoverage Debug
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <fully-qualified-class-name> [output-dir] [configuration]"
    echo ""
    echo "  fully-qualified-class-name  e.g. OrchardCore.Tests.Workflows.WorkflowManagerTests"
    echo "  output-dir                  directory for coverage output (default: ./TestResults)"
    echo "  configuration               Release or Debug (default: Release)"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_CLASS="${1:-OrchardCore.Tests.Workflows.WorkflowManagerTests}"
OUTPUT_DIR="${2:-$REPO_ROOT/TestResults}"
CONFIGURATION="${3:-Release}"
TEST_PROJECT="$REPO_ROOT/test/OrchardCore.Tests/OrchardCore.Tests.csproj"

# Ensure global tools are on PATH
export PATH="$HOME/.dotnet/tools:$PATH"

# Sanitise class name for use in file names (replace dots and plus signs)
SAFE_NAME="${TEST_CLASS//[.+]/_}"
COVERAGE_FILE="$OUTPUT_DIR/${SAFE_NAME}.cobertura.xml"

mkdir -p "$OUTPUT_DIR"

echo "=== OrchardCore: Test with Coverage ==="
echo "Test class    : $TEST_CLASS"
echo "Configuration : $CONFIGURATION"
echo "Coverage file : $COVERAGE_FILE"
echo ""

dotnet-coverage collect \
    --output "$COVERAGE_FILE" \
    --output-format cobertura \
    "dotnet test --project $TEST_PROJECT -c $CONFIGURATION --no-build --filter-class $TEST_CLASS"

echo ""
echo "=== Test run complete ==="
echo "Coverage report: $COVERAGE_FILE"
