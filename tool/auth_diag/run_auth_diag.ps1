param(
  [string]$ExistingCapture,
  [string]$OutputDir,
  [string]$Browser = 'edge',
  [switch]$SkipFreshCredentialChain,
  [switch]$AutoSubmit,
  [switch]$Prefill,
  [switch]$PreserveTicket,
  [switch]$NoPrefill
)

$ErrorActionPreference = 'Stop'

function ConvertTo-PlainText([Security.SecureString]$SecureValue) {
  if ($null -eq $SecureValue) {
    return ''
  }

  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    if ($bstr -ne [IntPtr]::Zero) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
  }
}

$toolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $toolDir '..\..')
$outRoot = Join-Path $toolDir '.out'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = if ($OutputDir) {
  if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
  } else {
    Join-Path $repoRoot $OutputDir
  }
} else {
  Join-Path $outRoot $timestamp
}
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$capturePath = if ($ExistingCapture) {
  (Resolve-Path $ExistingCapture).Path
} else {
  Join-Path $runDir 'capture.json'
}
$summaryPath = Join-Path $runDir 'summary.json'
$logPath = Join-Path $runDir 'auth-diagnostics.log'

$nodeModulesPath = Join-Path $toolDir 'node_modules\playwright-core'
if (-not (Test-Path $nodeModulesPath)) {
  Write-Host '[auth-diag] Installing Node dependencies in tool/auth_diag...'
  Push-Location $toolDir
  try {
    npm install --no-fund --no-audit
  } finally {
    Pop-Location
  }
}

$usePrefill = $Prefill.IsPresent -and (-not $NoPrefill.IsPresent)
if ($AutoSubmit.IsPresent -and (-not $usePrefill)) {
  throw '-AutoSubmit requires -Prefill; manual browser mode will not inject credentials.'
}
$needsCredentialPrompt = (-not $SkipFreshCredentialChain.IsPresent) -or ($usePrefill -and (-not $ExistingCapture))
$username = $null
$password = $null

if ($needsCredentialPrompt) {
  $username = Read-Host 'Unified identity username'
  $securePassword = Read-Host 'Unified identity password' -AsSecureString
  $password = ConvertTo-PlainText $securePassword
}

try {
  if (-not $ExistingCapture) {
    if ($usePrefill) {
      $env:LEARNY_AUTH_DIAG_USERNAME = $username
      $env:LEARNY_AUTH_DIAG_PASSWORD = $password
    } else {
      Remove-Item Env:LEARNY_AUTH_DIAG_USERNAME -ErrorAction SilentlyContinue
      Remove-Item Env:LEARNY_AUTH_DIAG_PASSWORD -ErrorAction SilentlyContinue
    }

    $captureArgs = @(
      'capture_login_context.mjs',
      '--output', $capturePath,
      '--browser', $Browser
    )
    if ($AutoSubmit.IsPresent) {
      $captureArgs += '--auto-submit'
    }
    if (-not $usePrefill) {
      $captureArgs += '--no-prefill'
    }
    if ($PreserveTicket.IsPresent) {
      $captureArgs += '--preserve-ticket'
    }

    Write-Host '[auth-diag] Opening browser capture flow...'
    Push-Location $toolDir
    try {
      & node @captureArgs
      if ($LASTEXITCODE -ne 0) {
        throw "Browser capture failed with exit code $LASTEXITCODE"
      }
    } finally {
      Pop-Location
    }
  }

  if ($username) {
    $env:LEARNY_AUTH_DIAG_USERNAME = $username
  }
  if ($password) {
    $env:LEARNY_AUTH_DIAG_PASSWORD = $password
  }

  $dartArgs = @(
    '--capture', $capturePath,
    '--summary', $summaryPath,
    '--log', $logPath,
    '--username-env', 'LEARNY_AUTH_DIAG_USERNAME',
    '--password-env', 'LEARNY_AUTH_DIAG_PASSWORD'
  )
  if ($SkipFreshCredentialChain.IsPresent) {
    $dartArgs += '--skip-fresh-credential-chain'
  }
  $env:LEARNY_AUTH_DIAG_ARGS_JSON = ($dartArgs | ConvertTo-Json -Compress)

  Write-Host '[auth-diag] Running Dart diagnostics...'
  Push-Location $repoRoot
  try {
    & flutter test tool/auth_diag/auth_diagnostics_runner_test.dart --reporter expanded
    if ($LASTEXITCODE -ne 0) {
      throw "Dart diagnostics failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }

  Write-Host "[auth-diag] Capture: $capturePath"
  Write-Host "[auth-diag] Summary: $summaryPath"
  Write-Host "[auth-diag] Log: $logPath"
} finally {
  Remove-Item Env:LEARNY_AUTH_DIAG_ARGS_JSON -ErrorAction SilentlyContinue
  Remove-Item Env:LEARNY_AUTH_DIAG_USERNAME -ErrorAction SilentlyContinue
  Remove-Item Env:LEARNY_AUTH_DIAG_PASSWORD -ErrorAction SilentlyContinue
  $password = $null
}
