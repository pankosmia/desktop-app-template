#define AppShortName GetEnv("APP_SHORT_NAME")
#pragma message "APP_SHORT_NAME resolved to: " + AppShortName

#define AppIcoName "icon.ico"

#define AppIconSrc GetEnv("APP_ICON")
#if AppIconSrc == ""
  #error APP_ICON is not set. Run via makeInstallElectronite.ps1 (reads resources.app_icon from app_config.json).
#endif
#pragma message "APP_ICON resolved to: " + AppIconSrc

[Setup]
AppName={#GetEnv('APP_NAME')}
AppVersion={#GetEnv('APP_VERSION')}
DefaultDirName={commonpf}\{#GetEnv('APP_NAME')}
DefaultGroupName={#GetEnv('APP_NAME')}
OutputBaseFilename={#GetEnv('FILE_APP_NAME')}-{#GetEnv('APP_VERSION')}-win-{#GetEnv('ARCH')}
Compression=lzma
SolidCompression=yes

[Tasks]
Name: "desktopicon"; Description: "Create a {#GetEnv('APP_NAME')} &desktop icon"; GroupDescription: "{#GetEnv('APP_NAME')} icons:"

[InstallDelete]
Type: filesandordirs; Name: "{%USERPROFILE}\pankosmia\{#GetEnv('APP_SHORT_NAME')}\webfonts"
Type: filesandordirs; Name: "{%USERPROFILE}\pankosmia\{#GetEnv('APP_SHORT_NAME')}\temp"
Type: files; Name: "{%USERPROFILE}\pankosmia\{#GetEnv('APP_SHORT_NAME')}\i18n.json"
Type: files; Name: "{app}\appLauncherElectron.bat"

[Files]
Source: "..\temp\project\payload\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "{#AppIconSrc}"; DestDir: "{app}"; DestName: "{#AppIcoName}"

[Icons]
Name: "{group}\{#GetEnv('APP_NAME')}"; Filename: "{app}\electron\electron.exe"; Parameters: """{app}\electron"""; IconFilename: "{app}\{#AppIcoName}"; Tasks: desktopicon
Name: "{userdesktop}\{#GetEnv('APP_NAME')}"; Filename: "{app}\electron\electron.exe"; Parameters: """{app}\electron""";  IconFilename: "{app}\{#AppIcoName}"; Tasks: desktopicon
Name: "{userdesktop}\{#GetEnv('APP_NAME')} README"; Filename: "{app}\README.txt"; Tasks: desktopicon
Name: "{group}\Uninstall {#GetEnv('APP_NAME')} (Delete App Files)"; Filename: "{uninstallexe}"; Parameters: "/DELETE /ALLFILES"

[Run]
Filename: "{app}\custom_uninstaller.bat"; Parameters: "{app}"