param(
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "automation-common.ps1")

$context = Get-AutomationContext -TaskName "auto-pull"
Ensure-AutomationDirectories -Context $context
Add-PortableNodeToPath -RepoRoot $context.RepoRoot
$lock = Acquire-AutomationLock -Context $context

if ($null -eq $lock) {
  Write-AutomationLog -Context $context -Level "WARN" -Message "Skipped: another automation run is already active."
  exit 0
}

try {
  Test-RepositoryIdentity -Context $context

  $statusEntries = Get-GitStatusEntries -RepoRoot $context.RepoRoot
  if ($statusEntries.Count -gt 0) {
    $dirtyPaths = (Get-UniquePaths -Entries $statusEntries) -join ", "
    Write-AutomationLog -Context $context -Level "WARN" -Message "Skipped pull: working tree is dirty ($dirtyPaths)."
    exit 0
  }

  if ($DryRun) {
    Write-AutomationLog -Context $context -Level "INFO" -Message "Dry run: would fetch origin/main and fast-forward pull if behind."
    exit 0
  }

  Invoke-Git -RepoRoot $context.RepoRoot -Arguments @("fetch", "origin", "main") | Out-Null
  $delta = Get-GitRevisionDelta -RepoRoot $context.RepoRoot

  if ($delta.Ahead -gt 0) {
    Write-AutomationLog -Context $context -Level "WARN" -Message "Skipped pull: local branch is ahead of origin by $($delta.Ahead) commit(s)."
    exit 0
  }

  if ($delta.Behind -eq 0) {
    Write-AutomationLog -Context $context -Level "INFO" -Message "No remote changes detected."
    exit 0
  }

  Write-AutomationLog -Context $context -Level "INFO" -Message "Pulling $($delta.Behind) remote commit(s)."
  Invoke-Git -RepoRoot $context.RepoRoot -Arguments @("pull", "--ff-only", "origin", "main") | Out-Null
  Invoke-Git -RepoRoot $context.RepoRoot -Arguments @("status", "--short") | Out-Null
  Push-Location $context.RepoRoot
  try {
    $output = & npm ci 2>&1
    if ($LASTEXITCODE -ne 0) {
      $text = ($output | Out-String).Trim()
      throw "npm ci failed: $text"
    }
  } finally {
    Pop-Location
  }
  Write-AutomationLog -Context $context -Level "INFO" -Message "Pull completed successfully."
} catch {
  Write-AutomationLog -Context $context -Level "ERROR" -Message $_.Exception.Message
  exit 1
} finally {
  Release-AutomationLock -LockHandle $lock
}
