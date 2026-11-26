#!/usr/bin/env zsh

# Run from pankosmia/[this-repo's-name]/macos/scripts directory by:  ./run.zsh
# Optional arguments:
#   -s (or -S)       Pre-confirm the server is off, so as to not be asked.
#   <tier>           One of tiers.order in app_config.json (e.g. dev, qa, main). Only one may be given.
#                    Default is <tiers.default>. Passed to `node build.js`.
#   All other arguments are forwarded to server.exe.
# Requires: jq

set -e
set -u

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

# Do not ask if the server is off if -s or -S is provided.
# Forward all other arguments to server.bin.
askIfOff=""
tier=""
serverArgs=()


while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -[sS])
      askIfOff="-s" # -s = "no"
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

# Assign default value if -s is not present
if [ -z ${askIfOff+x} ]; then # askIfOff is unset
  askIfOff=-yes
fi

if [ ! -f ../../local_server/target/release/local_server ]; then
  echo
  echo "      Exiting..."
  echo
  echo "      The local server does not exist. Run \`./build_server.zsh\`, then re-run this script."
  echo
  exit
fi

echo "tier=$tier"
echo "serverArgs: ${serverArgs[*]}"

# Do not ask if the server is off if the -s argument is provided
if ! [[ $askIfOff =~ ^(-s) ]]; then
  while true; do
    read "choice?Is the server off? [Y/n]: "
    case $choice in
      "y" | "Y" | "" ) echo
        echo "Continuing..."
        break
        ;;
      [nN] ) echo
        echo "     Exiting..."
        echo
        echo "If the server is on, turn it off (e.g., Ctrl-C in terminal window or exit app), then re-run this script."
        echo
        exit
        ;;
      * ) echo
        echo "     \"$choice\" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit."
        echo
        ;;
    esac
  done
fi

# set available port environment variable (exported as $ROCKET_PORT )
source ../buildResources/find_free_port.sh
echo "Serving on port $ROCKET_PORT..."
echo

if [ -d ../build ]; then
  echo "Removing last build environment..."
  echo
  rm -rf ../build
fi

if [ ! -d ../build ]; then
  echo "Assembling build environment for tier $tier..."
  if ! node ./build.js "$tier"; then
    echo "" >&2
    echo "     node build.js failed for tier \"$tier\"." >&2
    echo "" >&2
    exit 1
  fi
fi

cd ../build

echo
echo "Running with local server in release mode... When ready to stop this server, press Ctrl-C."
echo "       If Ctrl-Z (suspend) is used by accident, then run \`killall -9 \"server.bin\"\` or Force Quit from the Activity Monitor,"
echo "       or to resume run \`fg\` for the last suspended process, otherwise \`fg \"./run.zsh\"\`."
echo

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export APP_RESOURCES_DIR="$SCRIPT_DIR/lib/"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/bin/server.bin" "${serverArgs[@]}"
