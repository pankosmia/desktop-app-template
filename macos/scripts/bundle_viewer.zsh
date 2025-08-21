# This script uses the APP_VERSION environment variable as defined in app_config.env

# Run from pankosmia\[this-repo's-name]\macos\scripts directory by:  .\bundle_viewer.zsh
# with the optional arguments of: .\bundle_viewer.zsh -s
# to pre-specify that the server is off.

# Do not ask if the server is off if the -s $1 positional argument is provided
askIfOff="${1:-yes}" # -s means "no"
if ! [[ $askIfOff =~ ^(-s) ]]; then
  while true; do
    read "choice?Is the server off? [Y/N y/n]: "
    case $choice in 
      [yY] ) echo
        echo "Continuing..."
        break
        ;;
      [nN] ) echo
        echo "     Exiting..."
        echo
        echo "If the server is on, turn it off (e.g., Ctrl-C in terminal window or exit app), then re-run this script."
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

if [ ! -f ../../local_server/target/release/local_server ]; then
  echo
  echo "   ***************************************************************"
  echo "   * IMPORTANT: Build the local server, then re-run this script! *"
  echo "   ***************************************************************"
  echo
  exit
fi

cd ..\..\
echo "checkout main"
git checkout main | Out-Null
echo "pull"
git pull
echo "npm install"
npm install
echo
echo "Running app_setup to ensure version number consistency between buildSpec.json and this build bundle:"
cd windows\scripts
./app_setup.zsh

source ../../app_config.env
echo
echo "Version is $APP_VERSION"
echo

$TEMP_DIR = "../temp"
if [ -d $TEMP_DIR ]; then
    echo "Deleting previous build..."
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

../install/makeAllInstallsElectronite.sh
