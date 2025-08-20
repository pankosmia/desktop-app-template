#!/usr/bin/env zsh

set -e
set -u

# Do not clean if the -c $1 positional argument is provided
buildWithoutClean="${1:-yes}" # -c = "yes"
if ! [[ $buildWithoutClean =~ ^(-c) ]]; then
  ./clean.bsh
fi

if [ ! -f ../../local_server/target/release/local_server ]; then
    echo "Building local server"
    cd ../../local_server
    OPENSSL_STATIC=yes cargo build --release
    cd ../macos/scripts
fi

if [ ! -d ../build ]; then
  echo "Assembling build environment"
  node ./build.js
fi
