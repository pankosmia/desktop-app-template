#!/usr/bin/env zsh

set -e
set -u

doSync() {
  git fetch upstream
  git merge --no-log --no-ff --no-commit upstream/main
  echo README.md:
  git reset README.md
  git checkout README.md
  echo package.json:
  git reset package.json
  git checkout package.json
  echo package-lock.json:
  git reset package-lock.json
  git checkout package-lock.json
  echo app_config.env:
  git reset app_config.env
  git checkout app_config.env
  echo globalBuildResources/favicon.ico:
  git reset globalBuildResources/favicon.ico
  git checkout globalBuildResources/favicon.ico
  echo globalBuildResources/theme.json:
  git reset globalBuildResources/theme.json
  git checkout globalBuildResources/theme.json
  echo
  echo  "    *******************************************************************************"
  echo  "    * Files expected to differ have been excluded from the sync.                  *"
  echo  "    * Now review staged changes, and commit if there are no conflicts, then push. *"
  echo  "    *******************************************************************************"
  echo
}

echo

# Do not ask if the latest is already pulled if the -p $1 positional argument is provided
askIfPulled="${1:-yes}" # -p means "no"
if ! [[ $askIfPulled =~ ^(-p) ]]; then
  while true; do
    read "choice?Are you certain the latest is already pulled? [Y/N y/n]: "
    case $choice in 
      [yY] ) echo
        echo "Continuing..."
        break
        ;;
      [nN] ) echo
        echo "     Exiting...";
        echo
        echo "     Pull the latest, then re-run this script."
        echo
        exit
        ;;
      * ) echo
        echo "     \"$choice\" is not a valid response. Please enter a Y or y for yes, or an N or n for no."
        echo
        ;;
    esac
  done
fi

cd ../../

remote=$(git remote 2>&1)
counta=$(wc -l <<< "${remote}")
remotearray=(${remote[@]})

config=$(git config --local --list 2>&1)
countb=$(wc -l <<< "${config}")
configarray=(${config[@]})
 
# Don't proceed if the origin is not set.
if [ -z "${remotearray[0]}" ]; then
  echo "origin is not set"
  echo "add origin, then re-run this script"
  cd windows/scripts/
  exit;
else
  echo "${remotearray[0]} is set"
fi

origintest=good_if_not_changed
upstreamtest=different_if_not_changed
for ((i=1;i<=countb;i++)); do
  # Don't proceed if the origin is the intended upstream.
  if [ "${configarray[${i}]}" == "remote.origin.url=https://github.com/pankosmia/desktop-app-template.git" ]; then
    origintest=stop_because_is_set_to_desired_upstream
    echo
    echo "origin is set to https://github.com/pankosmia/desktop-app-template.git"
    echo "This script is not meant to be run on this repo as it expects that that to be the upstream, not the origin."
    echo
    echo "Exiting ...."
    echo
    cd windows/scripts/
    exit;
  fi
  # This assumes the origin record will always be returned on an earlier line that the upstream record.
  # Proceed if the origin is set.
  if [ "$origintest"=="good_if_not_changed" ]; then
      # Proceed if the upstream is already set as expected.
    if [ "${configarray[${i}]}" == "remote.upstream.url=https://github.com/pankosmia/desktop-app-template.git" ]; then
      upstreamtest=as_expected
      echo "upstream is confirmed as set to https://github.com/pankosmia/desktop-app-template.git"
      up=$i
      doSync
      cd windows/scripts/
      exit;
    fi
  fi
done
# This assumes the origin record will always be returned on an earlier line that the upstream record.
# Proceed if the origin is set.
if [ "$origintest"="good_if_not_changed" ]; then
  # Set the upstream and proceed if it is not yet set.
  if [ -z "${remotearray[1]}" ]; then
    git remote add upstream https://github.com/pankosmia/desktop-app-template.git
    set upstreamtest=set
    echo upstream has been set to https://github.com/pankosmia/desktop-app-template.git
    doSync
    cd windows/scripts/
    exit;
  fi
fi
# Don't proceed if the upstream is set elsewhere.
if [ "$upstreamtest" == "different_if_not_changed" ]; then
  echo
  echo "The upstream is set to: ${configarray[${up}]}"
  echo "However, this script is written for an upstream that is set to https://github.com/pankosmia/desktop-app-template.git"
  echo
  goto :end
fi
