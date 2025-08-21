#!/usr/bin/env zsh

set -e
set -u

echo

# Build without cleaning if the -c positional argument is provided in either #1 or #2
# Do not ask if the server is off if the -s positional argument is provided in either #1 or #2
while [[ "$#" -gt 0 ]]
  do case $1 in
      -c) buildWithoutClean="$1"  # -c means "yes"
      ;;
      -s) askIfOff="$1" # -s means "no"
  esac
  shift
done

# Assign default value if -c is not present
if [ -z ${buildWithoutClean+x} ]; then # buildWithoutClean is unset"
  buildWithoutClean=-no
fi

# Assign default value if -s is not present
if [ -z ${askIfOff+x} ]; then # serverOff is unset
  askIfOff=-yes
fi

# Do not clean if the -c positional argument is provided
if ! [[ $buildWithoutClean =~ ^(-c) ]]; then
  # Do not ask if the server is off if the -s positional argument is provided
  if [[ $askIfOff =~ ^(-s) ]]; then
    ./clean.zsh -s
  else
    ./clean.zsh
  fi
fi

if [ ! -f ../../buildSpec.json ] || [ ! -f ../../globalBuildResources/i18nPatch.json ] || [ ! -f ../buildResources/setup/app_setup.json ]; then
  ./app_setup.zsh
  echo
  echo "  +-----------------------------------------------------------------------------+"
  echo "  | Config files were rebuilt by \`./app_setup.zsh\` as one or more were missing. |"
  echo "  +-----------------------------------------------------------------------------+"
  echo 
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
