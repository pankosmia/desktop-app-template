#!/bin/sh

# Find first free TCP port starting at $PORT (default 19119)
PORT=${1:-19119}
MAX_PORT=65535

# Helpers to identify free port
have_cmd(){ command -v "$1" >/dev/null 2>&1; }

is_listening_ss(){
  # Avoid complex ss filters which can hang; parse output instead.
  ss -ltnH -o state listening 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | grep -xq -- "$1"
}

is_listening_lsof(){
  # -t prints only PIDs
  lsof -iTCP:"$1" -sTCP:LISTEN -t >/dev/null 2>&1
}

is_listening_netstat(){
  netstat -ltn 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | grep -xq -- "$1"
}

# Choose port checker helper preferring ss over lsof over netstat otherwise use default
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
  echo "Will use the default port and hope it is not already in use."
else
  # find first free port
  found=false
  while [ "$PORT" -le "$MAX_PORT" ]; do
    if ! $checker "$PORT"; then
      found=true
      break
    fi
    PORT=$((PORT+1))
  done

  if [ "$found" = false ]; then
    echo "No free TCP port found up to $MAX_PORT"
    exit 1
  fi
fi

# set port environment variables
export ROCKET_PORT=$PORT