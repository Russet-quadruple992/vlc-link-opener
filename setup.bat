@echo off
:: Runs setup.ps1 bypassing the execution policy to make it double-clickable
powershell -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
echo.
pause
