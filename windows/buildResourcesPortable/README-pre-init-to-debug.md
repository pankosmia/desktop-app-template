# This is for developers.

### Here is how to see the windows error without the initialize script method:
- Make sure ~/pankosmia/%%APP_SHORT_NAME%% is deleted
- Then run the bat start script in the portable-pre-installed root (next to this README-pre-init-to-debug.md file).

### To demonstrate that "portable-pre-installed (once run)" and "portable (once initialized)" are the same except for the working directory:

Run the initialize script on "portable" by starting, exiting, then starting again, and then:
- compare the contents of `portable_root/panksomia/%%APP_SHORT_NAME%%` *after it has been initialized* vs the contents of ``portable-pre-installed_root/panksomia/%%APP_SHORT_NAME%%` *after it has run, leading to a server error*.

Also compare the following two files at these locations as they are the only differences from the installed production app. These should be the same between the "portable-pre-installed (once run)" and "portable (once initialized)":
  - "%%APP_NAME%%\electron\electronStartup.js" line 45
    - `serverProcess = spawn(SERVER_EXECUTABLE_PATH, ['../pankosmia/%%APP_SHORT_NAME%%'], {`
  - "%%APP_NAME%%\electron\core\server.js" line 130"
    - `serverProcess = spawn(SERVER_EXECUTABLE_PATH, ['../pankosmia/%%APP_SHORT_NAME%%'], {`