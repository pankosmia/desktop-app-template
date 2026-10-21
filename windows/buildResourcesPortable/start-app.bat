@echo off
pushd "%~dp0"

REM Does the working dir already exist in the portable app?
if not exist "%~dp0pankosmia\%%APP_SHORT_NAME%%" (
    REM If not, then does a user_setting.json already exist that does not use the portable app repo_dir?
    if exist "%USERPROFILE%\pankosmia\%%APP_SHORT_NAME%%\user_settings.json" (
        findstr /c:"\"repo_dir\": \"..\\\\pankosmia_repos\"" "%USERPROFILE%\pankosmia\%%APP_SHORT_NAME%%\user_settings.json" >nul
        if errorlevel 1 (
            echo Please delete the following folder, then run this script again:
            echo     "%USERPROFILE%\pankosmia\%%APP_SHORT_NAME%%"
            echo     ("~\pankosmia\%%APP_SHORT_NAME%%"^)
            echo.
            popd
            pause
            exit /b 1
        )
    )
)

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
