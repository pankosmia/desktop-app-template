#!/usr/bin/env zsh

# This script uses APP_VERSION environment as defined in app_config.json
#
# Run from pankosmia/[this-repo's-name]/macos/scripts directory:
#  ./bundle_app.zsh  [tier] [-s|-S] [-p|-P]
#
# Arguments (all optional):
#   tier    One of the values in tiers.order. Defaults to tiers.default.
#   -s/-S   Skip the prompt when the server is off.
#   -p/-P indicates Portable App zip build (produces a .zip)
#
# bundle_viewer.zsh is a symlink to bundle_app.zsh

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

# get arguments
askIfOff=yes
portable=false
tier=""

while [[ "$#" -gt 0 ]]
  do case $1 in
    -[sS]) askIfOff=no
    ;;
    -[pP]) portable=true
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

# Do not ask if the server is off if the -s argument is provided
if [ $askIfOff = yes ]; then
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

TEMP_DIR=../temp
if [ -d $TEMP_DIR ]; then
    echo "Deleting previous build..."
    echo
    rm -rf $TEMP_DIR
fi

echo
echo "Bundling Zip for tier $tier..."
echo "  - updates the build environment for the Electronite package build,"
echo "  - and creates a zip bundle that parallels the Electronite package."
./bundle_zip.zsh -s $tier

echo
echo
echo "********************************************************************"
echo "\"Getting Electron release\" downloads an approximately 120 MB file."
echo "Please wait patiently for the download process to complete..."
echo "********************************************************************"
echo

args=(-f)
args+=(-t "$tier")
if [ "$portable" = true ]; then
    args+=(-p)
fi
../install/makeAllInstallsElectronite.sh "${args[@]}"
