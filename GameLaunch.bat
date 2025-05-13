@echo off
setlocal
rem Call the PowerShell script with the provided argument

rem Uncomment and use below to show CMD window
powershell.exe -ExecutionPolicy Bypass -File "GameLaunch.ps1" "%~1"

rem Uncomment and use below to hide CMD window
rem powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "GameLaunch.ps1" "%~1"
:end