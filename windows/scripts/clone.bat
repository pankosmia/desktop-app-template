@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\clone.bat
REM Usage: .\clone.bat [-s] [devRepos|qaRepos|mainRepos]
REM   -s         Use ssh instead of https
REM   devRepos   Clone only the repos used by the dev tier  (likewise qaRepos, mainRepos)
REM   (none)     Clone every asset and client repo listed in app_config.json
REM Cloning does NOT select dev/qa/main branches. Each repo is left on its default branch.
REM Run .\build_clients.bat [dev|qa|main] to check out the branches for a tier.

echo.
setlocal

set "METHOD=https://github.com/"
set "TIER="

:args
if "%~1"=="" goto :args_done
if /I "%~1"=="-s" (
  set "METHOD=git@github.com:"
) else if /I "%~1"=="devRepos" (
  set "TIER=dev"
) else if /I "%~1"=="qaRepos" (
  set "TIER=qa"
) else if /I "%~1"=="mainRepos" (
  set "TIER=main"
) else (
  echo Unknown argument "%~1". Use -s, devRepos, qaRepos, or mainRepos.
  exit /b 1
)
shift
goto :args
:args_done

set "CONFIG=%~dp0..\..\app_config.json"
if not exist "%CONFIG%" (
  echo app_config.json not found at "%CONFIG%"
  exit /b 1
)
where jq >nul 2>&1
if errorlevel 1 (
  echo jq was not found on PATH.
  exit /b 1
)

if defined TIER (
  echo Cloning repos used by the %TIER% tier.
  echo Note: cloning does not check out %TIER% branches. Repos stay on their default branch.
) else (
  echo Cloning every repo listed in app_config.json.
)
echo.

REM Clone into the parent of this repo
pushd "%~dp0..\..\.."

for /f "usebackq delims=" %%R in (`jq -r --arg t "%TIER%" ".assets[] | select(($t | length) == 0 or (.branches | index($t))) | .repo" "%CONFIG%"`) do call :clone Asset %%R
for /f "usebackq delims=" %%R in (`jq -r --arg t "%TIER%" ".clients[] | select(($t | length) == 0 or (.branches | index($t))) | .repo" "%CONFIG%"`) do call :clone Client %%R

popd

echo Done. Repos are on their default branches.
if defined TIER (
  echo To check out the %TIER% branches, run: .\build_clients.bat %TIER%
) else (
  echo To check out a tier's branches, run: .\build_clients.bat [dev^|qa^|main]
)

endlocal
exit /b 0


:clone
REM %~1 = Asset or Client, %~2 = repo name
echo "############################### BEGIN %~1: %~2 ###############################"
if not exist "%~2" (
  git clone %METHOD%pankosmia/%~2.git
) else (
  echo "Directory already exists; Not cloned."
)
echo "################################ END %~1: %~2 ################################"
echo.
exit /b 0
