#!/usr/bin/env bash

# clone.bsh is a symlink to clone.sh
#
# Run from pankosmia/[this-repo's-name]/linux/scripts directory:
#  ./clone.sh [-s|-S] [tier | tierRepos]
#
# Arguments (all optional):
#   -s/-S        Use ssh; defaults to https
#   <tier>         One of the values in tiers.order (e.g. dev, qa, main)
#   <tier>Repos    Same as tier (e.g. devRepos, qaRepos, mainRepos)
#   (none)       Clones the repos used by tiers.default

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
METHOD=https://github.com/

while [[ "$#" -gt 0 ]]
  do case $1 in
    -[sS]) METHOD=git@github.com:
    ;;
    *)
      # Accept <tier> or <tier>Repos
      base="${1%Repos}"
      if jq -e --arg t "$base" '.tiers.order | index($t) != null' "$APP_CONFIG" >/dev/null; then
        if [[ -n "$tier" ]]; then
          echo "" >&2
          echo "     Only one tier may be specified (got '$tier' and '$base'). One of: $tier_list (optionally with a Repos suffix)" >&2
          echo "" >&2
          exit 1
        fi
        tier="$base"
      else
        echo "" >&2
        echo "     Unknown argument \"$1\". Use -s, or one of: $tier_list (optionally with a Repos suffix)" >&2
        echo "" >&2
        exit 1
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

echo "Cloning repos used by the $tier tier."
echo "Note: cloning does not check out $tier branches. Repos stay on their default branch."
echo

# Read the repos used by this tier before changing directory,
# since APP_CONFIG is relative to the scripts directory
assets=$(jq -r --arg t "$tier" '.assets[] | select(.branches | index($t)) | .repo' "$APP_CONFIG")
clients=$(jq -r --arg t "$tier" '.clients[] | select(.branches | index($t)) | .repo' "$APP_CONFIG")

cd ../../
RepoDirName=$(basename "$(pwd)")
cd ../

for asset in $assets; do
  echo "############################### BEGIN Asset: $asset ###############################"
  if [ ! -d "$asset" ]; then
    git clone "$METHOD"pankosmia/$asset.git
  else
    echo "Directory already exists; Not cloned."
  fi
  echo "################################ END Asset: $asset ################################"
  echo
done

for client in $clients; do
  echo "############################### BEGIN Client: $client ###############################"
  if [ ! -d "$client" ]; then
    git clone "$METHOD"pankosmia/$client.git
  else
    echo "Directory already exists; Not cloned."
  fi
  echo "################################ END Client: $client ################################"
  echo
done

echo "Done. Repos are on their default branches for the $tier tier."
echo "To check out a tier's branches, run: ./build_clients.sh <tier>"

cd $RepoDirName/linux/scripts
