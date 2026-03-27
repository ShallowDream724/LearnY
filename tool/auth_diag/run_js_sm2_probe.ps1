param(
  [string]$OutputPath = '.\tool\auth_diag\.out\js-sm2-probe.json',
  [string]$BodyDir = '.\tool\auth_diag\.out\js-sm2-probe-body'
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
$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath
} else {
  Join-Path $repoRoot $OutputPath
}

$resolvedBodyDir = if ([System.IO.Path]::IsPathRooted($BodyDir)) {
  $BodyDir
} else {
  Join-Path $repoRoot $BodyDir
}

$username = Read-Host 'Unified identity username'
$securePassword = Read-Host 'Unified identity password' -AsSecureString
$password = ConvertTo-PlainText $securePassword

try {
  $env:LEARNY_AUTH_DIAG_USERNAME = $username
  $env:LEARNY_AUTH_DIAG_PASSWORD = $password

  Push-Location $toolDir
  try {
    & node .\js_sm2_ticket_probe.mjs --output $resolvedOutput --body-dir $resolvedBodyDir
    if ($LASTEXITCODE -ne 0) {
      throw "js_sm2_ticket_probe failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }

  Write-Host "[js-sm2-probe] Output: $resolvedOutput"
  Write-Host "[js-sm2-probe] BodyDir: $resolvedBodyDir"
} finally {
  Remove-Item Env:LEARNY_AUTH_DIAG_USERNAME -ErrorAction SilentlyContinue
  Remove-Item Env:LEARNY_AUTH_DIAG_PASSWORD -ErrorAction SilentlyContinue
  $password = $null
}
