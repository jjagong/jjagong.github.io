@echo off
setlocal
cd /d "%~dp0"
set "NODE_HOME="
for /d %%D in ("%~dp0.local-node\node-*") do (
  set "NODE_HOME=%%~fD"
)
if defined NODE_HOME (
  set "PATH=%NODE_HOME%;%PATH%"
  call "%NODE_HOME%\npx.cmd" quartz build --serve
) else (
  npx quartz build --serve
)
endlocal
