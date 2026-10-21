%%APP_NAME%% Instructions

1. If ~/pankosmia/%%APP_SHORT_NAME%% already exists, then delete it, otherwise we will prompt for this to be done first.
  - This will ensure the portable app repo_dir points to the portable app.
  - And it will ensure all else matches this version (e.g., i18n).

2. In the portable app root, which is the same location where you found this file that you are reading now, double click `start-%%APP_SHORT_NAME%%.bat` in Windows Explorer or run it from a terminal.
  - This will recreate ~/pankosmia/%%APP_SHORT_NAME%% consistent with this version, as the server currently seems to insist on initially creating it in `~`.

3. Exit the app.

4. Now in the portable app root, double click `start-%%APP_SHORT_NAME%%.bat` a second time in Windows Explorer or run it from a terminal.
  - This will:
    + move ~/pankosmia/%%APP_SHORT_NAME%% to `portable_root/pankosmia/%%APP_SHORT_NAME%%` and point the spawned server to this new working dir location.
    + remove the Electron AppData directory for App Name from `~/AppData/Roaming` and set it to `portable_root/pankosmia/<shortappname>/AppData`
    + delete the this README.txt file and delete Initialize-PortableApp.ps1, that is unless for some reason something above isn't successful, in which case it will print a message stating what happened.

5. Once this README.txt file and Initialize-PortableApp.ps1 have been deleted by the start script, then the portable app has been initialized and can be moved to different locations as needed.
   - IMPORTANT: Windows needs NTFS format on any media from which this is run (e.g., not FAT or exFAT)