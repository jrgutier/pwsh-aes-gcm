# Compact capability detection for air-gapped systems
# Type this first to determine what implementation to use

Write-Host "=== System Capability Detection ===" -ForegroundColor Cyan

# OS Version
$os = [System.Environment]::OSVersion
Write-Host "`nOS: $($os.VersionString)"
Write-Host "Version: $($os.Version)" -ForegroundColor Yellow

# PowerShell Version
Write-Host "`nPowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow

# .NET Version
$netVer = [System.Environment]::Version
Write-Host ".NET Runtime: $netVer" -ForegroundColor Yellow

# Test 1: Modern AesGcm (.NET Core 3.0+, .NET 5+, PS7+)
Write-Host "`n--- Testing Modern AesGcm ---" -ForegroundColor Cyan
$hasModern = $false
try {
    $testType = [System.Security.Cryptography.AesGcm]
    $hasModern = $true
    Write-Host "[PASS] System.Security.Cryptography.AesGcm available" -ForegroundColor Green
    Write-Host "  -> Use: MODERN (simplest)" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] AesGcm not available: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: BCrypt CNG (Windows 7+, .NET Framework 3.5+)
Write-Host "`n--- Testing BCrypt CNG ---" -ForegroundColor Cyan
$hasBCrypt = $false
try {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class BCryptTest {
    [DllImport("bcrypt.dll")]
    public static extern uint BCryptOpenAlgorithmProvider(
        out IntPtr phAlgorithm,
        [MarshalAs(UnmanagedType.LPWStr)] string pszAlgId,
        [MarshalAs(UnmanagedType.LPWStr)] string pszImplementation,
        uint dwFlags);
    [DllImport("bcrypt.dll")]
    public static extern uint BCryptCloseAlgorithmProvider(IntPtr hAlgorithm, uint dwFlags);
}
"@
    $handle = [IntPtr]::Zero
    $status = [BCryptTest]::BCryptOpenAlgorithmProvider([ref]$handle, "AES", $null, 0)
    if ($status -eq 0 -and $handle -ne [IntPtr]::Zero) {
        [BCryptTest]::BCryptCloseAlgorithmProvider($handle, 0) | Out-Null
        $hasBCrypt = $true
        Write-Host "[PASS] BCrypt CNG available" -ForegroundColor Green
        Write-Host "  -> Use: LEGACY (recommended for .NET Framework)" -ForegroundColor Green
    }
} catch {
    Write-Host "[FAIL] BCrypt not available: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: AES-ECB for Full GCM (always available)
Write-Host "`n--- Testing AES-ECB (Full GCM fallback) ---" -ForegroundColor Cyan
try {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode = [System.Security.Cryptography.CipherMode]::ECB
    $aes.Dispose()
    Write-Host "[PASS] AES-ECB available (Full GCM possible)" -ForegroundColor Green
    Write-Host "  -> Use: FULL (supports all IV sizes)" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] AES-ECB not available: $($_.Exception.Message)" -ForegroundColor Red
}

# Recommendations
Write-Host "`n=== RECOMMENDATION ===" -ForegroundColor Cyan
if ($hasModern) {
    Write-Host "Use MODERN implementation (type 'modern' snippets)" -ForegroundColor Green
} elseif ($hasBCrypt) {
    Write-Host "Use LEGACY implementation (type 'legacy' snippets)" -ForegroundColor Yellow
} else {
    Write-Host "Use FULL implementation (type 'full' snippets)" -ForegroundColor Yellow
}

Write-Host "`nNext: Type the implementation snippets for your system"
