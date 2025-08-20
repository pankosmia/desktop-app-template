@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\build_server.bat
REM Git hub actions use this with optional arguments of: .\build_server.bat -c
REM because it is a brand new clean environment without need for any prior build to be removed.

if not exist ..\..\buildSpec.json set runSetup=1
if not exist ..\..\globalBuildResources\i18nPatch.json set runSetup=1
if not exist ..\buildResources\setup\app_setup.json set runSetup=1
if defined %runSetup (
  cmd /c .\app_setup.bat
  echo.
  echo   +-----------------------------------------------------------------------------+
  echo   ^| Config files were rebuilt by `./app_setup.bsh` as one or more were missing. ^|
  echo   +-----------------------------------------------------------------------------+
  echo.
)

REM Build without cleaning if the -c positional argument is provided in either #1 or #2
REM Do not ask if the server is off if the -s positional argument is provided in either #1 or #2
:loop
IF "%~1"=="" (
  goto :continue
) ELSE IF "%~1"=="-c" (
  set buildWithoutClean=%~1
) ELSE IF "%~1"=="-s" (
  set askIfOff=%~1
)
shift
goto :loop

:continue

REM Assign default value if -c is not present
if not defined %buildWithoutClean (
  set buildWithoutClean=-no
)

REM Assign default value if -s is not present
if not defined %askIfOff (
  set askIfOff=-yes
)

REM Do not clean if the -c positional argument is provided
IF NOT "%buildWithoutClean%"=="-c" (
  REM Do not ask if the server is off if the -s positional argument is provided
  IF "%askIfOff%"=="-s" (
    call .\clean.bat -s
  ) ELSE (
    call .\clean.bat
  )
)

if not exist ..\..\local_server\target\release\local_server.exe (
    echo "Building local server..."
    cd ..\..\local_server
    cargo build --release
    cd ..\windows\scripts
)
if not exist ..\build (
  echo "Assembling build environment..."
  node build.js
)
