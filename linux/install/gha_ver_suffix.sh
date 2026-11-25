#!/usr/bin/env bash

set -e
set -u

# This file is used by GHA to send a version suffix argument.
# The suffix is appended to app.version in app_config.json for the selected tier.
# Usage: gha_ver_suffix.sh <suffix> [tier]
#   Tier: 2nd argument, else tiers.default.
# Note: Requires jq - preinstalled on GitHub linux runners;
#   otherwise for Ubuntu: sudo apt update
#                         sudo apt install jq


suffix="${1:-}"
if [ -z "$suffix" ]; then
    exit 0
fi

APP_CONFIG="../../app_config.json"
APP_CONFIG_TMP="../../app_config.json.tmp"

tier="${2:-}"
if [ -z "$tier" ]; then
    tier="$(jq -r '.tiers.default' "$APP_CONFIG")"
fi

echo
echo "  Using version suffix \"$suffix\" for tier \"$tier\""

if ! jq -e --arg t "$tier" \
    '[.app.version[] | select(.branches | index($t))] | length == 1' \
    "$APP_CONFIG" >/dev/null; then
    echo "  app.version must have exactly one entry for tier \"$tier\""
    exit 1
fi

if ! jq --arg t "$tier" --arg s "$suffix" \
    '(.app.version[] | select(.branches | index($t)) | .value) |= . + "-" + $s' \
    "$APP_CONFIG" > "$APP_CONFIG_TMP"; then
    rm -f "$APP_CONFIG_TMP"
    echo "  Failed to update app_config.json"
    exit 1
fi

mv -f "$APP_CONFIG_TMP" "$APP_CONFIG"
