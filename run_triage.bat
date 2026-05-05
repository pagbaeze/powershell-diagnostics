@echo off
echo Running Slow Computer Triage Script...
powershell -ExecutionPolicy Bypass -File "%~dp0Slow-Computer-Triage.ps1"
echo.
echo Script finished. Opening report...
start "" "%~dp0slow_computer_triage_log.txt"
echo.
pause