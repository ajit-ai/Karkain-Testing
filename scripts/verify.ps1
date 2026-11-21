#Requires -Version 5.1
# Karkain-Testing verification gate.
# Verifies the framework with the real Karkain v1.2.0 toolchain.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\verify.ps1
#
# Override paths with parameters if your toolchain lives elsewhere:
#   ... -KarkainSource 'C:\path\Karkain' -KarkainExe 'C:\path\karkain.exe' -CcDir 'C:\msys64\ucrt64\bin'

param(
    [string]$KarkainSource = 'C:\Windows\Temp\opencode\Karkain-v1.2.0',
    [string]$KarkainExe    = 'C:\Windows\Temp\opencode\karkain-bin\karkain-v1.2.0-windows-amd64\karkain.exe',
    [string]$CcDir          = 'C:\msys64\ucrt64\bin'
)

$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath $KarkainSource)) { throw "Karkain source not found: $KarkainSource" }
if (-not (Test-Path -LiteralPath $KarkainExe)) { throw "Karkain executable not found: $KarkainExe" }
if (Test-Path -LiteralPath $CcDir) { $env:PATH = "$CcDir;$env:PATH" }

$enc = New-Object System.Text.UTF8Encoding($false)
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('ktesting-verify-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

function Invoke-Karkain {
    param([string[]]$CmdArgs)
    Push-Location $KarkainSource
    try {
        & $KarkainExe @CmdArgs 2>&1 |
            Where-Object { $_ -notmatch 'undefined reference|collect2|ld returned 1 exit status' } |
            Out-String
    } finally { Pop-Location }
}

try {
    # 1. Static check of the framework module.
    $module = Join-Path $repo 'src\ktesting.kark'
    $out = Invoke-Karkain @('check', $module)
    $code = $LASTEXITCODE
    Write-Output "CHECK module: exit=$code"
    if ($code -ne 0) { Write-Output $out; throw 'module check failed' }

    # 2. Native test suite: module source + test bodies in one file.
    #    `karkain test` cannot resolve imports, so the real module source is
    #    prepended verbatim to the test functions.
    $tests = Join-Path $repo 'tests\api_tests.kark'
    $combined = Join-Path $tmp 'ktesting_suite_test.kark'
    $src = (Get-Content -LiteralPath $module -Raw) + "`n" + (Get-Content -LiteralPath $tests -Raw)
    [System.IO.File]::WriteAllText($combined, $src, $enc)
    $out = Invoke-Karkain @('test', $combined)
    $code = $LASTEXITCODE
    Write-Output "TEST native: exit=$code"
    Write-Output $out
    if ($code -ne 0) { throw 'native tests failed' }
    if ($out -notlike '*10 tests, 10 passed, 0 failed*') { throw 'native test summary did not match 10/10' }

    # 3. Integration: a real Karkain program consumes the public API.
    $verify = Join-Path $repo 'src\verify.kark'
    $out = Invoke-Karkain @('run', $verify)
    $code = $LASTEXITCODE
    Write-Output "RUN integration: exit=$code"
    Write-Output $out
    if ($code -ne 0) { throw 'integration program failed' }
    if ($out -notlike '*positive: 7 passed; 0 failed*') { throw 'positive summary missing' }
    if ($out -notlike '*FAIL wrong value - expected 2, got 1*') { throw 'negative diagnostic missing' }

    # 4. Negative gate: a deliberately failing suite must produce exit 4.
    $neg = Join-Path $tmp 'negative_test.kark'
    [System.IO.File]::WriteAllText($neg, "func test_expected_failure() {`n    assert(false)`n}`n", $enc)
    $out = Invoke-Karkain @('test', $neg)
    $code = $LASTEXITCODE
    Write-Output "TEST negative-gate: exit=$code (expected 4)"
    if ($code -ne 4) { throw 'negative gate did not return exit 4' }

    # 5. Runnable example: stage the module beside it and execute with the
    #    real compiler (local imports resolve from the entry file directory).
    $example = Join-Path $repo 'examples\suite_demo.kark'
    $exDir = Join-Path $tmp 'example'
    New-Item -ItemType Directory -Path $exDir | Out-Null
    Copy-Item -LiteralPath $module -Destination (Join-Path $exDir 'ktesting.kark')
    Copy-Item -LiteralPath $example -Destination (Join-Path $exDir 'suite_demo.kark')
    $out = Invoke-Karkain @('run', (Join-Path $exDir 'suite_demo.kark'))
    $code = $LASTEXITCODE
    Write-Output "RUN example: exit=$code"
    Write-Output $out
    if ($code -ne 0) { throw 'example failed' }
    if ($out -notlike '*suite total: 6*') { throw 'example summary missing' }
    if ($out -notlike '*suite ok: 0*') { throw 'example soft-failure status missing' }

    Write-Output 'VERIFY: ALL GATES PASSED'
}
finally {
    try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
