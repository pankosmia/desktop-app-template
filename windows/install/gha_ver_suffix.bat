@echo off
REM This file is used by GHA to send a version suffix argument.
REM The suffix is appended to app.version in app_config.json for the selected tier.
REM Usage: gha_ver_suffix.bat <suffix> [tier]
REM   Tier: 2nd argument, else tiers.default.

IF "%~1"=="" goto :eof

setlocal
set "suffix=%~1"
set "APP_CONFIG=..\..\app_config.json"
set "APP_CONFIG_TMP=..\..\app_config.json.tmp"

set "tier=%~2"
if not defined tier for /f "usebackq delims=" %%T in (`jq -r ".tiers.default" "%APP_CONFIG%"`) do set "tier=%%T"

echo.
echo   Using version suffix "%suffix%" for tier "%tier%"

jq -e --arg t "%tier%" "[.app.version[] | select(.branches | index($t))] | length == 1" "%APP_CONFIG%" >nul
if errorlevel 1 (
  echo   app.version must have exactly one entry for tier "%tier%"
  exit /b 1
)

jq --arg t "%tier%" --arg s "%suffix%" "(.app.version[] | select(.branches | index($t)) | .value) |= . + \"-\" + $s" "%APP_CONFIG%" > "%APP_CONFIG_TMP%"
if errorlevel 1 (
  del "%APP_CONFIG_TMP%" 2>nul
  echo   Failed to update app_config.json
  exit /b 1
)
move /y "%APP_CONFIG_TMP%" "%APP_CONFIG%" >nul
endlocal
