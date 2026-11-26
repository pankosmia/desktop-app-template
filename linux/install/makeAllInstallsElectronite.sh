#!/usr/bin/env bash

# Synopsis:
#   makeAllInstallsElectronite.sh -t <tier> [-d] [-f]
#
# Description:
#   This script automates the build process for the application on linux,
#   creating installation packages for both Intel (x64) and ARM64 architectures.
#   It downloads the required Electron and zip releases, and processes them
#   into installable packages.
#
# Flag-style Arguments:
#   -t <tier> REQUIRED. Builds all of the given tier from app_config.json: dev, qa, or main. Fallback is <tiers.default>.
#   -d indicates generation of a development environment viewer (optional; unrelated to the dev tier)
#   -f indicates a full install including Electronite download/copy (optional)
#   Note - Electronite URLs come from electronite.url in app_config.json; architectures are hardcoded
#
# Requires: jq
#
# Return Values:
#   0 - Success, all architectures built successfully
#   1 - Error occurred during download or build process
#

# get arguments
devRun="no"
fullInstall=false
tier=""

while [ $# -gt 0 ]; do
    case "$1" in
        -d) devRun="-d" ;; # -d is a development environment viewer run
        -f) fullInstall=true ;;
        -t) tier="$2"
            shift
            ;;
    esac
    shift
done

# app_config.json at repo root (read before any cd)
APP_CONFIG="../../app_config.json"

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required to read app_config.json"
    exit 1
fi

if [ -z "$tier" ]; then
    tier=$(jq -r '.tiers.default' "$APP_CONFIG")
fi

# Tier is required. Default is <tiers.default>.
if ! jq -e --arg t "$tier" '.tiers.order | index($t)' "$APP_CONFIG" >/dev/null; then
    echo "Error: tier \"$tier\" is not listed in tiers.order in app_config.json"
    exit 1
fi

# Prints the value of the single entry (in array $1) whose branches include the tier.
# Optional $2 is a jq suffix applied to the value (e.g. '."linux-x64"').
tier_value() {
    jq -er --arg t "$tier" --arg k "$1" \
        "[$1[] | select(.branches | index(\$t))] | if length == 1 then .[0].value${2:-} else error(\$k + \" must have exactly one entry for tier \" + \$t) end" \
        "$APP_CONFIG"
}

# App values are read by makeInstallElectronite.sh itself (passed -t "$tier").
echo "TIER=$tier"

# Electronite download URLs (electronite.url)
ElectronArm64=$(tier_value '.electronite.url' '."linux-arm64"') || { echo "Error: electronite.url linux-arm64 not set for tier \"$tier\""; exit 1; }
ElectronX64=$(tier_value '.electronite.url' '."linux-x64"') || { echo "Error: electronite.url linux-x64 not set for tier \"$tier\""; exit 1; }

# Detect current CPU architecture
CPU_ARCH=$(uname -m)
if [ "$CPU_ARCH" = "x86_64" ]; then
    CPU_ARCH="x64"
elif [ "$CPU_ARCH" = "aarch64" ]; then
    CPU_ARCH="arm64"
else
    echo "Error: Unsupported CPU architecture: $CPU_ARCH, default to x64"
    CPU_ARCH="x64"
fi

# Loop through creating installs for both arm64 and x64
for ARCH in "x64" "arm64"; do
    # Skip if not running on native architecture
    if [ "$ARCH" != "$CPU_ARCH" ]; then
        echo "Skipping $ARCH build on $CPU_ARCH machine"
        continue
    fi

    echo "Architecture: $ARCH"

    downloadElectronUrl="$ElectronX64"
    expectedZip="*-x64-cli.zip"
    if [ "$ARCH" = "arm64" ]; then
        downloadElectronUrl="$ElectronArm64"
        expectedZip="*-arm64-cli.zip"
    fi

    cd ../install || exit 1  # required on local builds runs; no harm in gha
    if [ "$fullInstall" = true ]; then
        ./getElectronRelease.sh "$downloadElectronUrl" "$ARCH" "$devRun"

        if [ $? -ne 0 ]; then
            echo "Error: Failed to get Electron release files at $downloadElectronUrl"
            exit 1
        fi
    else
        echo "Skipping Electron download/release step (not needed)."
    fi

    if [[ $devRun =~ ^(-d) ]]; then
        pkgDir="viewer"
    else
        pkgDir="temp"
    fi

    if [ "$fullInstall" = true ]; then
        echo
        echo "     *****************************************"
        echo "     * Running makeInstallElectronite.sh...  *"
        echo "     * Wait for the prompt.                  *"
        echo "     *****************************************"
        echo
    fi

    if [ "$fullInstall" = true ]; then
        ./makeInstallElectronite.sh "$ARCH" "$devRun" -t "$tier" -f
    else
        ./makeInstallElectronite.sh "$ARCH" "$devRun" -t "$tier"
    fi
    buildStatus=$?

    if ! [[ $devRun =~ ^(-d) ]]; then
        echo "Files at ../../releases/linux/"
        ls -als "../../releases/linux/"
    fi

    if [ $buildStatus -ne 0 ]; then
        echo "Error: Build failed for architecture $ARCH"
        exit 1
    fi
done

echo "Build completed for $CPU_ARCH architecture"

# Remove temporary electronite files from local dev viewer build.
if [[ $devRun =~ ^(-d) ]]; then
    rm -rf "../$pkgDir/electron"
    rm -rf "../$pkgDir"/electron.*
    echo "Local Dev Electronite Viewer has been successfully built."
fi
