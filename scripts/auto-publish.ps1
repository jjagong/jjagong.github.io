param(
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "automation-common.ps1")

$context = Get-AutomationContext -TaskName "auto-publish"
Ensure-AutomationDirectories -Context $context
Add-PortableNodeToPath -RepoRoot $context.RepoRoot
$lock = Acquire-AutomationLock -Context $context

if ($null -eq $lock) {
  Write-AutomationLog -Context $context -Level "WARN" -Message "Skipped: another automation run is already active."
  exit 0
}

try {
  Test-RepositoryIdentity -Context $context

  $preStatus = Get-GitStatusEntries -RepoRoot $context.RepoRoot
  if ($preStatus.Count -eq 0) {
    Write-AutomationLog -Context $context -Level "INFO" -Message "No local changes detected."
    exit 0
  }

  $contentChanges = @($preStatus | Where-Object { Test-ContentPath -Path $_.Path })
  $riskyPreChanges = @($preStatus | Where-Object { -not (Test-ContentPath -Path $_.Path) })

  if ($riskyPreChanges.Count -gt 0) {
    $paths = (Get-UniquePaths -Entries $riskyPreChanges) -join ", "
    Write-AutomationLog -Context $context -Level "WARN" -Message "Skipped publish: non-content changes are present ($paths)."
    exit 0
  }

  if ($contentChanges.Count -eq 0) {
    Write-AutomationLog -Context $context -Level "INFO" -Message "Skipped publish: content changes were not detected."
    exit 0
  }

  if ($DryRun) {
    $paths = (Get-UniquePaths -Entries $contentChanges) -join ", "
    Write-AutomationLog -Context $context -Level "INFO" -Message "Dry run: would build and publish changes for $paths"
    exit 0
  }

  Invoke-Git -RepoRoot $context.RepoRoot -Arguments @("fetch", "origin", "main") | Out-Null
  $delta = Get-GitRevisionDelta -RepoRoot $context.RepoRoot

  if ($delta.Behind -gt 0) {
    Write-AutomationLog -Context $context -Level "WARN" -Message "Skipped publish: origin/main is ahead by $($delta.Behind) commit(s). Run pull first."
    exit 0
  }

  if ($delta.Ahead -gt 0) {
    Write-AutomationLog -Context $context -Level "WARN" -Message "Skipped publish: local branch is already ahead of origin by $($delta.Ahead) commit(s)."
    exit 0
  }

  Write-AutomationLog -Context $context -Level "INFO" -Message "Running Quartz build before auto publish."
  Invoke-RepoScript -RepoRoot $context.RepoRoot -ScriptPath (Join-Path $PSScriptRoot "build-site.ps1") | Out-Null

  $postStatus = Get-GitStatusEntries -RepoRoot $context.RepoRoot
  if ($postStatus.Count -eq 0) {
    Write-AutomationLog -Context $context -Level "INFO" -Message "Nothing changed after build."
    exit 0
  }

  $stageable = @($postStatus | Where-Object { Test-AutoPublishPath -Path $_.Path })
  $riskyAfterBuild = @($postStatus | Where-Object { -not (Test-AutoPublishPath -Path $_.Path) })

  if ($riskyAfterBuild.Count -gt 0) {
    $paths = (Get-UniquePaths -Entries $riskyAfterBuild) -join ", "
    Write-AutomationLog -Context $context -Level "WARN" -Message "Skipped publish after build: unexpected paths changed ($paths)."
    exit 0
  }

  if ($stageable.Count -eq 0) {
    Write-AutomationLog -Context $context -Level "INFO" -Message "No publishable changes detected."
    exit 0
  }

  foreach ($path in (Get-UniquePaths -Entries $stageable)) {
    Invoke-Git -RepoRoot $context.RepoRoot -Arguments @("add", "-A", "--", $path) | Out-Null
  }

  $staged = Invoke-Git -RepoRoot $context.RepoRoot -Arguments @("diff", "--cached", "--name-only")
  if ($staged.Count -eq 0) {
    Write-AutomationLog -Context $context -Level "INFO" -Message "No staged changes remained after filtering."
    exit 0
  }

  $message = "Auto publish: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
  Invoke-Git -RepoRoot $context.RepoRoot -Arguments @("commit", "-m", $message) | Out-Null
  Invoke-Git -RepoRoot $context.RepoRoot -Arguments @("push", "origin", "main") | Out-Null
  Write-AutomationLog -Context $context -Level "INFO" -Message "Auto publish completed with commit message '$message'."
} catch {
  Write-AutomationLog -Context $context -Level "ERROR" -Message $_.Exception.Message
  exit 1
} finally {
  Release-AutomationLock -LockHandle $lock
}
