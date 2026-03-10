#!/usr/bin/env bash
# build.sh – Build the test project (and its dependencies) for coverage collection.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIGURATION="${1:-Release}"
TEST_PROJECT="$REPO_ROOT/test/OrchardCore.Tests/OrchardCore.Tests.csproj"

echo "=== OrchardCore: Build for Testing ==="
echo "Configuration : $CONFIGURATION"
echo "Test project  : $TEST_PROJECT"
echo ""

dotnet build "$TEST_PROJECT" -c "$CONFIGURATION" --verbosity quiet

echo ""
echo "=== Build succeeded ==="
