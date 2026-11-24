#!/usr/bin/env bash

# build_viewer.bsh is a symlink to build_viewer.sh

# Run from pankosmia\[this-repo's-name]\linux\scripts directory by:  ./build_viewer.sh
# Or force a full install with: ./build_viewer.sh -f

ELECTRON_VER="../viewer/project/payload/app/electron/version"
EXPECTED="37.1.0"

FORCE_FULL_INSTALL=false
if [[ "${1:-}" == "-f" ]]; then
    FORCE_FULL_INSTALL=true
fi

# A full install will also install, or re-install, Electronite.
fullInstall=$FORCE_FULL_INSTALL

if [ "$fullInstall" != true ]; then
    if [ -f "$ELECTRON_VER" ]; then
        content="$(tr -d '\r\n' < "$ELECTRON_VER")"
        if [ "$content" = "$EXPECTED" ]; then
            echo "The installed viewer Electronite version is $content, which is correct. Use -f to force a full re-install."
            echo "No download is needed. Everything else will be updated."
            fullInstall=false
        else
            echo "The installed viewer Electronite version is $content, however we are not using $EXPECTED. Please wait for the download and upgrade that will follow..."
            fullInstall=true
        fi
    else
        echo "A full viewer install will follow, including download of Electronite. Please wait patiently..."
        fullInstall=true
    fi
else
    # -f flag detected.
    echo "A full viewer install will follow, including download of Electronite. Please wait patiently..."
fi

TEMP_DIR="../viewer"
if [ "$fullInstall" = true ] && [ -d "$TEMP_DIR" ]; then
    echo "Deleting previous viewer build..."
    rm -rf "$TEMP_DIR"
fi

if [ "$fullInstall" = true ]; then
    echo "********************************************************************"
    echo "\"Getting Electron release\" downloads an approximately 120 MB file."
    echo "Please wait patiently for the download process to complete..."
    echo "********************************************************************"
    ../install/makeAllInstallsElectronite.sh -d -f
else
    ../install/makeAllInstallsElectronite.sh -d
fi
