param(
  [int]$PollIntervalSeconds = 60,
  [int]$PublishIntervalMinutes = 10
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "automation-common.ps1")

$context = Get-AutomationContext -TaskName "automation-runner"
Ensure-AutomationDirectories -Context $context
Add-PortableNodeToPath -RepoRoot $context.RepoRoot
$lock = Acquire-AutomationLock -Context $context

if ($null -eq $lock) {
  exit 0
}

$publishMarker = Join-Path $context.StateRoot "last-auto-publish.txt"
$vaultPath = Join-Path $context.RepoRoot "content"

function Get-MarkerTime {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }

  try {
    return [DateTime]::Parse((Get-Content -LiteralPath $Path -Raw).Trim())
  } catch {
    return $null
  }
}

function Set-MarkerTime {
  param([string]$Path)
  Set-Content -LiteralPath $Path -Value (Get-Date).ToString("o") -Encoding ASCII
}

function Invoke-AutomationScript {
  param(
    [string]$ScriptName
  )

  $scriptPath = Join-Path $PSScriptRoot $ScriptName
  $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-AutomationLog -Context $context -Level "ERROR" -Message "$ScriptName failed: $(($output | Out-String).Trim())"
  }
}

function Test-ObsidianVaultActive {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedVaultPath
  )

  $normalizedVault = $ExpectedVaultPath.ToLowerInvariant()
  $vaultName = [System.IO.Path]::GetFileName($ExpectedVaultPath).ToLowerInvariant()

  try {
    $processes = Get-CimInstance Win32_Process -Filter "Name = 'Obsidian.exe'" -ErrorAction Stop
  } catch {
    $processes = @()
  }

  if (-not $processes -or $processes.Count -eq 0) {
    return $false
  }

  foreach ($process in $processes) {
    $commandLine = "$($process.CommandLine)".ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($commandLine) -and $commandLine.Contains($normalizedVault.ToLowerInvariant())) {
      return $true
    }
  }

  $windowedProcesses = Get-Process Obsidian -ErrorAction SilentlyContinue
  foreach ($process in $windowedProcesses) {
    $title = "$($process.MainWindowTitle)".ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($title) -and $title.Contains(" - $vaultName - obsidian")) {
      return $true
    }
  }

  return $false
}

try {
  Write-AutomationLog -Context $context -Level "INFO" -Message "Runner started."
  $wasActive = $false

  while ($true) {
    $now = Get-Date
    $isActive = Test-ObsidianVaultActive -ExpectedVaultPath $vaultPath
    $lastPublish = Get-MarkerTime -Path $publishMarker

    if ($isActive -and -not $wasActive) {
      Write-AutomationLog -Context $context -Level "INFO" -Message "Obsidian activity detected. Running initial pull."
      Invoke-AutomationScript -ScriptName "auto-pull.ps1"
      Set-MarkerTime -Path $publishMarker
      $lastPublish = Get-Date
    }

    if ($isActive -and ($null -eq $lastPublish -or (($now - $lastPublish).TotalMinutes -ge $PublishIntervalMinutes))) {
      Write-AutomationLog -Context $context -Level "INFO" -Message "Obsidian is open. Running scheduled auto publish."
      Invoke-AutomationScript -ScriptName "auto-publish.ps1"
      Set-MarkerTime -Path $publishMarker
    }

    if (-not $isActive -and $wasActive) {
      Write-AutomationLog -Context $context -Level "INFO" -Message "Obsidian closed. Running final auto publish."
      Invoke-AutomationScript -ScriptName "auto-publish.ps1"
      Set-MarkerTime -Path $publishMarker
    }

    $wasActive = $isActive
    Start-Sleep -Seconds $PollIntervalSeconds
  }
} finally {
  Release-AutomationLock -LockHandle $lock
}
