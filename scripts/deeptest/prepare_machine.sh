#!/usr/bin/env bash
# prepare_machine.sh – Install prerequisites for building and testing OrchardCore.
set -euo pipefail

DOTNET_SDK_VERSION="10.0"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "=== OrchardCore: Prepare Machine ==="

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

# Ensure global tools are on PATH
export PATH="$HOME/.dotnet/tools:$PATH"

# ---------- Restore NuGet packages ----------
echo "[+] Restoring NuGet packages ..."
dotnet restore "$REPO_ROOT/test/OrchardCore.Tests/OrchardCore.Tests.csproj" --verbosity quiet

echo ""
echo "=== Machine is ready ==="
