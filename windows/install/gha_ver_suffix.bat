@echo off
REM This file is used by GHA to send a version suffix argument.
REM The suffix is appended to app.version in app_config.json for the selected tier.
REM Usage: gha_ver_suffix.bat <suffix> [tier]
REM   Tier: 2nd argument, else APP_TIER, else BRANCHES, else tiers.default.

IF "%~1"=="" goto :eof

setlocal
set "suffix=%~1"
set "configFile=..\..\app_config.json"
set "configTmp=..\..\app_config.json.tmp"

set "tier=%~2"
if not defined tier set "tier=%APP_TIER%"
if not defined tier set "tier=%BRANCHES%"
if not defined tier for /f "usebackq delims=" %%T in (`jq -r ".tiers.default" "%configFile%"`) do set "tier=%%T"

echo.
echo   Using version suffix "%suffix%" for tier "%tier%"

jq -e --arg t "%tier%" "[.app.version[] | select(.branches | index($t))] | length == 1" "%configFile%" >nul
if errorlevel 1 (
  echo   app.version must have exactly one entry for tier "%tier%"
  exit /b 1
)

jq --arg t "%tier%" --arg s "%suffix%" "(.app.version[] | select(.branches | index($t)) | .value) |= . + \"-\" + $s" "%configFile%" > "%configTmp%"
if errorlevel 1 (
  del "%configTmp%" 2>nul
  echo   Failed to update app_config.json
  exit /b 1
)
move /y "%configTmp%" "%configFile%" >nul
endlocal
