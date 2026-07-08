@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\pull.ps1"
endlocal
