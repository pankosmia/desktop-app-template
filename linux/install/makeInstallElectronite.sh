#!/usr/bin/env bash

# linux Installation Package Builder Script
#
# Synopsis:
#   Creates a linux installation package (.pkg) for the application
#   based on provided architecture (arm64 or x64) and tier.
#
# Description:
#   This script automates the process of building a linux installer package by:
#   1. Creating the installation directory structure
#   2. Copying application files and resources
#   3. Setting up proper permissions
#   4. Configuring application metadata
#   5. Building the final installer package
#
# Requirements:
#   - app_config.json at the repo root (app.*, resources.rocket_config,
#     resources.electron_icon for the selected tier)
#   - jq
#   - Architecture parameter must be provided when running the script
#
# Parameters:
#   $1 : Architecture type (Required)
#        Accepted values: arm64, x64
#   $2 : -d indicates a development environment run (for building viewer only; unrelated to the dev tier)
#   -t <tier> REQUIRED. Builds all of the given tier from app_config.json: dev, qa, or main. Default is <tiers.default>.
#   -f indicates full install including Electronite copy/download setup
#
# Returns:
#   0 : Success
#   1 : Failure (Invalid/missing parameters or execution error)
#
# Output:
#   Creates installer package at: ../releases/linux/<app-name>_installer_<arch>_<version>.pkg

# This script's dir (/linux/install). Resolve before any cd.
# resources.* values in app_config.json are relative to /<os>/scripts (same depth).
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
APP_CONFIG="$SCRIPT_DIR/../../app_config.json"

# get arguments
arch="$1"
devRun="${2:-no}" # This is a development environment viewer run if $2 is -d
fullInstall=false
tier=""

while [ $# -gt 0 ]; do
    case "$1" in
        -f) fullInstall=true ;;
        -t) tier="$2"
            shift
            ;;
    esac
    shift
done

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
tier_value() {
    jq -er --arg t "$tier" --arg k "$1" \
        "[$1[] | select(.branches | index(\$t))] | if length == 1 then .[0].value else error(\$k + \" must have exactly one entry for tier \" + \$t) end" \
        "$APP_CONFIG"
}

# Prints resources.$1 resolved against this script's dir. Not resolved further, so wildcards are preserved.
res_path() {
    local resValue
    resValue=$(tier_value ".resources.$1") || return 1
    printf '%s\n' "$SCRIPT_DIR/$resValue"
}

APP_NAME=$(tier_value '.app.name') || { echo "Error: app.name not set for tier \"$tier\""; exit 1; }
APP_VERSION=$(tier_value '.app.version') || { echo "Error: app.version not set for tier \"$tier\""; exit 1; }

