#!/usr/bin/env zsh

# This script uses APP_NAME as defined in app_config.json
#
# Run from pankosmia/[this-repo's-name]/windows/scripts directory in a terminal with:  ./viewer.zsh
# ./build_viewer.zsh must be run once before ./viewer.zsh will work

# Use the first numeric argument as the port; default to 19119
ROCKET_PORT=19119
for arg in "$@"; do
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    ROCKET_PORT="$arg"
    break
  fi
done
export ROCKET_PORT

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

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    [0-9]*)
      # Numeric argument is the port, already handled above
      if [[ ! "$1" =~ ^[0-9]+$ ]]; then
        serverArgs+=("$1")
      fi
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

APP_NAME=$(tier_value '.app.name') || { echo "Error: app.name not set for tier \"$tier\""; exit 1; }

echo "Starting the Electronite viewer using tier ${tier} app.name --  ${APP_NAME} -- in the viewer starting path."
echo "Accessing the backend server at port ${ROCKET_PORT}."

# Using development environment server.
export START_SERVER="false"

# Starting electronite viewer, accessing the development build environment

# This bypasses ../viewer/start-*.sh (which, fyi, originates from ../buildResources/appLauncherElectron.sh)
../viewer/project/payload/${APP_NAME}.app/Contents/electron/Electron/Contents/MacOS/Electron ../viewer/project/payload/${APP_NAME}.app/Contents/electron
