param(
    [ValidateSet('run', 'build', 'test')]
    [string]$Action = 'run',
    [switch]$Demo,
    [ValidateSet('debug', 'release')]
    [string]$Configuration = 'debug',
    [ValidateSet('normal', 'offline', 'slow')]
    [string]$Network = 'normal',
    [switch]$PreviousSemester
)

$ErrorActionPreference = 'Stop'
$flutterCommand = Get-Command flutter.bat -ErrorAction Stop
$gitCommand = Get-Command git.exe -ErrorAction Stop
$originalPath = $env:Path
$originalPathExt = $env:PATHEXT
$projectRoot = Split-Path $PSScriptRoot -Parent

# System command discovery must also work inside MSBuild's nested cmd process.
$paths = [System.Collections.Generic.List[string]]::new()
foreach ($entry in @(
    "$env:SystemRoot\System32",
    $env:SystemRoot,
    "$env:SystemRoot\System32\WindowsPowerShell\v1.0",
    (Split-Path $gitCommand.Source),
    (Split-Path $flutterCommand.Source)
)) {
    $paths.Add($entry)
}
if ($env:CONDA_PREFIX -and (Test-Path "$env:CONDA_PREFIX\Library\bin")) {
    $paths.Add("$env:CONDA_PREFIX\Library\bin")
}
foreach ($entry in ($originalPath -split ';')) {
    if ($entry -and $entry -ne '%PATH%' -and -not $paths.Contains($entry)) {
        $paths.Add($entry)
    }
}

try {
    $env:Path = $paths -join ';'
    $env:PATHEXT = '.COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC'
    Push-Location $projectRoot
    try {
        $flutterArguments = @('--no-version-check')
        if ($Action -eq 'test') {
            $flutterArguments += @('test', '--no-pub')
        } else {
            if ($Action -eq 'build') {
                $flutterArguments += @('build', 'windows', "--$Configuration", '--no-pub')
            } else {
                $flutterArguments += @('run', '-d', 'windows', "--$Configuration", '--no-pub')
            }
            $entryPoint = if ($Demo) { 'lib/main_demo.dart' } else { 'lib/main.dart' }
            $flutterArguments += @('-t', $entryPoint)
            if ($Demo) {
                $flutterArguments += "--dart-define=LEARNY_DEMO_NETWORK=$Network"
                if ($PreviousSemester) {
                    $flutterArguments += '--dart-define=LEARNY_DEMO_PREVIOUS_SEMESTER=true'
                }
            }
        }
        & $flutterCommand.Source @flutterArguments
        if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
} finally {
    $env:Path = $originalPath
    $env:PATHEXT = $originalPathExt
}