# Use lower case app name in filename, and replace spaces with a dash (-)
FILE_APP_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
FILE_APP_NAME=${FILE_APP_NAME// /-}

ROCKET_CONFIG=$(res_path rocket_config) || { echo "Error: resources.rocket_config not set for tier \"$tier\""; exit 1; }
ELECTRON_ICON=$(res_path electron_icon) || { echo "Error: resources.electron_icon not set for tier \"$tier\""; exit 1; }

echo "TIER=$tier"
echo "APP_NAME=$APP_NAME"
echo "APP_VERSION=$APP_VERSION"
echo "FILE_APP_NAME=$FILE_APP_NAME"

# Needed for local bundles. Not required in GHA but does no harm.
if ! [[ $devRun =~ ^(-d) ]]; then
    rm -f "../../releases/linux/${FILE_APP_NAME}"-*-linux-"${arch}".deb
fi

# cwd: /linux/install -> /linux/build
cd ../build || exit 1

if [[ $devRun =~ ^(-d) ]]; then
    pkgDir="viewer"
else
    pkgDir="temp"
fi

APP_BASE_DIR="../$pkgDir/project/payload/app"

if [ "$fullInstall" = true ] || ! [[ $devRun =~ ^(-d) ]]; then
    # Needed for local bundles. Not required in GHA but also doesn't hurt anything.
    rm -rf "../$pkgDir/project"
fi

mkdir -p "$APP_BASE_DIR"

# Rocket config (resources.rocket_config)
cp "$ROCKET_CONFIG" "${APP_BASE_DIR}/Rocket.toml"

# electron startup
LAUNCHER_NAME="start-${FILE_APP_NAME}.sh"
cp "../buildResources/devAppLauncherElectron.sh" "${APP_BASE_DIR}/${LAUNCHER_NAME}"
sed -i.bak "s/\${APP_NAME}/$APP_NAME/g" "${APP_BASE_DIR}/${LAUNCHER_NAME}"
#remove backup
rm "${APP_BASE_DIR}/${LAUNCHER_NAME}.bak"


# copy app-specific electron files
ELECTRON_DEST="${APP_BASE_DIR}/electron"
NODE_MODULES_SRC="../../node_modules"
NODE_MODULES_DEST="${ELECTRON_DEST}/node_modules"

cp -R "../../buildResources/electron/." "$ELECTRON_DEST/"
echo "Successfully copied app-specific electron files"

if [ ! -d "$ELECTRON_DEST" ]; then
    echo "Error: Electron destination path not found for app-specific electron files: $ELECTRON_DEST"
    exit 1
fi

# Electron icon (resources.electron_icon) -- dir quoted, filename unquoted so wildcards expand
cp "$(dirname "$ELECTRON_ICON")"/$(basename "$ELECTRON_ICON") "$ELECTRON_DEST"
echo "Copied $(basename "$ELECTRON_ICON") files"

ALL_OS_MODULES=(
    "puppeteer-core"
    "@puppeteer/browsers"
    "chromium-bidi"
    "debug"
    "devtools-protocol"
    "ms"
    "typed-query-selector"
    "webdriver-bidi-protocol"
    "ws"
    "semver"
    "proxy-agent"
    "lru-cache"
    "agent-base"
    "proxy-from-env"
    "progress"
    "mitt"
)

for mod in "${ALL_OS_MODULES[@]}"; do
    mkdir -p "${NODE_MODULES_DEST}/${mod}"
    cp -R "${NODE_MODULES_SRC}/${mod}/." "${NODE_MODULES_DEST}/${mod}/"
done

LINUX_MODULES=(
    "tar-fs"
    "tar-stream"
    "streamx"
    "events-universal"
    "fast-fifo"
    "text-decoder"
    "b4a"
    "pump"
    "once"
    "wrappy"
    "end-of-stream"
)

for mod in "${LINUX_MODULES[@]}"; do
    mkdir -p "${NODE_MODULES_DEST}/${mod}"
    cp -R "${NODE_MODULES_SRC}/${mod}/." "${NODE_MODULES_DEST}/${mod}/"
done

echo "Successfully copied node_modules dependencies"

# Replace all occurrences of ${APP_NAME} and ${APP_VERSION} in startup script
sed -i.bak "s/\${APP_NAME}/$APP_NAME/g" "${ELECTRON_DEST}/electronStartup.js"
sed -i.bak "s/\${APP_NAME}/$APP_NAME/g" "${ELECTRON_DEST}/package.json"
sed -i.bak "s/\${APP_VERSION}/$APP_VERSION/g" "${ELECTRON_DEST}/package.json"

if [ "$fullInstall" = true ]; then
    # now copy architecture specific electron files
    cp -R "../$pkgDir/electron.$arch/"* "${ELECTRON_DEST}/"
    echo "Successfully copied architecture-specific electron files"
else
    echo "Skipping architecture-specific electron file copy (not needed)."
fi

# Check if Electron executable owner is current user
ELECTRON_OWNER=$(stat --format='%u' "$ELECTRON_DEST")
CURRENT_USER=$(id -u)
if [ "$ELECTRON_OWNER" != "$CURRENT_USER" ]; then
    echo "Error: Electron executable owner is not current user. Please run: sudo chown -R $(id -u):$(id -g) ../buildResources/electron.$arch/*"
    exit 1
fi

if ! [[ $devRun =~ ^(-d) ]]; then
    cp -R "./bin" "${APP_BASE_DIR}/"
    echo "copied bin to $APP_BASE_DIR/"
    chmod 755 "${APP_BASE_DIR}/bin/server.bin"
    chmod 755 "${APP_BASE_DIR}/${LAUNCHER_NAME}"

    cp -R "./lib" "${APP_BASE_DIR}/"
    echo "copied lib to $APP_BASE_DIR/"
fi

# set execute permission on all folders
find "${APP_BASE_DIR}/" -type d -exec chmod u+x,g+x,o+x {} +
