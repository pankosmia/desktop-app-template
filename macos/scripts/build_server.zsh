#!/usr/bin/env zsh

# build_server.zsh
#
# Run from pankosmia/[this-repo's-name]/macos/scripts directory:
#   ./build_server.zsh [-s|-S] [-f|-F] [tier]
#   -s/-S  Pre-confirm the server is off, so as to not be asked.
#   -f/-F  Force a rebuild even if the build stamp shows the server is already built for this version.
#   tier   One of tiers.order in app_config.json (e.g. dev, qa, main). Only one may be given. Default is tiers.default.
# Requires: jq
#
# Server crate version comes from server.crate_version in app_config.json for the tier.
#   - All tiers: Cargo.toml and Cargo.lock are backed up, the crate line is rewritten, and both are
#     restored to their original state after the build (Cargo.lock is removed if it did not exist before).
# A build stamp (<server.bin>.stamp.json) is written after a successful build:
#   {"tier":"<tier>","crate":"<crate>","crate_version":"<version built>"}

set -e
set -u

echo

if ! command -v jq >/dev/null 2>&1; then
  echo
  echo "     jq is required to read app_config.json."
  echo
  exit 1
fi

APP_CONFIG="../../app_config.json"
localServerDir="../../local_server"
cargoFile="$localServerDir/Cargo.toml"
cargoLock="$localServerDir/Cargo.lock"
cargoBackup="$cargoFile.bak"
lockBackup="$cargoLock.bak"
cargoLockAbsent="$cargoLock.absent"

default_tier=$(jq -r '.tiers.default' "$APP_CONFIG")
tier_list=$(jq -r '.tiers.order | join(" ")' "$APP_CONFIG")

is_tier() {
  jq -e --arg t "$1" '.tiers.order | index($t) != null' "$APP_CONFIG" >/dev/null
}

# Prints the value of the single entry (in array $1) whose branches include the tier.
tier_value() {
  jq -er --arg t "$tier" "[$1[] | select(.branches | index(\$t))] | if length == 1 then .[0].value else empty end" "$APP_CONFIG"
}

# --- parse args ---
askIfOff=""
force=""
tier=""
while [ $# -gt 0 ]; do
  case "$1" in
    -s|-S) askIfOff=1 ;;
    -f|-F) force=1 ;;
    *)
      if is_tier "$1"; then
        if [ -n "$tier" ]; then
          echo "" >&2
          echo "     Only one tier may be given (got \"$tier\" and \"$1\"). Use one of: $tier_list" >&2
          echo "" >&2
          exit 1
        fi
        tier="$1"
      else
        echo "" >&2
        echo "     Unrecognized argument \"$1\". Use -s, -f, and/or one tier: $tier_list" >&2
        echo "" >&2
        exit 1
      fi
      ;;
  esac
  shift
done

# Default tier is tiers.default; must still be in tiers.order
tier=${tier:-$default_tier}
if ! is_tier "$tier"; then
  echo "" >&2
  echo "     Tier \"$tier\" is not listed in tiers.order. One of: $tier_list" >&2
  echo "" >&2
  exit 1
fi

# Server settings from app_config.json
crate=$(jq -r '.server.crate // empty' "$APP_CONFIG")
if [ -z "$crate" ]; then
  echo "" >&2
  echo "     server.crate is not set in app_config.json." >&2
  echo "" >&2
  exit 1
fi
crateVersion=$(tier_value '.server.crate_version') || {
  echo "" >&2
  echo "     .server.crate_version must have exactly one entry for tier \"$tier\" in app_config.json." >&2
  echo "" >&2
  exit 1
}
serverBin=$(tier_value '.server.bin') || {
  echo "" >&2
  echo "     .server.bin must have exactly one entry for tier \"$tier\" in app_config.json." >&2
  echo "" >&2
  exit 1
}
stampFile="$serverBin.stamp.json"

# Restores Cargo.toml and Cargo.lock to the state they were in before the build
restore_cargo() {
  if [ -f "$cargoBackup" ]; then mv -f "$cargoBackup" "$cargoFile"; fi
  if [ -f "$lockBackup" ]; then
    mv -f "$lockBackup" "$cargoLock"
  elif [ -f "$cargoLockAbsent" ]; then
    rm -f "$cargoLock"
  fi
  rm -f "$cargoLockAbsent"
}
trap restore_cargo EXIT

# Recover from an interrupted earlier run (e.g. Ctrl+C during cargo build)
if [ -f "$cargoBackup" ] || [ -f "$lockBackup" ] || [ -f "$cargoLockAbsent" ]; then
  echo "  WARNING: Found Cargo backup from an interrupted run. Restoring Cargo.toml and Cargo.lock first..."
  restore_cargo
fi

# Pin the crate line in Cargo.toml to the tier's version; the originals are backed up first
rewrite_cargo() {
  cp "$cargoFile" "$cargoBackup"
  if [ -f "$cargoLock" ]; then
    cp "$cargoLock" "$lockBackup"
  else
    touch "$cargoLockAbsent"
  fi
  sed -i '' "s|^${crate} *=.*|${crate} = \"=${crateVersion}\"|" "$cargoFile"
}

echo "  Tier is $tier"
echo "  Using $crate version $crateVersion for tier \"$tier\""
echo

# Do not ask if the server is off if the -s argument is provided
if [ -z "$askIfOff" ]; then
  while true; do
    read -r "yn?Is the server off? [Y/n]: "
    case "$yn" in
      ""|y|Y)
        echo
        break
        ;;
      n|N)
        echo
        echo "     Exiting..."
        echo
        echo "     If the server is on, turn it off (e.g., Ctrl-C in the terminal window or exit the app), then re-run this script."
        echo
        exit 1
        ;;
      *)
        echo
        echo "     \"$yn\" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit."
        echo
        ;;
    esac
  done
fi

# Skip the cargo build if the stamp shows this version is already built (unless -f)
needBuild=1
if [ -z "$force" ] && [ -f "$serverBin" ] && [ -f "$stampFile" ]; then
  stampVersion=$(jq -r '.crate_version // empty' "$stampFile" 2>/dev/null || true)
  if [ "$stampVersion" = "$crateVersion" ]; then
    echo "  Server is already built with $crate $crateVersion (per build stamp). Skipping cargo build. Use -f to force a rebuild."
    needBuild=0
  fi
fi

if [ "$needBuild" -eq 1 ]; then
  # Remove the stamp first so a failed build never leaves a stamp describing it
  rm -f "$stampFile"

  rewrite_cargo

  echo "Building local Release server at /local_server/target/release ..."
  echo "cargo build --release"
  if (cd "$localServerDir" && OPENSSL_STATIC=yes cargo build --release); then
    buildResult=0
  else
    buildResult=$?
  fi

  # Restore Cargo.toml and Cargo.lock to their original state (success or failure)
  restore_cargo

  if [ "$buildResult" -ne 0 ]; then
    echo
    echo "     Build failed with exit code $buildResult."
    echo
    exit "$buildResult"
  fi

  printf '{"tier":"%s","crate":"%s","crate_version":"%s"}\n' "$tier" "$crate" "$crateVersion" > "$stampFile"
  echo "  Wrote build stamp: $crate $crateVersion (tier $tier)"
fi

# Clean the build environment
if [ -d ../build ]; then
  echo "Removing last build environment..."
  echo
  rm -rf ../build
fi

# Assemble the build environment for the tier
echo "Assembling build environment for tier $tier..."
if ! node ./build.js "$tier"; then
  echo
  echo "     node build.js failed for tier \"$tier\"."
  echo
  exit 1
fi
