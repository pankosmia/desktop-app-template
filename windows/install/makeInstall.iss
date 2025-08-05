   [Setup]
   AppName={#GetEnv('APP_NAME')}
   AppVersion={#GetEnv('APP_VERSION')}
   DefaultDirName={commonpf}\{#GetEnv('APP_NAME')}
   DefaultGroupName={#GetEnv('APP_NAME')}
   OutputBaseFilename={#GetEnv('FILE_APP_NAME')}-windows-setup-{#GetEnv('APP_VERSION')}
   Compression=lzma
   SolidCompression=yes

   [Files]
   Source: "..\build\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
   Source: "..\buildResources\appLauncher.bat"; DestDir: "{app}"; Flags: ignoreversion
   Source: "..\build\README.txt"; DestDir: "{app}"; Flags: ignoreversion

   [Icons]
   Name: "{group}\{#GetEnv('APP_NAME')}"; Filename: "{app}\appLauncher.bat"
   Name: "{userdesktop}\{#GetEnv('APP_NAME')}"; Filename: "{app}\appLauncher.bat"; Tasks: desktopicon
   Name: "{userdesktop}\{#GetEnv('APP_NAME')} README"; Filename: "{app}\README.txt"; Tasks: desktopicon
   Name: "{group}\Uninstall {#GetEnv('APP_NAME')} (Delete App Files)"; Filename: "{uninstallexe}"; Parameters: "/DELETE /ALLFILES"

   [Run]
   Filename: "{app}\custom_uninstaller.bat"; Parameters: "{app}"

   [Tasks]
   Name: "desktopicon"; Description: "Create a {#GetEnv('APP_NAME')} &desktop icon"; GroupDescription: "{#GetEnv('APP_NAME')} icons:"
