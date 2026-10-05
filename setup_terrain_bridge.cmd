@echo off
setlocal
pushd "%~dp0"
if exist ".venv\Scripts\python.exe" goto install
where py >nul 2>&1
if errorlevel 1 goto python_fallback
py -3 -m venv .venv
if errorlevel 1 goto failed
goto install
:python_fallback
where python >nul 2>&1
if errorlevel 1 goto missing_python
python -m venv .venv
if errorlevel 1 goto failed
:install
".venv\Scripts\python.exe" -m pip install -r terrain_bridge\requirements.txt
if errorlevel 1 goto failed
echo.
echo Ready. Run run_terrain_bridge.cmd after exporting a battle in Godot.
popd
pause
exit /b 0
:missing_python
echo Install Python 3.11 or 3.12 for Windows from https://www.python.org/downloads/windows/
echo Include its launcher or add Python to PATH, then run this setup again.
:failed
echo Setup did not finish. Read the error above before retrying.
popd
pause
exit /b 1
