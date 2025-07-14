#%%FILE_APP_NAME%%%%-macos-%%APP_VERSION%% USAGE

To upgrade:

1. Backup `~/panksomia_working/repos` where "~" is the OS user home directory.
2. Delete `~/panksomia_working/`
3. Move %%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%.zip to your Desktop.
4. Follow either "PKG Installed Version" or "Zip Terminal Package" depending on which you are using.

  PKG Installed Version:
    4.1. Double-click the %%FILE_APP_NAME%%%%-macos-%%APP_VERSION%% pkg file to start the installer.
      * If you get a message saying "Not Opened", then:
        a. Click either "Done" or "Cancel", depending on which of those options you have.
        b. Go to Apple menu > System Preference >  Privacy and Security > General > and at the bottom, where it shows the file that was blocked, click "Allow Anyway" .
        c. Wait until the "___ was blocked" message disappears from the settings page.
      * If you get "can't open the file" or something else similar, then:
        * Look under Settings > Privacy and Security > Files & Folders > Terminal, and see if you need to turn on permissions for Desktop, OR, move your %%FILE_APP_NAME%%%% folder to another location or re-unzip in another location and run from there in a terminal.
        * Or, another possibility is that 'Move to Trash' could have been selected on server.bin on a prior attempt to run. If this was done, then you can find it in your trash and 'put back', or re-unzip.
    4.2. Continue the Installation, only double-clicking again on the pkg file if the process isn't automatically continued for you.
    4.5. After installation, run /%%FILE_APP_NAME%%%% from the Launchpad or from Applications.
        Watch following load in the terminal window:
        OS = 'macos'
        Rocket has launched from http://127.0.0.1:19119
        This will also launch http://localhost:19119 in Firefox (if available) or in your default web browser.
          * Refresh the browser if the app does not show on first load.
    4.6. Restore backup from step 1 to `~/panksomia_working/repos`
    4.7. Reconnect to http://localhost:19119 from Firefox (or an alternate web browser) as needed.

  Zip Terminal Package:
    4.1. Double-click %%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%.zip to expand its contents into a '%%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%' folder.
    4.2. Open a terminal -- Launchpad (Application) > Utilities > Terminal
    4.3. Type the following then enter:
        cd Desktop/%%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%
              Use the values of [ intel | mx ] from the folder name expanded on your Desktop in step 4 above.
    4.4. Type the following then enter:
        ./%%FILE_APP_NAME%%%%.%%APP_EXT%%
    4.5. This will should to a message saying "server.bin" Not Opened. If instead you get "can't open the file" or something else similar, then:
      * Look under Settings > Privacy and Security > Files & Folders > Terminal, and see if you need to turn on permissions for Desktop, OR, move your %%FILE_APP_NAME%%%% folder to another location or re-unzip in another location and run from there in a terminal.
      * Or, another possibility is that 'Move to Trash' could have been selected on server.bin on a prior attempt to run. If this was done, then you can find it in your trash and 'put back', or re-unzip.
    4.6. Click either "Done" or "Cancel", depending on which of those options you have.
    4.7. Go to Apple menu > System Preference >  Privacy and Security > General > and at the bottom, after "server.bin" was blocked, click "Allow Anyway" .
    4.8. Wait until the "server.bin was blocked" message disappears from the settings page.
    4.9. In the terminal type the following again then enter:
        ./%%FILE_APP_NAME%%%%.%%APP_EXT%%
        Watch following load in the terminal window:
        OS = 'macos'
        Rocket has launched from http://127.0.0.1:19119
        This will also launch http://localhost:19119 in Firefox (if available) or in your default web browser.
    4.10. Restore backup from step 1 to `~/panksomia_working/repos`
    4.11. Reconnect to http://localhost:19119 from Firefox (or an alternate web browser) as needed.
    4.12. To completely stop the app from running, short of rebooting you can:
          4.12.1. G to Launchpad > Other > Activity Monitor (or Go > Utilities > Activity Monitor)
          4.12.2. Search for app-name
          4.12.3. Click on the app process row to highlight
          4.12.4. Click the x next to the i in the top row.
          4.12.5. Choose Force Quite

First time use (not an upgrade) -- Follow either "PKG Installed Version" or "Zip Terminal Package" depending on which you are using.

  PKG Installed version:
      1. Double-click %%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%.zip to expand its contents into a '%%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%' folder.
      2. Open a terminal -- Launchpad (Application) > Utilities > Terminal
      3. Type the following then enter:
          cd Desktop/%%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%
                Use the values of [ intel | mx ] from the folder name expanded on your Desktop in step 4 above.
      4. Type the following then enter:
          ./%%FILE_APP_NAME%%%%.%%APP_EXT%%
      5. This will should to a message saying "server.bin" Not Opened. If instead you get "can't open the file" or something else similar, then:
        * Look under Settings > Privacy and Security > Files & Folders > Terminal, and see if you need to turn on permissions for Desktop, OR, move your %%FILE_APP_NAME%%%% folder to another location or re-unzip in another location and run from there in a terminal.
        * Or, another possibility is that 'Move to Trash' could have been selected on server.bin on a prior attempt to run. If this was done, then you can find it in your trash and 'put back', or re-unzip.
      6. Click either "Done" or "Cancel", depending on which of those options you have.
      7. Go to Apple menu > System Preference >  Privacy and Security > General > and at the bottom, after "server.bin" was blocked, click "Allow Anyway" .
      8. Wait until the "server.bin was blocked" message disappears from the settings page.
      9. In the terminal type the following again then enter:
          ./%%FILE_APP_NAME%%%%.%%APP_EXT%%
          Watch following load in the terminal window:
          OS = 'macos'
          Rocket has launched from http://127.0.0.1:19119
          This will also launch http://localhost:19119 in Firefox (if available) or in your default web browser.
      10. Reconnect to http://localhost:19119 from Firefox (or an alternate web browser) as needed.
      11. To completely stop the app from running, short of rebooting you can:
          11.1. G to Launchpad > Other > Activity Monitor (or Go > Utilities > Activity Monitor)
          11.2. Search for server.bin
          11.3. Click on the app process row to highlight
          11.4. Click the x next to the i in the top row.
          11.5. Choose Force Quite

  Zip Terminal Package:
    1. Move %%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%.zip to your Desktop.
    2. Double-click %%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%.zip to expand its contents into a '%%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%' folder.
    3. Open a terminal -- Launchpad (Application) > Utilities > Terminal
    4. Type the following then enter:
        cd Desktop/%%FILE_APP_NAME%%%%-macos-%%APP_VERSION%%
              Use the values of [ intel | mx ] from the folder expanded on your Desktop in step 2 above.
    5. Type the following then enter:
        ./%%FILE_APP_NAME%%%%.%%APP_EXT%%
    6. This will lead to a message saying "server.bin" Not Opened
    7. Click either "Done" or "Cancel", depending on which of those options you have.
    8. Go to Apple menu > System Preference >  Privacy and Security > General > and at the bottom, after "server.bin" was blocked, click "Allow Anyway" .
    9. Wait until the "server.bin was blocked" message disappears from the settings page.
    10. In the terminal type the following again then enter:
        ./%%FILE_APP_NAME%%%%.%%APP_EXT%%
        Watch following load in the terminal window:
        OS = 'macos'
        Rocket has launched from http://127.0.0.1:19119
        This will also launch http://localhost:19119 in Firefox (if available) or in your default web browser.
    11. Reconnect to http://localhost:19119 from Firefox (or an alternate web browser) as needed.

Best viewed with a Graphite-enabled browser such as Firefox, Zen Browser, LibreWolf or via Electronite.