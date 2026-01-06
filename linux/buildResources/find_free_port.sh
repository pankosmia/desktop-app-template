#!/bin/sh

# This script is intended for linux an differs from the macos sh script.
#   ss is not present on macOS by default, so that test isn't so useful there.
#   The macOS netstat test is written differently as -ltn may not list listeners the same way.

# This script works as follows:
#   If ss (fastest) is available it listens there until it finds an available port.
#     An open port found by ss will then be reconfirmed as open via lsof (if available) otherwise via netstat (if available)
#   If ss is not available but lsof is, then lsof will be used.
#   If neither ss nor lsof are available but netstat is, then netstat will be used.
#   In the event none of these methods are available the default port will be used without confirmation that it is available.

# Why the double check on ss?
#  ss false negatives (ports false reported as not in use) could stem from visibility, parsing, permissions, and tool/version quirks.
#  lsof false negatives are possible but uncommon.
#  netstat false negatives stem from visibility/namespace/permission limits, differing output formats across implementations, filtering flags, IPv6/address-format quirks, race conditions, and parsing bugs. 

# Find first free TCP port starting at $PORT (default 19119)
PORT=${1:-19119}
MAX_PORT=65535

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

is_listening_ss(){
  ss --numeric --no-header -ltn 2>/dev/null | awk -v p=":$PORT$" '
    { for (i=1;i<=NF;i++) if ($i ~ p) exit 0 }
    END { exit 1 }
  '
}

is_listening_lsof(){
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t >/dev/null 2>/dev/null
}

is_listening_netstat(){
  netstat -ltn 2>/dev/null | awk -v p=":$PORT$" '
    { for(i=1;i<=NF;i++) if ($i ~ p) exit 0 }
    END { exit 1 }
  '
}

# prefer ss then lsof then netstat
checker_available=true
if have_cmd ss; then
  checker=is_listening_ss
elif have_cmd lsof; then
  checker=is_listening_lsof
elif have_cmd netstat; then
  checker=is_listening_netstat
else
  checker_available=false
fi

if [ "$checker_available" = false ]; then
  echo "Neither ss nor lsof nor netstat are available."
  exit 3
fi

case "$PORT" in
  ''|*[!0-9]*)
    echo "Invalid port: $PORT"; exit 2 ;;
esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt "$MAX_PORT" ]; then
  echo "Port out of range: $PORT"; exit 2
fi

found=false
tries=0
while [ "$PORT" -le "$MAX_PORT" ] && [ "$tries" -le 65536 ]; do
  if ! $checker; then
    if [ "$checker" = "is_listening_ss" ]; then
      if have_cmd lsof; then
        if is_listening_lsof; then
          PORT=$((PORT+1)); tries=$((tries+1)); continue
        else
          found=true; break
        fi
      elif have_cmd netstat; then
        if is_listening_netstat; then
          PORT=$((PORT+1)); tries=$((tries+1)); continue
        else
          found=true; break
        fi
      else
        found=true; break
      fi
    else
      found=true; break
    fi
  else
    PORT=$((PORT+1)); tries=$((tries+1)); continue
  fi
done

if [ "$found" = false ]; then
  echo "No free TCP port found up to $MAX_PORT"
  exit 1
fi

# set port environment variables
export ROCKET_PORT=$PORT