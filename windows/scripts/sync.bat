@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\sync.bat
REM Optional arguments: .\sync.bat -p
REM or: .\sync.bat -P
REM To pre-confirm the server is off, so as to not be asked.

echo.
:choice
IF "%~1"=="-p" (
  goto :yes
) ELSE (
  set /P "c=Is the latest already pulled? [Y/n]: "
)
if /I "%c%" EQU "" goto :yes
if /I "%c%" EQU "Y" goto :yes
if /I "%c%" EQU "N" goto :no
echo "%c%" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit.
goto :choice

:no

echo.
echo      Exiting...
echo.
echo      Pull the latest, then re-run this script.
echo.
exit

:yes

cd ..\..\
SETLOCAL ENABLEDELAYEDEXPANSION
SET "counta=1"
FOR /F "tokens=* USEBACKQ" %%F IN (`git remote`) DO (
  SET vara!counta!=%%F
  SET /a counta=!counta!+1
)

SET "countb=1"
  FOR /F "tokens=* USEBACKQ" %%F IN (`git config --local --list`) DO (
    SET varb!countb!=%%F
    SET /a countb=!countb!+1
  )

REM Don't proceed if the origin is not set.
if not defined vara1 (
  echo origin is not set
  echo add origin, then re-run this script
  ENDLOCAL
  exit
) else (
  echo %vara1% is set
)
set "origintest=good_if_not_changed"
set "upstreamtest=different_if_not_changed"
for /l %%b in (1,1,%countb%) do (
  REM Don't proceed if the origin is the intended upstream.
  IF "!varb%%b!"=="remote.origin.url=https://github.com/pankosmia/desktop-app-template.git" (
    set "origintest=stop_because_is_set_to_desired_upstream"
    echo.
    echo origin is set to https://github.com/pankosmia/desktop-app-template.git
    echo This script is not meant to be run on this repo as it expects that that to be the upstream, not the origin.
    echo.
    echo Exiting ....
    echo.
    goto :end
  )
  REM This assumes the origin record will always be returned on an earlier line that the upstream record.
  REM Proceed if the origin is set.
  IF "%origintest%"=="good_if_not_changed" (
      REM Proceed if the upstream is already set as expected.
    IF "!varb%%b!"=="remote.upstream.url=https://github.com/pankosmia/desktop-app-template.git" (
      set "upstreamtest=as_expected"
      echo upstream is confirmed as set to https://github.com/pankosmia/desktop-app-template.git
      set up=%%b
      call :sync
      goto :end
    )
  )
)
REM This assumes the origin record will always be returned on an earlier line that the upstream record.
REM Proceed if the origin is set.
if "%origintest%"=="good_if_not_changed" (
  REM Set the upstream and proceed if it is not yet set.
  if not defined vara2 (
    git remote add upstream https://github.com/pankosmia/desktop-app-template.git
    set "upstreamtest=set"
    echo upstream has been set to https://github.com/pankosmia/desktop-app-template.git
    call :sync
    goto :end
  )
)
REM Don't proceed if the upstream is set elsewhere.
if "%upstreamtest%"=="different_if_not_changed" (
  echo.
  echo The upstream is set to: !varb%up%!
  echo However, this script is written for an upstream that is set to https://github.com/pankosmia/desktop-app-template.git
  echo.
  goto :end
)

:sync
git fetch upstream
git merge --no-log --no-ff --no-commit upstream/main

REM --- Build the list of files we want to protect from the merge ---
SET "PROTECTED_FILES=package-lock.json"
SET "PROTECTED_FILES=%PROTECTED_FILES% globalBuildResources\favicon.ico"
SET "PROTECTED_FILES=%PROTECTED_FILES% globalBuildResources\icon.icns"
SET "PROTECTED_FILES=%PROTECTED_FILES% globalBuildResources\icon.ico"
SET "PROTECTED_FILES=%PROTECTED_FILES% globalBuildResources\linux_icon.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% globalBuildResources\favicon.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% globalBuildResources\favicon@1.25x.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% globalBuildResources\favicon@1.5x.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% globalBuildResources\favicon@1.75x.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% globalBuildResources\favicon@2x.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% globalBuildResources\theme.json"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_favicon_ico\favicon_16x16.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_favicon_ico\favicon_32x32.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_icns\icon_128x128.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_icns\icon_128x128@2x.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_icns\icon_16x16.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_icns\icon_16x16@2x.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_icns\icon_256x256.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_icns\icon_256x256@2x.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_icns\icon_32x32.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_icns\icon_32x32@2x.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_icns\icon_512x512.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_icns\icon_512x512@2x.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_ico\win_icon_16x16.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_ico\win_icon_256x256.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_ico\win_icon_32x32.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\building_blocks\for_icon_ico\win_icon_48x48.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\favicon.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\mac_icon.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\win_icon.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\favicon.svg"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\mac_icon.svg"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\win_icon.svg"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\artwork\favicon_transparent_square_blue-turqoise.psd"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\artwork\logo_512.png"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\artwork\logo_favicon_inkscape.svg"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\artwork\logo_inkscape.svg"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\artwork\logo_macos.psd"
SET "PROTECTED_FILES=%PROTECTED_FILES% branding\source\artwork\logo_windows.psd"

REM --- Get the list of files actually staged by the merge ---
SET "excluded_count=0"
SET "excluded_list="

REM --- For each staged file, check if it's in our protected list ---
FOR /F "tokens=* USEBACKQ" %%S IN (`git diff --name-only --cached`) DO (
  REM git outputs forward slashes; convert to backslashes for comparison
  SET "staged_file=%%S"
  SET "staged_file=!staged_file:/=\!"
  SET "was_protected=0"
  FOR %%P IN (%PROTECTED_FILES%) DO (
    IF /I "!staged_file!"=="%%P" (
      SET "was_protected=1"
    )
  )
  IF "!was_protected!"=="1" (
    git reset "%%S" >nul 2>&1
    git checkout "%%S" >nul 2>&1
    SET /a excluded_count=!excluded_count!+1
    SET "excluded_list=!excluded_list!      - !staged_file!!LF!"
  )
)

REM --- Print a clean summary ---
echo.
IF !excluded_count! EQU 0 (
  echo      No protected files were affected by this sync.
) ELSE (
  echo      !excluded_count! protected file(s) were excluded from this sync:
  echo.
  REM Print each excluded file
  FOR /F "tokens=* USEBACKQ" %%S IN (`git diff --name-only`) DO (
    SET "unstaged=%%S"
    SET "unstaged=!unstaged:/=\!"
    FOR %%P IN (%PROTECTED_FILES%) DO (
      IF /I "!unstaged!"=="%%P" (
        echo        - !unstaged!
      )
    )
  )
  echo.
  echo      These files were reset to preserve this repo's versions.
)
echo.
echo      *******************************************************************************
echo      * Now review staged changes, and commit if there are no conflicts, then push. *
echo      *******************************************************************************
echo.
exit /b
