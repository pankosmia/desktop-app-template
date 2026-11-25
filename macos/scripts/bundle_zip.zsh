#!/usr/bin/env zsh

# This script uses the APP_VERSION and APP_NAME environment variables as defined in app_config.json

# Run from the pankosmia/[this-repo's-name]/macos/scripts directory:
#   ./bundle_zip.zsh [tier] [-s|-S] [-g|-G]
#
# Arguments (all optional):
#   tier    One of the values in tiers.order. Defaults to tiers.default.
#   -s/-S   Skip the prompt when the server is off.
#   -g/-G   Run in GitHub Actions mode.

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
tier=""

# Do not ask if the server is off if the -s positional argument is provided in either #1 or #2
# Github Actions specified if the -g positional argument is provided in either #1 or #2
while [[ "$#" -gt 0 ]]
  do case $1 in
      -[sS]) askIfOff="$1"  # -s means "no"
      ;;
      -[gG]) isGHA="$1" # -g means "yes"
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
if [ -z ${askIfOff+x} ]; then # askIfOff is unset"
  askIfOff=-yes
fi

# Assign default value if -g is not present
if [ -z ${isGHA+x} ]; then # isGHA is unset
  isGHA=-no
fi

if ! [[ $askIfOff =~ ^(-s) ]]; then
  while true; do
    read "choice?Is the server off? [Y/n]: "
    case $choice in 
      "y" | "Y" | "" ) echo
        echo "Continuing...";
        break
        ;;
      [nN] ) echo;
        echo "     Exiting...";
        echo;
        echo "     If the server is on, turn it off with Ctrl-C in the terminal window in which it is running, then re-run this script.";
        echo;
        exit
        ;;
      * ) echo
        echo "     \"$choice\" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit.";
        echo
        ;;
    esac
  done
fi

# In GHA, each step has either already run or is otherwise unnecessary.
if ! [[ $isGHA =~ ^(-g) ]]; then
  cd ../../
  if [ $(ls releases/macos/*.zip 2>/dev/null | wc -l) -gt 0 ]; then
    echo "A previous macos .zip release exists. Removing..."
    rm releases/macos/*.zip
  fi
  # echo "checkout main"
  # git checkout main &> /dev/null
  # echo "pull"
  # git pull
  # echo "pnpm install"
  # pnpm install
  cd macos/scripts
fi

# Prints the value of the single entry (in array $1) whose branches include the tier.
tier_value() {
    jq -er --arg t "$tier" --arg k "$1" \
        "[$1[] | select(.branches | index(\$t))] | if length == 1 then .[0].value else error(\$k + \" must have exactly one entry for tier \" + \$t) end" \
        "$APP_CONFIG"
}

APP_NAME=$(tier_value '.app.name') || { echo "Error: app.name not set for tier \"$tier\""; exit 1; }
APP_VERSION=$(tier_value '.app.version') || { echo "Error: app.version not set for tier \"$tier\""; exit 1; }

echo
echo "Tier is $tier"
echo "Version is $APP_VERSION"
echo

if ! [[ $isGHA =~ ^(-g) ]]; then
  if [ -f ../build ]; then
    echo "Removing last build environment"
    rm -rf ../build
  fi
  echo "Assembling build environment for tier $tier..."
    if ! node ./build.js "$tier"; then
    echo "" >&2
    echo "     node build.js failed for tier \"$tier\"." >&2
    echo "" >&2
    exit 1
  fi
fi

# Detect current CPU architecture
CPU_ARCH=$(uname -m)
if [ "$CPU_ARCH" = "x86_64" ]; then
    CPU_ARCH="x64"
elif [ "$CPU_ARCH" = "arm64" ]; then
    CPU_ARCH="arm64"
else
    echo "Error: Unsupported CPU architecture: $CPU_ARCH"
    exit 1
fi

echo
echo "   **********************************"
echo "   *                                *"
echo "   *           ====                 *"
echo "   * Bundling. Wait for the prompt. *"
echo "   *           ====                 *"
echo "   *                                *"
echo "   **********************************"
echo
cd ../build
sed -i.bak "s/\%%ARCH%%/$CPU_ARCH/g" "README.txt"
# Use lower case app name in filename
APP_NAME=${APP_NAME:l}
# Replace spaces with a dash (-) in filename
APP_NAME=${APP_NAME// /-}
# Make executable and zip
chmod +x $APP_NAME.zsh
UNQ="../buildResources/unquarantine.sh"
chmod +x $UNQ
echo $UNQ
zip -r ../../releases/macos/$APP_NAME-$APP_VERSION-macos-$CPU_ARCH-cli.zip * -x post_install_script.sh README.txt.bak @ &> /dev/null
zip -j ../../releases/macos/$APP_NAME-$APP_VERSION-macos-$CPU_ARCH-cli.zip $UNQ
cd ../scripts
