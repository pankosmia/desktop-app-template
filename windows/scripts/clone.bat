@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\clone.bat
REM Usage: .\clone.bat [-s] [tier | tierRepos]
REM   -s          Use ssh instead of https
REM   <tier>      Clone the repos used by a tier from tiers.order (e.g. dev, qa, main)
REM   <tier>Repos Same as <tier> (e.g. devRepos, qaRepos, mainRepos)
REM   (none)      Clone the repos used by tiers.default
REM Cloning does NOT select dev/qa/main branches. Each repo is left on its default branch.

echo.
setlocal

set "METHOD=https://github.com/"
set "tier="

set "APP_CONFIG=%~dp0..\..\app_config.json"
if not exist "%APP_CONFIG%" (
  echo app_config.json not found at "%APP_CONFIG%"
  exit /b 1
)

where jq >nul 2>&1
if errorlevel 1 (
  echo jq was not found on PATH.
  exit /b 1
)

REM Read tiers.order from app_config.json (space-separated list)
set "tiers="
for /f "usebackq delims=" %%T in (`jq -r ".tiers.order[]" "%APP_CONFIG%"`) do call set "tiers=%%tiers%% %%T"
if not defined tiers (
  echo.
  echo      Could not read tiers.order from %APP_CONFIG%
  echo.
  exit /b 1
)

REM Parse arguments: -s, and at most one tier (tier or tierRepos)
:args
if "%~1"=="" goto :args_done

if /I "%~1"=="-s" (
  set "METHOD=git@github.com:"
  shift
  goto :args
)

set "isTier="
for %%T in (%tiers%) do (
  if /I "%~1"=="%%T" set "isTier=%%T"
  if /I "%~1"=="%%TRepos" set "isTier=%%T"
)

if not defined isTier (
  echo Unknown argument "%~1". Use -s, or one of:%tiers% ^(optionally with a Repos suffix^)
  exit /b 1
)
if defined tier (
  echo.
  echo      Only one tier may be given ^(got "%tier%" and "%isTier%"^). Use one of:%tiers% ^(optionally with a Repos suffix^)
  echo.
  exit /b 1
)
set "tier=%isTier%"
shift
goto :args
:args_done

REM Default tier is tiers.default; must still be in tiers.order
if not defined tier for /f "usebackq delims=" %%T in (`jq -r ".tiers.default" "%APP_CONFIG%"`) do set "tier=%%T"
set "isTier="
for %%T in (%tiers%) do if /I "%tier%"=="%%T" set "isTier=%%T"
if not defined isTier (
  echo.
  echo      Tier "%tier%" is not listed in tiers.order. Use one of:%tiers%
  echo.
  exit /b 1
)

echo Cloning repos used by the %tier% tier.
echo Note: cloning does not check out %tier% branches. Repos stay on their default branch.
echo.

REM Clone into the parent of this repo
pushd "%~dp0..\..\.."

for /f "usebackq delims=" %%R in (`jq -r --arg t "%tier%" ".assets[] | select(.branches | index($t)) | .repo" "%APP_CONFIG%"`) do call :clone Asset %%R
for /f "usebackq delims=" %%R in (`jq -r --arg t "%tier%" ".clients[] | select(.branches | index($t)) | .repo" "%APP_CONFIG%"`) do call :clone Client %%R

popd

echo Done. Repos are on their default branches for the %tier% tier.
echo To check out a tier's branches, run: .\build_clients.bat ^<tier^>

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
