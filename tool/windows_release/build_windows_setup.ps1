param(
  [switch]$SkipBuild,
  [string]$OutputDir,
  [string]$IsccPath
)

$ErrorActionPreference = 'Stop'

function Resolve-InnoSetupCompiler {
  param([string]$PreferredPath)

  $candidates = @(
    $PreferredPath,
    $env:INNO_SETUP_ISCC,
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    'C:\Program Files\Inno Setup 6\ISCC.exe'
  ) | Where-Object { $_ }

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return (Resolve-Path $candidate).Path
    }
  }

  return $null
}

function Resolve-AppVersionLabel {
  param([string]$PubspecPath)

  $versionLine = Select-String -Path $PubspecPath -Pattern '^version:\s*(.+)$' |
    Select-Object -First 1
  if (-not $versionLine) {
    throw "Could not read app version from $PubspecPath"
  }

  $rawVersion = $versionLine.Matches[0].Groups[1].Value.Trim()
  $parts = $rawVersion -split '\+', 2
  if ($parts.Length -gt 1 -and $parts[1]) {
    return "$($parts[0])-build$($parts[1])"
  }

  return $parts[0]
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot '..\..')).Path
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$issPath = Join-Path $scriptRoot 'LearnY.iss'

$versionLabel = Resolve-AppVersionLabel -PubspecPath $pubspecPath
$resolvedOutputDir = $null
if ($OutputDir) {
  if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $resolvedOutputDir = $OutputDir
  } else {
    $resolvedOutputDir = Join-Path $repoRoot $OutputDir
  }
}
if (-not $resolvedOutputDir) {
  $resolvedOutputDir = Join-Path $repoRoot 'dist\windows'
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null

if (-not $SkipBuild) {
  Push-Location $repoRoot
  try {
    flutter build windows
  } finally {
    Pop-Location
  }
}

$runnerExe = Join-Path $releaseDir 'learn_y.exe'
if (-not (Test-Path $runnerExe)) {
  throw "Windows release build is missing: $runnerExe"
}

$resolvedIsccPath = Resolve-InnoSetupCompiler -PreferredPath $IsccPath
if (-not $resolvedIsccPath) {
  throw @"
Inno Setup 6 was not found.

Install ISCC.exe or pass -IsccPath explicitly, then rerun:
  powershell -ExecutionPolicy Bypass -File .\tool\windows_release\build_windows_setup.ps1
"@
}

$outputBaseFilename = "LearnY-Setup-$versionLabel"

Push-Location $repoRoot
try {
  & $resolvedIsccPath `
    "/DAppVersion=$versionLabel" `
    "/DSourceDir=$releaseDir" `
    "/DOutputDir=$resolvedOutputDir" `
    "/DOutputBaseFilename=$outputBaseFilename" `
    $issPath
} finally {
  Pop-Location
}

$installerPath = Join-Path $resolvedOutputDir "$outputBaseFilename.exe"
if (-not (Test-Path $installerPath)) {
  throw "Installer build did not produce $installerPath"
}

Write-Output "Installer created: $installerPath"
