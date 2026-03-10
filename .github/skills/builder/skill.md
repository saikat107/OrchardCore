# Skill: C# Test & Coverage Builder

Build, test, and collect code coverage for any C# / .NET project. Produces three shell scripts (`prepare_machine.sh`, `build.sh`, `test.sh`) inside a designated scripts folder, then verifies them end-to-end.

## When to Use

Use this skill when the user needs to:
- Set up a C# repository for testing with coverage
- Create reusable scripts for building and running tests with coverage collection
- Run a specific test class with Cobertura coverage output

## Prerequisites

- A Linux or macOS environment with `bash`
- Internet access (for installing .NET SDK and tools on first run)

## Workflow

### Step 1 — Discover Project Configuration

Before generating any scripts, explore the repository to collect these facts:

1. **SDK version**: Read `global.json` for the `sdk.version` field (e.g. `"8.0.100"`, `"9.0.100"`, `"10.0.100"`). Extract the major version number (e.g. `8.0`, `9.0`, `10.0`).
2. **Test runner**: Check `global.json` for `"test": { "runner": "Microsoft.Testing.Platform" }`. If present, the project uses the new Microsoft Testing Platform (MTP); otherwise it uses VSTest.
3. **Test projects**: Find all `*.csproj` files under the `test/` directory. Identify the primary test project(s) — those that reference xUnit/NUnit/MSTest and contain actual test classes (not sample modules or themes).
4. **Coverage tooling**: Search `Directory.Packages.props` and test `.csproj` files for `coverlet.collector`, `coverlet.msbuild`, or `Microsoft.Testing.Extensions.CodeCoverage`. Note what is already present.
5. **Test filter syntax**: Determine filter flags based on the test runner:
   - **MTP (xUnit v3)**: Uses `--filter-class <fully-qualified-class>` and `--filter-method <fully-qualified-method>`.
   - **VSTest (xUnit v2, NUnit, MSTest)**: Uses `--filter "FullyQualifiedName~<class>"`.
6. **Target framework**: Check `Directory.Build.props` or the test `.csproj` for `<TargetFramework>` (e.g. `net8.0`, `net9.0`, `net10.0`).

### Step 2 — Generate `scripts/deeptest/prepare_machine.sh`

This script installs all prerequisites. Generate it using the discovered values.

```bash
#!/usr/bin/env bash
# prepare_machine.sh – Install prerequisites for building and testing.
set -euo pipefail

DOTNET_SDK_VERSION="<MAJOR.MINOR>"  # e.g. "8.0", "10.0" — from global.json
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "=== Prepare Machine ==="

# ---------- .NET SDK ----------
if command -v dotnet &>/dev/null && dotnet --list-sdks 2>/dev/null | grep -q "^${DOTNET_SDK_VERSION}"; then
    echo "[✓] .NET SDK ${DOTNET_SDK_VERSION}.x already installed"
else
    echo "[+] Installing .NET SDK ${DOTNET_SDK_VERSION} ..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq dotnet-sdk-${DOTNET_SDK_VERSION}
    else
        echo "ERROR: Unsupported package manager. Install .NET SDK ${DOTNET_SDK_VERSION} manually."
        echo "       https://dotnet.microsoft.com/download"
        exit 1
    fi
fi

# ---------- dotnet-coverage global tool ----------
if dotnet tool list -g 2>/dev/null | grep -q "dotnet-coverage"; then
    echo "[✓] dotnet-coverage already installed"
else
    echo "[+] Installing dotnet-coverage global tool ..."
    dotnet tool install --global dotnet-coverage
fi

export PATH="$HOME/.dotnet/tools:$PATH"

# ---------- Restore NuGet packages ----------
echo "[+] Restoring NuGet packages ..."
dotnet restore "<RELATIVE_PATH_TO_TEST_PROJECT>" --verbosity quiet

echo ""
echo "=== Machine is ready ==="
```

**Substitutions:**
| Placeholder | Source |
|---|---|
| `<MAJOR.MINOR>` | Major.Minor from `global.json` `sdk.version` |
| `<RELATIVE_PATH_TO_TEST_PROJECT>` | Relative path from repo root to the primary test `.csproj` |

### Step 3 — Generate `scripts/deeptest/build.sh`

This script builds the test project (and all its dependencies) so tests can run with `--no-build`.

