@echo off
pushd "%~dp0"

REM Has the first (unpatched) launch already created the working dir?
if exist "%USERPROFILE%\pankosmia\%%APP_SHORT_NAME%%" (
    REM Yes -> do setup now, if it hasn't been done yet
    if exist "%~dp0Initialize-PortableApp.ps1" (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Initialize-PortableApp.ps1"
        if errorlevel 1 (
            echo Setup failed. Not launching.
            timeout /t 10 /nobreak >nul
            exit /b 1
        )
    )
)

echo Launching %%APP_NAME%% in another window...
cmd /c start "" "%~dp0%%APP_NAME%%\electron\electron.exe" "%~dp0%%APP_NAME%%\electron"
timeout /t 2 /nobreak >nul
popd
exit
