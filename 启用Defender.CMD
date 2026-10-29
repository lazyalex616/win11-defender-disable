@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Bin\Switch.ps1" -Mode Enable
set "result=%errorlevel%"
echo.
pause
exit /b %result%