```bash
#!/usr/bin/env bash
# build.sh – Build the test project for coverage collection.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIGURATION="${1:-Release}"
TEST_PROJECT="$REPO_ROOT/<RELATIVE_PATH_TO_TEST_PROJECT>"

echo "=== Build for Testing ==="
echo "Configuration : $CONFIGURATION"
echo "Test project  : $TEST_PROJECT"
echo ""

dotnet build "$TEST_PROJECT" -c "$CONFIGURATION" --verbosity quiet

echo ""
echo "=== Build succeeded ==="
```

### Step 4 — Generate `scripts/deeptest/test.sh`

This script runs a specific test class with `dotnet-coverage` collecting Cobertura output.

The test filter flag varies by runner — use the value determined in Step 1.

```bash
#!/usr/bin/env bash
# test.sh – Run a specific test class with code-coverage collection.
#
# Usage:
#   ./scripts/deeptest/test.sh <fully-qualified-class-name> [output-dir] [configuration]
#
# Examples:
#   ./scripts/deeptest/test.sh MyApp.Tests.Services.FooServiceTests
#   ./scripts/deeptest/test.sh MyApp.Tests.Services.FooServiceTests ./MyCoverage Debug
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <fully-qualified-class-name> [output-dir] [configuration]"
    echo ""
    echo "  fully-qualified-class-name  e.g. MyApp.Tests.Services.FooServiceTests"
    echo "  output-dir                  directory for coverage output (default: ./TestResults)"
    echo "  configuration               Release or Debug (default: Release)"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_CLASS="$1"
OUTPUT_DIR="${2:-$REPO_ROOT/TestResults}"
CONFIGURATION="${3:-Release}"
TEST_PROJECT="$REPO_ROOT/<RELATIVE_PATH_TO_TEST_PROJECT>"

export PATH="$HOME/.dotnet/tools:$PATH"

# Sanitise class name for use in file names
SAFE_NAME="${TEST_CLASS//[.+]/_}"
COVERAGE_FILE="$OUTPUT_DIR/${SAFE_NAME}.cobertura.xml"

mkdir -p "$OUTPUT_DIR"

echo "=== Test with Coverage ==="
echo "Test class    : $TEST_CLASS"
echo "Configuration : $CONFIGURATION"
echo "Coverage file : $COVERAGE_FILE"
echo ""

dotnet-coverage collect \
    --output "$COVERAGE_FILE" \
    --output-format cobertura \
    "dotnet test --project $TEST_PROJECT -c $CONFIGURATION --no-build <FILTER_FLAG> $TEST_CLASS"

echo ""
echo "=== Test run complete ==="
echo "Coverage report: $COVERAGE_FILE"
```

**Substitutions:**
| Placeholder | Source |
|---|---|
| `<RELATIVE_PATH_TO_TEST_PROJECT>` | Relative path from repo root to the primary test `.csproj` |
| `<FILTER_FLAG>` | `--filter-class` for MTP/xUnit v3, or `--filter FullyQualifiedName~` for VSTest |

### Step 5 — Make Scripts Executable and Verify

After generating the three scripts:

```bash
chmod +x scripts/deeptest/*.sh
```

Then verify end-to-end by running them against a known test class:

```bash
# 1. Build
./scripts/deeptest/build.sh

# 2. Pick any test class from the project and run it
./scripts/deeptest/test.sh <SomeKnown.TestClass>
```

Confirm:
- Build exits 0 with no errors
- Test exits 0, reports test pass count
- A `.cobertura.xml` file is written to `TestResults/`
- The XML contains `<package>` elements with non-empty coverage data

## Key Decisions

| Decision | Rationale |
|---|---|
| Use `dotnet-coverage` global tool | Works with both VSTest and Microsoft Testing Platform (MTP). The older `--collect:"XPlat Code Coverage"` flag does not work with MTP. |
| Cobertura output format | Widely supported by CI systems, reporting tools, and IDEs. |
| `--no-build` in test.sh | Avoids redundant rebuilds; `build.sh` handles compilation separately. |
| Scripts assume `scripts/deeptest/` is two levels below repo root | `REPO_ROOT` is derived via `$(cd "$(dirname "$0")/../.." && pwd)`. Adjust if the scripts folder is nested differently. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `dotnet-coverage: command not found` | Run `prepare_machine.sh` or ensure `$HOME/.dotnet/tools` is on `PATH`. |
| `Zero tests ran` with exit code 5 | The filter didn't match any class. Verify the fully-qualified class name (namespace + class). |
| Empty `<packages />` in coverage XML | The test ran but coverage was not instrumented. Ensure `coverlet.collector` is referenced in the test project, or remove any conflicting `<EnableMicrosoftCodeCoverage>` settings. |
| Build fails with SDK not found | Run `prepare_machine.sh` or install the correct .NET SDK version from `global.json`. |
