param(
  [string]$Message = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($Message)) {
  $Message = "Update blog"
}

& (Join-Path $PSScriptRoot "build-site.ps1")

git add .
git commit -m $Message
git push origin main
