[Setup]
AppName={#GetEnv('APP_NAME')}
AppVersion={#GetEnv('APP_VERSION')}
DefaultDirName={commonpf}\{#GetEnv('APP_NAME')}
DefaultGroupName={#GetEnv('APP_NAME')}
OutputBaseFilename={#GetEnv('FILE_APP_NAME')}-windows-setup-standalone-{#GetEnv('APP_VERSION')}
Compression=lzma
SolidCompression=yes

[Files]
Source: "..\temp\project\payload\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\{#GetEnv('APP_NAME')}"; Filename: "{app}\electron\electron.exe"; Parameters: """{app}\electron"""
Name: "{userdesktop}\{#GetEnv('APP_NAME')}"; Filename: "{app}\electron\electron.exe"; Parameters: """{app}\electron"""; Tasks: desktopicon
Name: "{userdesktop}\{#GetEnv('APP_NAME')} README"; Filename: "{app}\README.txt"; Tasks: desktopicon
Name: "{group}\Uninstall {#GetEnv('APP_NAME')} (Delete App Files)"; Filename: "{uninstallexe}"; Parameters: "/DELETE /ALLFILES"

[Run]
Filename: "{app}\custom_uninstaller.bat"; Parameters: "{app}"

[Tasks]
Name: "desktopicon"; Description: "Create a {#GetEnv('APP_NAME')} &desktop icon"; GroupDescription: "{#GetEnv('APP_NAME')} icons:"