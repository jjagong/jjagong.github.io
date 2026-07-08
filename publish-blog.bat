@echo off
setlocal
set /p MSG=Commit message (default: Update blog): 
if "%MSG%"=="" set MSG=Update blog
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\publish.ps1" -Message "%MSG%"
endlocal
