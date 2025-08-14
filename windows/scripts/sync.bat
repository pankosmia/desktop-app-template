@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\sync.bat
REM Optional arguments: .\sync.bat -p
REM or: .\sync.bat -P
REM To pre-confirm the server is off, so as to not be asked.

echo.
:choice
IF "%~1"=="-p" (
  goto :yes
) ELSE IF "%~1"=="-P" (
  goto :yes
) ELSE (
  set /P c=Are you certain the latest is already pulled?[Y/N y/n]?
)
if /I "%c%" EQU "Y" goto :yes
if /I "%c%" EQU "N" goto :no
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
SET counta=1
FOR /F "tokens=* USEBACKQ" %%F IN (`git remote`) DO (
  SET vara!counta!=%%F
  SET /a counta=!counta!+1
)

SET countb=1
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
set origintest=good_if_not_changed
set upstreamtest=different_if_not_changed
for /l %%b in (1,1,%countb%) do (
  REM Don't proceed if the origin is the intended upstream.
  IF "!varb%%b!"=="remote.origin.url=https://github.com/pankosmia/desktop-app-template.git" (
    set origintest=stop_because_is_set_to_desired_upstream
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
      set upstreamtest=as_expected
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
    set upstreamtest=set
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
echo README.md:
git reset README.md
git checkout README.md
echo package.json:
git reset package.json
git checkout package.json
echo package-lock.json:
git reset package-lock.json
git checkout package-lock.json
echo app_config.env:
git reset app_config.env
git checkout app_config.env
echo globalBuildResources\favicon.ico:
git reset globalBuildResources\favicon.ico
git checkout globalBuildResources\favicon.ico
echo globalBuildResources\theme.json:
git reset globalBuildResources\theme.json
git checkout globalBuildResources\theme.json
echo.
echo      *******************************************************************************
echo      * Files expected to differ have been excluded from the sync.                  *
echo      * Now review staged changes, and commit if there are no conflicts, then push. *
echo      *******************************************************************************
echo.
exit /b

:end
cd windows\scripts\
ENDLOCAL