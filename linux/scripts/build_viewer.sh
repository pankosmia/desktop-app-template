#!/usr/bin/env bash

# Run from pankosmia\[this-repo's-name]\linux\scripts directory:
#  ./build_viewer.sh [tier] [-f|-F]
#
# Arguments (all optional):
#   tier    One of the values in tiers.order. Defaults to tiers.default.
#   -f/-F   Force a full install
#
# build_viewer.bsh is a symlink to build_viewer.sh

if ! command -v jq >/dev/null 2>&1; then
  echo
  echo "     jq is required to read app_config.json."
  echo
  exit 1
fi

echo

# app_config.json at repo root
APP_CONFIG="../../app_config.json"
default_tier=$(jq -r '.tiers.default' "$APP_CONFIG")
tier_list=$(jq -r '.tiers.order | join(" ")' "$APP_CONFIG")

tier=""
FORCE_FULL_INSTALL=false

while [[ "$#" -gt 0 ]]
  do case $1 in
    -[fF]) FORCE_FULL_INSTALL=true
    ;;
    *)
      if jq -e --arg t "$1" '.tiers.order | index($t) != null' "$APP_CONFIG" >/dev/null; then
        if [[ -n "$tier" ]]; then
          echo "" >&2
          echo "     Only one tier may be specified (got '$tier' and '$1'). One of: $tier_list" >&2
          echo "" >&2
          exit 1
        fi
        tier="$1"
      else
        serverArgs+=("$1")
      fi
      ;;
  esac
  shift
done

# Default tier is tiers.default; must still be in tiers.order
tier=${tier:-$default_tier}

if ! jq -e --arg t "$tier" '.tiers.order | index($t) != null' "$APP_CONFIG" >/dev/null; then
  echo "" >&2
  echo "     Tier \"$tier\" is not listed in tiers.order. One of: $tier_list" >&2
  echo "" >&2
  exit 1
fi

# Prints the value of the single entry (in array $1) whose branches include the tier.
tier_value() {
    jq -er --arg t "$tier" --arg k "$1" \
        "[$1[] | select(.branches | index(\$t))] | if length == 1 then .[0].value else error(\$k + \" must have exactly one entry for tier \" + \$t) end" \
        "$APP_CONFIG"
}

# Expected Electronite version, derived from electronite.url for this machine's arch
case "$(uname -m)" in
  aarch64|arm64) CPU_ARCH="arm64" ;;
  *)             CPU_ARCH="x64" ;;
esac
electron_urls=$(tier_value '.electronite.url') || { echo "Error: electronite.url not set for tier \"$tier\""; exit 1; }
electron_url=$(printf '%s' "$electron_urls" | jq -r --arg k "linux-$CPU_ARCH" '.[$k] // empty')
if [ -z "$electron_url" ]; then
  echo "Error: electronite.url has no 'linux-$CPU_ARCH' entry for tier \"$tier\"." >&2
  exit 1
fi
EXPECTED=$(printf '%s' "$electron_url" | sed -n 's/.*electronite-v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
if [ -z "$EXPECTED" ]; then
  echo "Error: Could not determine Electronite version from electronite.url: $electron_url" >&2
  exit 1
fi

ELECTRON_VER="../viewer/project/payload/app/electron/version"

# A full install will also install, or re-install, Electronite.
fullInstall=$FORCE_FULL_INSTALL

if [ "$fullInstall" != true ]; then
    if [ -f "$ELECTRON_VER" ]; then
        content="$(tr -d '\r\n' < "$ELECTRON_VER")"
        if [ "$content" = "$EXPECTED" ]; then
            echo "The installed viewer Electronite version is $content, which is correct. Use -f to force a full re-install."
            echo "No download is needed. Everything else will be updated."
            fullInstall=false
        else
            echo "The installed viewer Electronite version is $content, however we are not using $EXPECTED. Please wait for the download and upgrade that will follow..."
            fullInstall=true
        fi
    else
        echo "A full viewer install will follow, including download of Electronite. Please wait patiently..."
        fullInstall=true
    fi
else
    # -f flag detected.
    echo "A full viewer install will follow, including download of Electronite. Please wait patiently..."
fi

TEMP_DIR="../viewer"
if [ "$fullInstall" = true ] && [ -d "$TEMP_DIR" ]; then
    echo "Deleting previous viewer build..."
    rm -rf "$TEMP_DIR"
fi

if [ "$fullInstall" = true ]; then
    echo "********************************************************************"
    echo "\"Getting Electron release\" downloads an approximately 120 MB file."
    echo "Please wait patiently for the download process to complete..."
    echo "********************************************************************"
    ../install/makeAllInstallsElectronite.sh -d -f -t "$tier"
else
    ../install/makeAllInstallsElectronite.sh -d -t "$tier"
fi
