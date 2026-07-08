param()

$ErrorActionPreference = "Stop"

$taskNames = @(
  "jjagong_blog_automation_runner"
)

$startupFile = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\jjagong_blog_automation.bat"

foreach ($taskName in $taskNames) {
  & schtasks.exe /Delete /TN $taskName /F 2>$null | Out-Null
  Write-Host "Removed task (if present): $taskName"
}

if (Test-Path -LiteralPath $startupFile) {
  Remove-Item -LiteralPath $startupFile -Force
  Write-Host "Removed startup launcher: $startupFile"
}

Write-Host "Automation removal complete."
