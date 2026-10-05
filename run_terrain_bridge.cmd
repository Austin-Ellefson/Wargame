@echo off
setlocal
pushd "%~dp0"
if not exist ".venv\Scripts\python.exe" goto missing_setup
echo Creates or rebuilds terrain files for the chosen battle.
echo P: offline plan and footprint. F: fetch real OSM and elevation data.
choice /C PF /M "Choose a mode"
if errorlevel 2 goto fetch
set "fetch_flag="
goto run
:fetch
set "fetch_flag=--fetch"
:run
if "%~1"=="" goto latest
".venv\Scripts\python.exe" -m terrain_bridge "%~1" %fetch_flag% --overwrite
goto done
:latest
".venv\Scripts\python.exe" -m terrain_bridge --latest %fetch_flag% --overwrite
:done
set "result=%ERRORLEVEL%"
echo.
echo Open the printed preview.html path to inspect the package.
echo Read CMAUTOEDITOR.md inside that folder for the manual CMBS handoff.
popd
pause
exit /b %result%
:missing_setup
echo Run setup_terrain_bridge.cmd first.
popd
pause
exit /b 2
