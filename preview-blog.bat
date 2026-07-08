@echo off
setlocal
cd /d "%~dp0"
npx quartz build --serve
endlocal
