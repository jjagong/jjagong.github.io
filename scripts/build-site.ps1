param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "[1/4] Building Quartz output..."
npx quartz build

$generatedRootPaths = @(
  ".nojekyll",
  "404.html",
  "CNAME",
  "favicon.ico",
  "index.html",
  "index.xml",
  "sitemap.xml",
  "static",
  "tags"
)

$generatedPatterns = @(
  "component-*.css",
  "index-*.css",
  "index-*-image.webp",
  "postscript-*.js",
  "prescript-*.js",
  "*-og-image.webp"
)

Write-Host "[2/4] Cleaning previously generated root files..."
foreach ($relativePath in $generatedRootPaths) {
  $targetPath = Join-Path $repoRoot $relativePath
  if (Test-Path $targetPath) {
    Remove-Item -LiteralPath $targetPath -Recurse -Force
  }
}

foreach ($pattern in $generatedPatterns) {
  Get-ChildItem -Path $repoRoot -Filter $pattern -Force -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force
  }
}

Write-Host "[3/4] Copying built site to repository root..."
Get-ChildItem -Path (Join-Path $repoRoot "public") -Force | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $repoRoot $_.Name) -Recurse -Force
}

Write-Host "[4/4] Ensuring .nojekyll is present..."
New-Item -ItemType File -Path (Join-Path $repoRoot ".nojekyll") -Force | Out-Null

Write-Host "Site build sync complete."
