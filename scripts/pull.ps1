param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$portableNode = Get-ChildItem -LiteralPath (Join-Path $repoRoot ".local-node") -Directory -ErrorAction SilentlyContinue |
  Sort-Object Name -Descending |
  Select-Object -First 1

if ($portableNode) {
  $env:Path = "$($portableNode.FullName);$env:Path"
}

git pull --ff-only origin main
npm ci
