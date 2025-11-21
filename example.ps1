# Example usage of AES-256-GCM PowerShell module

# Import the module
Import-Module .\AesGcm.psd1 -Force

Write-Host "=== PowerShell AES-256-GCM Module Example ===" -ForegroundColor Cyan
Write-Host ""

# 1. Generate a secure key
Write-Host "[1] Generating 256-bit key..." -ForegroundColor Yellow
$key = New-AesGcmKey -AsHex
Write-Host "Key: $key" -ForegroundColor Green
Write-Host ""

# 2. Basic encryption/decryption
Write-Host "[2] Basic Encryption/Decryption" -ForegroundColor Yellow
$plaintext = "48656c6c6f20576f726c64"  # "Hello World" in hex
Write-Host "Plaintext (hex): $plaintext"

$result = ConvertTo-AesGcmEncrypted -Key $key -Plaintext $plaintext
Write-Host "Ciphertext: $($result.Ciphertext)" -ForegroundColor Green
Write-Host "Tag: $($result.Tag)" -ForegroundColor Green
Write-Host "Nonce: $($result.Nonce)" -ForegroundColor Green

$decrypted = ConvertFrom-AesGcmEncrypted `
    -Key $key `
    -Ciphertext $result.Ciphertext `
    -Tag $result.Tag `
    -Nonce $result.Nonce

Write-Host "Decrypted (hex): $decrypted" -ForegroundColor Green
Write-Host "Match: $($plaintext -eq $decrypted)" -ForegroundColor $(if ($plaintext -eq $decrypted) { "Green" } else { "Red" })
Write-Host ""

# 3. Encryption with Additional Authenticated Data (AAD)
Write-Host "[3] Encryption with AAD" -ForegroundColor Yellow
$aad = "deadbeef"  # Additional authenticated data
Write-Host "AAD (hex): $aad"

$result2 = ConvertTo-AesGcmEncrypted `
    -Key $key `
    -Plaintext $plaintext `
    -AdditionalData $aad

Write-Host "Ciphertext: $($result2.Ciphertext)" -ForegroundColor Green
Write-Host "Tag: $($result2.Tag)" -ForegroundColor Green

$decrypted2 = ConvertFrom-AesGcmEncrypted `
    -Key $key `
    -Ciphertext $result2.Ciphertext `
    -Tag $result2.Tag `
    -Nonce $result2.Nonce `
    -AdditionalData $aad

Write-Host "Decrypted (hex): $decrypted2" -ForegroundColor Green
Write-Host "Match: $($plaintext -eq $decrypted2)" -ForegroundColor $(if ($plaintext -eq $decrypted2) { "Green" } else { "Red" })
Write-Host ""

# 4. Test authentication failure
Write-Host "[4] Testing Authentication Tag Verification" -ForegroundColor Yellow
Write-Host "Attempting decryption with wrong tag..."
try {
    $wrongTag = "00000000000000000000000000000000"
    $failed = ConvertFrom-AesGcmEncrypted `
        -Key $key `
        -Ciphertext $result.Ciphertext `
        -Tag $wrongTag `
        -Nonce $result.Nonce

    Write-Host "ERROR: Authentication should have failed!" -ForegroundColor Red
}
catch {
    Write-Host "Authentication correctly failed: $($_.Exception.Message)" -ForegroundColor Green
}
Write-Host ""

# 5. Empty message encryption (authentication-only mode)
Write-Host "[5] Empty Message Encryption (Authentication-Only)" -ForegroundColor Yellow
$emptyPlaintext = ""
$result3 = ConvertTo-AesGcmEncrypted `
    -Key $key `
    -Plaintext $emptyPlaintext `
    -AdditionalData $aad

Write-Host "Empty ciphertext: '$($result3.Ciphertext)'" -ForegroundColor Green
Write-Host "Tag: $($result3.Tag)" -ForegroundColor Green

$decrypted3 = ConvertFrom-AesGcmEncrypted `
    -Key $key `
    -Ciphertext $result3.Ciphertext `
    -Tag $result3.Tag `
    -Nonce $result3.Nonce `
    -AdditionalData $aad

Write-Host "Decrypted: '$decrypted3'" -ForegroundColor Green
Write-Host "Match: $($emptyPlaintext -eq $decrypted3)" -ForegroundColor $(if ($emptyPlaintext -eq $decrypted3) { "Green" } else { "Red" })
Write-Host ""

# 6. Custom nonce
Write-Host "[6] Using Custom Nonce" -ForegroundColor Yellow
$customNonce = New-AesGcmNonce -Size 12 -AsHex
Write-Host "Custom nonce: $customNonce"

$result4 = ConvertTo-AesGcmEncrypted `
    -Key $key `
    -Plaintext $plaintext `
    -Nonce $customNonce

Write-Host "Ciphertext: $($result4.Ciphertext)" -ForegroundColor Green
Write-Host "Used nonce: $($result4.Nonce)" -ForegroundColor Green
Write-Host "Nonce match: $($customNonce -eq $result4.Nonce)" -ForegroundColor $(if ($customNonce -eq $result4.Nonce) { "Green" } else { "Red" })
Write-Host ""

Write-Host "=== All Examples Completed ===" -ForegroundColor Cyan
