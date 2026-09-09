[CmdletBinding()]
param(
    [string]$AvdName,
    [string]$SdkRoot,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if (-not $SdkRoot) {
    if ($env:ANDROID_HOME) {
        $SdkRoot = $env:ANDROID_HOME
    } elseif ($env:ANDROID_SDK_ROOT) {
        $SdkRoot = $env:ANDROID_SDK_ROOT
    } else {
        $SdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    }
}
$emulatorExecutable = Join-Path $SdkRoot 'emulator\emulator.exe'
if (-not (Test-Path -LiteralPath $emulatorExecutable)) {
    throw "Android emulator not found: $emulatorExecutable"
}
$availableAvds = @(& $emulatorExecutable -list-avds)
if ($LASTEXITCODE -ne 0) { throw 'Unable to list Android virtual devices.' }
if (-not $AvdName) {
    if ($availableAvds.Count -ne 1) {
        throw 'Specify -AvdName when the SDK does not have exactly one virtual device.'
    }
    $AvdName = $availableAvds[0].Trim()
}
if ($AvdName -notin $availableAvds) { throw "Unknown virtual device: $AvdName" }

# Keep userdata and use the hardware OpenGL path verified with course glass.
# SwiftShader reproduced a host access violation when opening the course page.
$emulatorArguments = @(
    '-avd', $AvdName, '-no-snapshot', '-no-boot-anim',
    '-cores', '4', '-gpu', 'host', '-feature', '-Vulkan', '-noaudio'
)
if ($DryRun) {
    Write-Output $emulatorExecutable
    Write-Output ($emulatorArguments -join ' ')
    return
}
& $emulatorExecutable @emulatorArguments
exit $LASTEXITCODE
