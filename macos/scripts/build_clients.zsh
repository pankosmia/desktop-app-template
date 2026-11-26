#!/usr/bin/env zsh

# Run from: pankosmia/<repo-name>/macos/scripts

# Usage:
#   ./build_clients.zsh [branch] [fallback_tier] [-d] [-f]
#     The -d argument means to delete past logs without asking
#     The -f argument means all clones are fresh, so pulling is skipped.
#     The first non-flag argument is the branch name (default: tiers.default in app_config.json, i.e. dev)
#     The second non-flag argument is the tier from tiers.order -- e.g., dev, qa, or main
#       (default: the branch itself if it is a tier name, otherwise tiers.default)
#     The tier selects which assets/clients are built, and the checkout fallback chain.
#
# Examples where tiers.order is ["dev", "qa", "main"] and tiers.default is dev
#   ./build_clients.zsh                        # dev  -> tries dev -> qa -> main
#   ./build_clients.zsh main                   # tries main
#   ./build_clients.zsh my-branch              # tries my-branch → dev → qa → main
#   ./build_clients.zsh my-branch qa -d        # tries my-branch → qa → main, deletes past logs
#   ./build_clients.zsh -f -d dev              # fresh clone (skips pulling), delete logs, dev → qa → main

# Temporary until migration from npm to pnpm is complete on main
export CI=true
export npm_config_dangerouslyAllowAllBuilds=true
export npm_config_dangerously_allow_all_builds=true

if ! command -v jq >/dev/null 2>&1; then
  echo
  echo "     jq is required to read app_config.json."
  echo
  exit 1
fi

# app_config.json at repo root
APP_CONFIG="../../app_config.json"
default_tier=$(jq -r '.tiers.default' "$APP_CONFIG")
tier_list=$(jq -r '.tiers.order | join(" ")' "$APP_CONFIG")
TIERS=("${(@s: :)tier_list}")

