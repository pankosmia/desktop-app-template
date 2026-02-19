#!/usr/bin/env zsh

source ../../app_config.env

count=$( wc -l < "../../app_config.env" )

cd ../../
RepoDirName=$(basename "$(pwd)")
cd ../
for ((i=1;i<=count;i++)); do
  eval asset='$'ASSET$i
  if [ ! -z "$asset" ]; then
    # Remove any spaces, e.g. trailing ones
    asset=$(sed 's/ //g' <<< $asset)
    echo "############################### BEGIN Asset $i: $asset ###############################"
    if [ ! -d "$asset" ]; then
      echo
      echo "****************************************************"
      echo "$asset does not exist; Run .\clone.bat"
      echo "****************************************************"
      echo
    else
      cd $asset
      echo "> git checkout main..."
      git checkout main
      echo "> git pull..."
      git pull
      echo "################################ END Asset $i: $asset ################################"
      echo
      cd ..
    fi
  fi
done
for ((i=1;i<=count;i++)); do
  eval client='$'CLIENT$i
  if [ ! -z "$client" ]; then
    # Remove any spaces, e.g. trailing ones
    client=$(sed 's/ //g' <<< $client)
    echo "############################### BEGIN Client $i: $client ###############################"
    if [ ! -d "$client" ]; then
      echo
      echo "***************************************************************************************"
      echo "$client does not exist; Run .\clone.bat then rerun .\build_clients_main.bat"
      echo "***************************************************************************************"
      echo
    else
      cd $client
      echo "> git checkout main..." 
      git checkout main
      echo "> git pull..."
      git pull
      echo "> npm ci..."
      npm ci
      echo "> npm run build..."
      npm run build
      echo "################################ END Client $i: $client ################################"
      echo
      cd ..  
    fi
  fi
done

cd $RepoDirName/linux/scripts
