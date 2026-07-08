Set-StrictMode -Version Latest

function Get-AutomationContext {
  param(
    [Parameter(Mandatory = $true)]
    [string]$TaskName
  )

  $repoRoot = Split-Path -Parent $PSScriptRoot
  $logsRoot = Join-Path $repoRoot "logs"
  $automationLogs = Join-Path $logsRoot "automation"
  $stateRoot = Join-Path $repoRoot ".automation"

  return @{
    RepoRoot = $repoRoot
    LogsRoot = $logsRoot
    AutomationLogs = $automationLogs
    StateRoot = $stateRoot
    LockPath = Join-Path $stateRoot "$TaskName.lock"
    LogPath = Join-Path $automationLogs "$TaskName.log"
    ExpectedOrigin = "https://github.com/jjagong/jjagong.github.io.git"
  }
}

function Ensure-AutomationDirectories {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Context
  )

  foreach ($path in @($Context.LogsRoot, $Context.AutomationLogs, $Context.StateRoot)) {
    if (-not (Test-Path -LiteralPath $path)) {
      New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
  }
}

function Add-PortableNodeToPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
  )

  $portableNode = Get-ChildItem -LiteralPath (Join-Path $RepoRoot ".local-node") -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    Select-Object -First 1

  if ($portableNode) {
    $env:Path = "$($portableNode.FullName);$env:Path"
  }
}

function Write-AutomationLog {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Context,
    [Parameter(Mandatory = $true)]
    [string]$Level,
    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$timestamp] [$Level] $Message"
  Add-Content -LiteralPath $Context.LogPath -Value $line
  Write-Host $line
}

function Acquire-AutomationLock {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Context
  )

  try {
    return [System.IO.File]::Open($Context.LockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
  } catch {
    return $null
  }
}

function Release-AutomationLock {
  param(
    [Parameter(Mandatory = $false)]
    $LockHandle
  )

  if ($null -ne $LockHandle) {
    $LockHandle.Dispose()
  }
}

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $output = & git -C $RepoRoot @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    $text = ($output | Out-String).Trim()
    throw "git $($Arguments -join ' ') failed (exit $exitCode): $text"
  }

  return @($output)
}

function Invoke-RepoScript {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,
    [string[]]$Arguments = @()
  )

  Push-Location $RepoRoot
  try {
    $output = & $ScriptPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
      $text = ($output | Out-String).Trim()
      throw "$ScriptPath failed (exit $exitCode): $text"
    }
    return @($output)
  } finally {
    Pop-Location
  }
}

function Get-BranchName {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
  )

  return (Invoke-Git -RepoRoot $RepoRoot -Arguments @("branch", "--show-current") | Select-Object -First 1).Trim()
}

function Test-RepositoryIdentity {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Context
  )

  $origin = (Invoke-Git -RepoRoot $Context.RepoRoot -Arguments @("remote", "get-url", "origin") | Select-Object -First 1).Trim()
  if ($origin -ne $Context.ExpectedOrigin) {
    throw "Unexpected origin remote: $origin"
  }

  $branch = Get-BranchName -RepoRoot $Context.RepoRoot
  if ($branch -ne "main") {
    throw "Current branch is '$branch', expected 'main'"
  }
}

function Get-GitStatusEntries {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
  )

  $lines = Invoke-Git -RepoRoot $RepoRoot -Arguments @("status", "--porcelain=v1", "--untracked-files=all")
  $entries = @()

  foreach ($line in $lines) {
    $text = "$line"
    if ([string]::IsNullOrWhiteSpace($text)) {
      continue
    }

    $pathText = $text.Substring(3).Trim()
    if ($pathText -like "* -> *") {
      $pathText = ($pathText -split " -> ")[-1]
    }

    $entries += [pscustomobject]@{
      Code = $text.Substring(0, 2)
      Path = ($pathText -replace "\\", "/")
      Raw  = $text
    }
  }

  return $entries
}

function Get-GitRevisionDelta {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
  )

  $behind = [int](Invoke-Git -RepoRoot $RepoRoot -Arguments @("rev-list", "--count", "HEAD..origin/main") | Select-Object -First 1)
  $ahead = [int](Invoke-Git -RepoRoot $RepoRoot -Arguments @("rev-list", "--count", "origin/main..HEAD") | Select-Object -First 1)

  return @{
    Behind = $behind
    Ahead = $ahead
  }
}

function Test-ContentPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  return $Path -like "content/*"
}

function Test-AutoPublishPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if ($Path -like "content/*") { return $true }
  if ($Path -in @(".nojekyll", "404.html", "CNAME", "favicon.ico", "index.html", "index.xml", "sitemap.xml")) { return $true }
  if ($Path -like "static/*" -or $Path -eq "static") { return $true }
  if ($Path -like "tags/*" -or $Path -eq "tags") { return $true }
  if ($Path -like "component-*.css") { return $true }
  if ($Path -like "index-*.css") { return $true }
  if ($Path -like "index-*-image.webp") { return $true }
  if ($Path -like "postscript-*.js") { return $true }
  if ($Path -like "prescript-*.js") { return $true }
  if ($Path -like "*-og-image.webp") { return $true }

  return $false
}

function Get-UniquePaths {
  param(
    [Parameter(Mandatory = $true)]
    [object[]]$Entries
  )

  return $Entries |
    ForEach-Object { $_.Path } |
    Sort-Object -Unique
}