is_tier() {
  jq -e --arg t "$1" '.tiers.order | index($t) != null' "$APP_CONFIG" >/dev/null
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- parse args ---
deleteLogs="-no"
FRESH_CLONE=""
BRANCH=""
FALLBACK_TIER=""
while [ $# -gt 0 ]; do
  if [ "$1" = "-d" ]; then
    deleteLogs="-d"
  elif [ "$1" = "-f" ]; then
    FRESH_CLONE=1
  elif [ -z "$BRANCH" ]; then
    BRANCH="$1"
  elif [ -z "$FALLBACK_TIER" ]; then
    FALLBACK_TIER="$1"
  fi
  shift
done

# Default branch is tiers.default if not provided
if [ -z "$BRANCH" ]; then
  BRANCH="$default_tier"
fi

# If no fallback tier specified, use the branch if it is a tier, otherwise tiers.default
if [ -z "$FALLBACK_TIER" ]; then
  if is_tier "$BRANCH"; then
    FALLBACK_TIER="$BRANCH"
  else
    FALLBACK_TIER="$default_tier"
  fi
fi

# Fallback tier must be listed in tiers.order
if ! is_tier "$FALLBACK_TIER"; then
  echo "" >&2
  echo "     Tier \"$FALLBACK_TIER\" is not listed in tiers.order. One of: $tier_list" >&2
  echo "" >&2
  exit 1
fi

# Checkout chain: the branch, then the fallback tier and every tier after it in tiers.order
CHAIN=("$BRANCH")
inChain=0
for t in "${TIERS[@]}"; do
  if [ "$t" = "$FALLBACK_TIER" ]; then
    inChain=1
  fi
  if [ "$inChain" -eq 1 ] && [ "$t" != "$BRANCH" ]; then
    CHAIN+=("$t")
  fi
done

# Read the repos used by the fallback tier before changing directory,
# since APP_CONFIG is relative to the scripts directory
assets=("${(@f)$(jq -r --arg t "$FALLBACK_TIER" '.assets[] | select(.branches | index($t)) | .repo' "$APP_CONFIG")}")
clients=("${(@f)$(jq -r --arg t "$FALLBACK_TIER" '.clients[] | select(.branches | index($t)) | .repo' "$APP_CONFIG")}")

# --- delete past logs (prompt unless -d) ---
if ls "${SCRIPT_DIR}"/build_clients_*.log >/dev/null 2>&1; then
  echo
  if [ "$deleteLogs" = "-d" ]; then
    rm -f "${SCRIPT_DIR}"/build_clients_*.log
  else
    while true; do
      read -r "c?Delete past logs? [Y/n]: "
      if [ -z "$c" ] || [ "$c" = "Y" ] || [ "$c" = "y" ]; then
        rm -f "${SCRIPT_DIR}"/build_clients_*.log
        break
      elif [ "$c" = "N" ] || [ "$c" = "n" ]; then
        break
      else
        echo "\"$c\" is not a valid response. Type y or 'Enter' to delete past logs, or 'n' to keep them."
      fi
    done
  fi
fi

# --- logging + failure tracking ---
LOG="${SCRIPT_DIR}/build_clients_$(date +%Y%m%d_%H%M%S).log"
echo "===== Build started $(date) =====" > "$LOG"

FAILCOUNT=0
FAILS=()
SKIPCOUNT=0
SKIPS=()

log() {
  echo "$*"
  echo "$*" >> "$LOG"
}

run() {
  "$@" 2>&1 | tee -a "$LOG"
  return "${pipestatus[1]}"   # zsh: exit status of the first command in the pipeline
}

markfail() {
  FAILCOUNT=$((FAILCOUNT + 1))
  FAILS+=("[$1] $2 :: $3")
}

markskip() {
  SKIPCOUNT=$((SKIPCOUNT + 1))
  SKIPS+=("[$1] $2 ($3): $4")
}

# --- checkout with fallback logic ---
checkout_branch() {
  local cb_type="$1"
  local cb_repo="$2"

  # Fetch remote refs so all remote branches are known
  log "> git fetch origin..."
  if ! run git fetch origin; then
    log "> WARNING: git fetch failed; proceeding with possibly stale remote refs"
  fi

  local prev=""
  local candidate
  for candidate in "${CHAIN[@]}"; do
    if [ -n "$prev" ]; then
      log "> Branch \"$prev\" not found, trying \"$candidate\"..."
    fi
    log "> git checkout $candidate..."
    if run git checkout "$candidate"; then
      CHECKED_OUT_BRANCH="$candidate"
      return
    fi
    prev="$candidate"
  done

  CHECKED_OUT_BRANCH="${CHAIN[-1]}"
  markfail "$cb_type" "$cb_repo" "git checkout ${CHAIN[*]}"
}

# --- pull logic ---
safe_pull() {
  local sp_type="$1"
  local sp_repo="$2"

  if [ -n "$FRESH_CLONE" ]; then
    log "> Skipping pull -- -f flag set, 'fresh' clone, no pull"
    markskip "$sp_type" "$sp_repo" "$CHECKED_OUT_BRANCH" "-f flag set, 'fresh' clone, no pull"
    return
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    log "> Skipping pull -- uncommitted local changes detected on \"$CHECKED_OUT_BRANCH\", no pull"
    markskip "$sp_type" "$sp_repo" "$CHECKED_OUT_BRANCH" "uncommitted local changes, no pull"
    return
  fi

  if ! git rev-parse --verify "origin/$CHECKED_OUT_BRANCH" >/dev/null 2>&1; then
    log "> Skipping pull -- origin/$CHECKED_OUT_BRANCH does not exist, no pull"
    markskip "$sp_type" "$sp_repo" "$CHECKED_OUT_BRANCH" "origin/$CHECKED_OUT_BRANCH does not exist, no pull"
    return
  fi

  local local_ahead
  local_ahead=$(git rev-list "origin/$CHECKED_OUT_BRANCH..HEAD" --count 2>/dev/null)
  if [ "$local_ahead" -gt 0 ] 2>/dev/null; then
    log "> Skipping pull -- \"$CHECKED_OUT_BRANCH\" has $local_ahead unpushed commit(s), no pull"
    markskip "$sp_type" "$sp_repo" "$CHECKED_OUT_BRANCH" "$local_ahead unpushed commit(s), no pull"
    return
  fi

  log "> git pull origin $CHECKED_OUT_BRANCH..."
  if ! run git pull origin "$CHECKED_OUT_BRANCH"; then markfail "$sp_type" "$sp_repo" "git pull origin $CHECKED_OUT_BRANCH"; fi
}

cd ../../
RepoDirName=$(basename "$(pwd)")
cd ../

for asset in "${assets[@]}"; do
  [[ -z "$asset" ]] && continue
  log "############################### BEGIN Asset: $asset ###############################"
  if [ ! -d "$asset" ]; then
    log
    log "****************************************************"
    log "$asset does not exist; Run ./clone.zsh"
    log "****************************************************"
    log
    markfail "ASSET" "$asset" "directory not found; Run ./clone.zsh"
  else
    cd "$asset"
    checkout_branch "ASSET" "$asset"
    safe_pull "ASSET" "$asset"

    log "################################ END Asset: $asset ################################"
    log
    cd ..
  fi
done

for client in "${clients[@]}"; do
  [[ -z "$client" ]] && continue
  log "############################### BEGIN Client: $client ###############################"
  if [ ! -d "$client" ]; then
    log
    log "***************************************************************************************"
    log "$client does not exist; Run ./clone.zsh then rerun this script"
    log "***************************************************************************************"
    log
    markfail "CLIENT" "$client" "directory not found; Run ./clone.zsh"
  else
    cd "$client"
    checkout_branch "CLIENT" "$client"
    safe_pull "CLIENT" "$client"

    if [ "${CHECKED_OUT_BRANCH:l}" = "main" ]; then
      # Temporary until migration from npm to pnpm is complete on main
      log "> pnpm --config.dangerouslyAllowAllBuilds=true install --no-frozen-lockfile ..."
      if ! run pnpm --config.dangerouslyAllowAllBuilds=true install --no-frozen-lockfile; then markfail "CLIENT" "$client" "run pnpm --config.dangerouslyAllowAllBuilds=true install --no-frozen-lockfile"; fi

      case "$client" in
        core-client-dashboard)
          log "-- temporarily adding @mui/icons-material..."
          if ! run pnpm add @mui/icons-material@6.5.0; then markfail "CLIENT" "$client" "pnpm add @mui/icons-material@6.5.0"; fi
          ;;
        core-client-i18n-editor|core-client-settings)
          log "-- temporarily adding notistack..."
          if ! run pnpm add notistack; then markfail "CLIENT" "$client" "pnpm add notistack"; fi
          ;;
        core-contenthandler_t_core)
          log "-- temporarily adding notistack and prop-types..."
          if ! run pnpm add notistack; then markfail "CLIENT" "$client" "pnpm add notistack"; fi
          if ! run pnpm add prop-types; then markfail "CLIENT" "$client" "pnpm add prop-types"; fi
          ;;
        core-client_pdf_publisher)
          log "-- temporarily adding @mui/icons-material, notistack and proskomma-json-tools..."
          if ! run pnpm add @mui/icons-material@6.1.5; then markfail "CLIENT" "$client" "pnpm add @mui/icons-material@6.1.5"; fi
          if ! run pnpm add notistack; then markfail "CLIENT" "$client" "pnpm add notistack"; fi
          if ! run pnpm add proskomma-json-tools; then markfail "CLIENT" "$client" "pnpm add proskomma-json-tools"; fi
          ;;
        core-contenthandler-print_specs)
          log "-- temporarily adding notistack..."
          if ! run pnpm add notistack; then markfail "CLIENT" "$client" "pnpm add notistack"; fi
          ;;
        core-contenthandler_translation_plan)
          log "-- temporarily adding @mui/icons-material and prop-types..."
          if ! run pnpm add @mui/icons-material@6.1.5; then markfail "CLIENT" "$client" "pnpm add @mui/icons-material@6.1.5"; fi
          if ! run pnpm add prop-types; then markfail "CLIENT" "$client" "pnpm add prop-types"; fi
          ;;
      esac
    else
      log "> pnpm install..."
      if ! run pnpm install; then markfail "CLIENT" "$client" "run pnpm install"; fi
    fi

    if [ "${CHECKED_OUT_BRANCH:l}" = "main" ]; then
      log "run pnpm --config.dangerouslyAllowAllBuilds=true run build ..."
      if ! run pnpm --config.dangerouslyAllowAllBuilds=true run build; then markfail "CLIENT" "$client" "run pnpm --config.dangerouslyAllowAllBuilds=true run build"; fi
    else
      log "run pnpm run build ..."
      if ! run pnpm run build; then markfail "CLIENT" "$client" "run pnpm run build"; fi
    fi

    log "################################ END Client: $client ################################"
    log
    cd ..
  fi
done

cd "$RepoDirName/macos/scripts"

# --- concise summary ---
echo
echo "================================= SUMMARY ================================="
if [ "$FAILCOUNT" -eq 0 ]; then
  echo "All builds succeeded."
else
  echo "Failed steps: $FAILCOUNT"
  for f in "${FAILS[@]}"; do
    echo "  $f"
  done
fi
if [ "$SKIPCOUNT" -gt 0 ]; then
  echo
  echo "Skipped pulls: $SKIPCOUNT"
  for s in "${SKIPS[@]}"; do
    echo "  $s"
  done
fi
echo
if [ "$GITHUB_ACTIONS" = "true" ]; then
  echo "Full log: scroll up in the \"Run build_clients.zsh\" step output above."
else
  echo "Full log: \"$LOG\""
fi
echo "==========================================================================="

if [ "$FAILCOUNT" -gt 0 ]; then
  exit 1
fi
exit 0
