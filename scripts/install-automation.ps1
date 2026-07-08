param(
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$logsDir = Join-Path $repoRoot "logs\automation"
$stateDir = Join-Path $repoRoot ".automation"

foreach ($path in @($logsDir, $stateDir)) {
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
  }
}

$pullScript = Join-Path $PSScriptRoot "auto-pull.ps1"
$publishScript = Join-Path $PSScriptRoot "auto-publish.ps1"
$runnerScript = Join-Path $PSScriptRoot "automation-runner.ps1"
$psExe = "powershell.exe"
$startupFile = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\jjagong_blog_automation.bat"

$taskDefs = @(
  @{
    Name = "jjagong_blog_automation_runner"
    Args = @("/Create", "/F", "/TN", "jjagong_blog_automation_runner", "/SC", "ONLOGON", "/RL", "LIMITED", "/TR", "$psExe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runnerScript`"")
  }
)

function Install-StartupFallback {
  param(
    [switch]$PreviewOnly
  )

  $content = @(
    "@echo off",
    "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runnerScript`""
  )

  if ($PreviewOnly) {
    Write-Host "Would create startup launcher: $startupFile"
    return
  }

  Set-Content -LiteralPath $startupFile -Value $content -Encoding ASCII
  Write-Host "Installed startup launcher: $startupFile"
}

$taskInstallFailed = $false

foreach ($task in $taskDefs) {
  if ($DryRun) {
    Write-Host "Would register task: $($task.Name)"
    continue
  }

  & schtasks.exe @($task.Args) | Out-Null
  if ($LASTEXITCODE -ne 0) {
    $taskInstallFailed = $true
    break
  }
  Write-Host "Registered task: $($task.Name)"
}

if ($DryRun) {
  Install-StartupFallback -PreviewOnly
  Write-Host "Automation installation dry run complete."
  exit 0
}

if ($taskInstallFailed) {
  Write-Warning "Task Scheduler registration failed. Falling back to Startup-based automation."
  Install-StartupFallback
} else {
  Write-Host "Automation installation complete via Task Scheduler."
}
