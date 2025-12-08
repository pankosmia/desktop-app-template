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

REM Build without cleaning if the -c positional argument is provided in either #1 or #2 or #3
REM Do not ask if the server is off if the -s positional argument is provided in either #1 or #2 or #3
REM Debug server if the -d positional argument is provided in either #1 or #2 or #3
:loop
IF "%~1"=="" (
  goto :continue
) ELSE IF "%~1"=="-c" (
  set buildWithoutClean=%~1
) ELSE IF "%~1"=="-s" (
  set askIfOff=%~1
) ELSE IF "%~1"=="-d" (
  set debugServer=%~1
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

REM Assign default value if -d is not present
if not defined %debugServer (
  set debugServer=-no
  set buildCommand=cargo build --release
  set "search=local_server/target/debug"
  set "replace=local_server/target/release"
) else if "%debugServer%"=="-d" (
  set buildCommand=cargo build
  set "search=local_server/target/release"
  set "replace=local_server/target/debug"
)

REM Ensure buildSpec.json has the location for the indicated server build type
@echo off
setlocal enabledelayedexpansion

set "configFile=..\..\buildSpec.json"
set "tmpFile=..\..\buildSpec.bak"
copy %configFile% %tmpFile%


(for /f "tokens=*" %%a in ('type "%tmpFile%" ^| findstr /n "^"') do (
    set "line=%%a"
    set "line=!line:*:=!"

    if defined line (
        set "line=!line:%search%=%replace%!"
        echo(!line!
    ) else echo.
)) > "%configFile%"

endlocal

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
  if not exist ..\..\local_server\target\debug\local_server.exe (
    echo "Building local server..."
    cd ..\..\local_server
    echo "%buildCommand%"
    %buildCommand%
    cd ..\windows\scripts
  )
)
if not exist ..\build (
  echo "Assembling build environment..."
  node build.js
)
