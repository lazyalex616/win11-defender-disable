@echo off
setlocal
if /i "%~1"=="Disable" goto run
if /i "%~1"=="Enable" goto run
echo Usage: DEFENDER.CMD Disable ^| Enable
exit /b 2
:run
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Switch.ps1" -Mode "%~1"
exit /b %errorlevel%
