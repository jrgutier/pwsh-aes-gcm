# Pre-Push Verification Script
# Run this locally before pushing to catch issues early

param(
    [switch]$Quick,
    [switch]$SkipTests
)

Write-Host "=== Pre-Push Verification ===" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$failures = 0

# 1. Check PowerShell syntax
Write-Host "[1/5] Validating PowerShell syntax..." -ForegroundColor Yellow
try {
    $files = Get-ChildItem -Path . -Filter "*.ps*1" -Recurse | Where-Object { $_.FullName -notmatch '\\\.git\\' }
    foreach ($file in $files) {
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName,
            [ref]$null,
            [ref]$parseErrors
        )

        if ($parseErrors) {
            Write-Host "  ❌ Syntax errors in $($file.Name)" -ForegroundColor Red
            $parseErrors | ForEach-Object {
                Write-Host "    Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red
            }
            $failures++
        }
    }

    if ($failures -eq 0) {
        Write-Host "  ✓ All files have valid syntax" -ForegroundColor Green
    }
} catch {
    Write-Host "  ❌ Syntax validation failed: $_" -ForegroundColor Red
    $failures++
}
Write-Host ""

# 2. Check module manifest
Write-Host "[2/5] Validating module manifest..." -ForegroundColor Yellow
try {
    $manifest = Test-ModuleManifest -Path ./AesGcm.psd1 -ErrorAction Stop
    Write-Host "  ✓ Module: $($manifest.Name) v$($manifest.Version)" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Module manifest validation failed: $_" -ForegroundColor Red
    $failures++
}
Write-Host ""

# 3. Run PSScriptAnalyzer if available
Write-Host "[3/5] Running PSScriptAnalyzer..." -ForegroundColor Yellow
try {
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-Host "  ⚠ PSScriptAnalyzer not installed. Run: Install-Module -Name PSScriptAnalyzer -Scope CurrentUser" -ForegroundColor Yellow
    } else {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        $results = Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery -Severity Error

        if ($results) {
            Write-Host "  ❌ Found $($results.Count) error(s):" -ForegroundColor Red
            $results | Format-Table -AutoSize | Out-String | Write-Host
            $failures++
        } else {
            Write-Host "  ✓ No errors found" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "  ⚠ PSScriptAnalyzer check skipped: $_" -ForegroundColor Yellow
}
Write-Host ""

# 4. Test module import
Write-Host "[4/5] Testing module import..." -ForegroundColor Yellow
try {
    Import-Module ./AesGcm.psd1 -Force -ErrorAction Stop
    Write-Host "  ✓ Module imported successfully" -ForegroundColor Green

    # Quick smoke test
    $key = New-AesGcmKey -AsHex
    $nonce = New-AesGcmNonce -AsHex
    $plaintext = "48656c6c6f20576f726c64"

    $result = ConvertTo-AesGcmEncrypted -Key $key -Plaintext $plaintext -Nonce $nonce
    $decrypted = ConvertFrom-AesGcmEncrypted -Key $key -Ciphertext $result.Ciphertext -Tag $result.Tag -Nonce $nonce

    if ($decrypted -eq $plaintext) {
        Write-Host "  ✓ Basic encryption/decryption working" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Encryption/decryption test failed" -ForegroundColor Red
        $failures++
    }
} catch {
    Write-Host "  ❌ Module import or smoke test failed: $_" -ForegroundColor Red
    $failures++
}
Write-Host ""

# 5. Run test suite (unless skipped or Quick mode)
if (-not $SkipTests -and -not $Quick) {
    Write-Host "[5/5] Running test suite..." -ForegroundColor Yellow
    try {
        Import-Module ./AesGcm.psd1 -Force
        Test-AesGcmImplementation -ErrorAction Stop | Out-Null
        Write-Host "  ✓ Test suite passed" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Test suite failed: $_" -ForegroundColor Red
        $failures++
    }
} else {
    Write-Host "[5/5] Test suite skipped (use without -Quick or -SkipTests to run)" -ForegroundColor Gray
}
Write-Host ""

# Summary
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($failures -eq 0) {
    Write-Host "✓ All checks passed! Ready to push." -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ $failures check(s) failed. Please fix issues before pushing." -ForegroundColor Red
    exit 1
}
