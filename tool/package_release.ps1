param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$')][string]$Version,
    [Parameter(Mandatory = $true)][ValidateRange(1, 2147483647)][int]$BuildNumber,
    [Parameter(Mandatory = $true)][string]$AaptPath
)

# Package already-built production targets; never rebuild, delete or overwrite
# an earlier distribution. Check both embedded versions before copying either.
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$releaseDirectory = Join-Path $projectDirectory "dist/releases/v$Version-build$BuildNumber"
$portableDirectory = Join-Path $releaseDirectory 'LearnY-Windows-x64'
$windowsBuild = Join-Path $projectDirectory 'build/windows/x64/runner/Release'
$androidBuild = Join-Path $projectDirectory 'build/app/outputs/flutter-apk/app-release.apk'
$exe = Join-Path $windowsBuild 'learn_y.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Missing Windows executable' }
if (-not (Test-Path -LiteralPath $androidBuild)) { throw 'Missing Android APK' }
$windowsVersion = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion
if ($windowsVersion -ne "$Version+$BuildNumber") { throw "Unexpected Windows version: $windowsVersion" }
$apkInfo = & $AaptPath dump badging $androidBuild
if ($LASTEXITCODE -ne 0) { throw 'Cannot read APK version' }
$packageLine = $apkInfo | Select-String '^package:'
if ($packageLine -notmatch "versionCode='$BuildNumber'" -or
    $packageLine -notmatch ("versionName='" + [regex]::Escape($Version) + "'")) {
    throw "Unexpected APK version: $packageLine"
}
foreach ($relative in @('flutter_windows.dll', 'data/app.so', 'data/icudtl.dat',
    'data/flutter_assets/shaders/glass_light.frag', 'data/flutter_assets/shaders/glass_refraction.frag')) {
    if (-not (Test-Path -LiteralPath (Join-Path $windowsBuild $relative))) { throw "Missing runtime asset: $relative" }
}
if (Test-Path -LiteralPath $releaseDirectory) { throw "Release output already exists: $releaseDirectory" }
New-Item -ItemType Directory -Path $portableDirectory | Out-Null
Get-ChildItem -LiteralPath $windowsBuild -Force | Copy-Item -Destination $portableDirectory -Recurse
$apkPath = Join-Path $releaseDirectory "LearnY-$Version-android.apk"
Copy-Item -LiteralPath $androidBuild -Destination $apkPath
$zipPath = Join-Path $releaseDirectory "LearnY-$Version-windows-x64-portable.zip"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($portableDirectory, $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal, $false)
$hashes = Get-FileHash -Algorithm SHA256 -LiteralPath $apkPath, $zipPath
$checksumLines = $hashes | ForEach-Object { '{0}  {1}' -f $_.Hash.ToLowerInvariant(), (Split-Path -Leaf $_.Path) }
[System.IO.File]::WriteAllLines((Join-Path $releaseDirectory 'SHA256SUMS.txt'),
    $checksumLines, [System.Text.UTF8Encoding]::new($false))
$hashes | Select-Object Path, Hash | Format-List
Write-Output "Windows: $windowsVersion"
Write-Output $packageLine
