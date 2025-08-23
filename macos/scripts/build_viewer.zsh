# Run from pankosmia\[this-repo's-name]\macos\scripts directory by:  .\build_viewer.zsh

TEMP_DIR=../viewer
if [ -d $TEMP_DIR ]; then
    echo "Deleting previous viewer build..."
    echo
    rm -rf $TEMP_DIR
fi

echo
echo
echo "********************************************************************"
echo "\"Getting Electron release\" downloads an approximately 120 MB file."
echo "Please wait patiently for the download process to complete..."
echo "********************************************************************"
echo

../install/makeAllInstallsElectronite.sh -d