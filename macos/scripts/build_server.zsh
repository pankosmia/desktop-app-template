#!/usr/bin/env zsh

set -e
set -u

echo

# Build without cleaning if the -c positional argument is provided in either #1 or #2 or #3
# Do not ask if the server is off if the -s positional argument is provided in either #1 or #2 or #3
# Debug server if the -d positional argument is provided in either #1 or #2 or #3
while [[ "$#" -gt 0 ]]
  do case $1 in
      -c) buildWithoutClean="$1"  # -c means "yes"
      ;;
      -s) askIfOff="$1" # -s means "no"
      ;;
      -d) debugServer="$1" # -d = "yes"
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

# Assign default value if -s is not present
if [ -z ${debugServer+x} ]; then # debugServer is unset
  debugServer=-no
  buildCommand=(cargo build --release)
  search=local_server/target/debug
  replace=local_server/target/release
elif [[ $debugServer =~ ^(-d) ]]; then
  buildCommand=(cargo build)
  search=local_server/target/release
  replace=local_server/target/debug
fi

# Ensure buildSpec.json has the location for the indicated server build type
configFile=../../buildSpec.json
tmpFile=../../buildSpec.bak
cp $configFile $tmpFile
sed -i '' "s|$search|$replace|g" "$configFile"

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

if [[ ! -f ../../local_server/target/release/local_server && ! -f ../../local_server/target/debug/local_server ]]; then
    echo "Building local server"
    cd ../../local_server
    OPENSSL_STATIC=yes "${buildCommand[@]}"
    cd ../macos/scripts
fi

if [ ! -d ../build ]; then
  echo "Assembling build environment"
  node ./build.js
fi
