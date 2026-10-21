@echo off
pushd "%~dp0"

REM --- Guard: the demo requires a clean state ---
if exist "%USERPROFILE%\pankosmia\%%APP_SHORT_NAME%%" (
    echo.
    echo The folder "%USERPROFILE%\pankosmia\%%APP_SHORT_NAME%%" exists ("~\\pankosmia\%%APP_SHORT_NAME%%"^).
    echo For this demonstration it must NOT exist.
    echo.
    echo Please delete the following folder, then run this script again:
    echo     "%USERPROFILE%\pankosmia\%%APP_SHORT_NAME%%"
    echo     ("~\pankosmia\%%APP_SHORT_NAME%%"^)
    echo.
    popd
    pause
    exit /b 1
)

echo Launching...
"%~dp0%%APP_NAME%%\electron\electron.exe" "%~dp0%%APP_NAME%%\electron"

echo.
echo The app has exited. Review any server start error above.
popd
pause
