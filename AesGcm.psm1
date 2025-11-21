# AesGcm.psm1
# PowerShell module for AES-256-GCM encryption/decryption
# Compatible with Windows 7, 10, and 11 using native .NET

# Load implementation classes
. "$PSScriptRoot/Classes/AesGcmNative.ps1"
. "$PSScriptRoot/Classes/AesGcmLegacy.ps1"
. "$PSScriptRoot/Classes/AesGcmFull.ps1"

# Module-level variables
$script:AesGcmImplType = $null
$script:UseNative = $false

function Initialize-AesGcmImplementation {
    if ($null -ne $script:AesGcmImplType) {
        return
    }

    # Try native implementation first
    if (Test-AesGcmNativeAvailable) {
        $script:UseNative = $true
        $script:AesGcmImplType = "Native"
        Write-Verbose "Using native System.Security.Cryptography.AesGcm implementation"
        return
    }

    # Fall back to BCrypt P/Invoke
    try {
        Initialize-AesGcmLegacy
        $script:UseNative = $false
        $script:AesGcmImplType = "Legacy"
        Write-Verbose "Using BCrypt CNG P/Invoke implementation"
    }
    catch {
        throw "Failed to initialize AES-GCM implementation: $_"
    }
}

function Invoke-AesGcmEncrypt {
    param(
        [byte[]]$Key,
        [byte[]]$Nonce,
        [byte[]]$Plaintext,
        [byte[]]$Aad
    )

    Initialize-AesGcmImplementation

    # Check if nonce is standard 96-bit (12 bytes)
    # If not, use the full GCM implementation that supports variable IV sizes
    if ($Nonce.Length -ne 12) {
        Write-Verbose "Using full GCM implementation for non-standard IV size: $($Nonce.Length) bytes"
        return Invoke-AesGcmFullEncrypt -Key $Key -Nonce $Nonce -Plaintext $Plaintext -Aad $Aad
    }

    if ($script:UseNative) {
        return Invoke-AesGcmNativeEncrypt -Key $Key -Nonce $Nonce -Plaintext $Plaintext -Aad $Aad
    }
    else {
        return Invoke-AesGcmLegacyEncrypt -Key $Key -Nonce $Nonce -Plaintext $Plaintext -Aad $Aad
    }
}

function Invoke-AesGcmDecrypt {
    param(
        [byte[]]$Key,
        [byte[]]$Nonce,
        [byte[]]$Ciphertext,
        [byte[]]$Tag,
        [byte[]]$Aad
    )

    Initialize-AesGcmImplementation

    # Check if nonce is standard 96-bit (12 bytes)
    # If not, use the full GCM implementation that supports variable IV sizes
    if ($Nonce.Length -ne 12) {
        Write-Verbose "Using full GCM implementation for non-standard IV size: $($Nonce.Length) bytes"
        return Invoke-AesGcmFullDecrypt -Key $Key -Nonce $Nonce -Ciphertext $Ciphertext -Tag $Tag -Aad $Aad
    }

    if ($script:UseNative) {
        return Invoke-AesGcmNativeDecrypt -Key $Key -Nonce $Nonce -Ciphertext $Ciphertext -Tag $Tag -Aad $Aad
    }
    else {
        return Invoke-AesGcmLegacyDecrypt -Key $Key -Nonce $Nonce -Ciphertext $Ciphertext -Tag $Tag -Aad $Aad
    }
}

function ConvertFrom-HexString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$HexString
    )

    if ([string]::IsNullOrWhiteSpace($HexString)) {
        return [byte[]]@()
    }

    # Remove any whitespace or common separators
    $cleaned = $HexString -replace '[\s:-]', ''

    if ($cleaned.Length % 2 -ne 0) {
        throw "Hex string must have an even number of characters"
    }

    $bytes = New-Object byte[] ($cleaned.Length / 2)
    for ($i = 0; $i -lt $cleaned.Length; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($cleaned.Substring($i, 2), 16)
    }

    return $bytes
}

function ConvertTo-HexString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [byte[]]$Bytes
    )

    if ($null -eq $Bytes -or $Bytes.Length -eq 0) {
        return ""
    }

    return [BitConverter]::ToString($Bytes) -replace '-', ''
}

function New-AesGcmKey {
    <#
    .SYNOPSIS
    Generates a cryptographically secure AES-256 key.

    .DESCRIPTION
    Creates a random 256-bit (32-byte) key suitable for AES-256-GCM encryption.

    .PARAMETER AsHex
    If specified, returns the key as a hexadecimal string instead of bytes.

    .EXAMPLE
    $key = New-AesGcmKey -AsHex
    #>
    [CmdletBinding()]
    param(
        [switch]$AsHex
    )

    $key = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($key)
    }
    finally {
        $rng.Dispose()
    }

    if ($AsHex) {
        return ConvertTo-HexString $key
    }
    else {
        return $key
    }
}

function New-AesGcmNonce {
    <#
    .SYNOPSIS
    Generates a cryptographically secure nonce (IV) for AES-GCM.

    .DESCRIPTION
    Creates a random nonce for use with AES-GCM. The default size is 96 bits (12 bytes)
    which is the recommended size for GCM mode.

    .PARAMETER Size
    The size of the nonce in bytes. Default is 12 (96 bits).

    .PARAMETER AsHex
    If specified, returns the nonce as a hexadecimal string instead of bytes.

    .EXAMPLE
    $nonce = New-AesGcmNonce -AsHex
    #>
    [CmdletBinding()]
    param(
        [int]$Size = 12,
        [switch]$AsHex
    )

    if ($Size -le 0) {
        throw "Nonce size must be positive"
    }

    $nonce = New-Object byte[] $Size
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($nonce)
    }
    finally {
        $rng.Dispose()
    }

    if ($AsHex) {
        return ConvertTo-HexString $nonce
    }
    else {
        return $nonce
    }
}

function ConvertTo-AesGcmEncrypted {
    <#
    .SYNOPSIS
    Encrypts data using AES-256-GCM.

    .DESCRIPTION
    Encrypts plaintext using AES-256-GCM authenticated encryption. All inputs and outputs
    are hexadecimal strings.

    .PARAMETER Key
    The encryption key as a hexadecimal string (64 hex characters for 256-bit key).

    .PARAMETER Plaintext
    The plaintext to encrypt as a hexadecimal string.

    .PARAMETER Nonce
    Optional nonce (IV) as a hexadecimal string. If not provided, a random 96-bit nonce is generated.

    .PARAMETER AdditionalData
    Optional additional authenticated data (AAD) as a hexadecimal string.

    .OUTPUTS
    Returns a hashtable with Ciphertext, Tag, and Nonce as hexadecimal strings.

    .EXAMPLE
    $key = New-AesGcmKey -AsHex
    $result = ConvertTo-AesGcmEncrypted -Key $key -Plaintext "48656c6c6f20576f726c64"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Plaintext,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Nonce,

        [Parameter()]
        [AllowEmptyString()]
        [string]$AdditionalData
    )

    Initialize-AesGcmImplementation

    # Convert hex inputs to bytes
    $keyBytes = ConvertFrom-HexString $Key
    $plaintextBytes = ConvertFrom-HexString $Plaintext

    if ($keyBytes.Length -ne 32) {
        throw "Key must be 256 bits (32 bytes, 64 hex characters). Got $($keyBytes.Length) bytes."
    }

    # Generate or use provided nonce
    if ([string]::IsNullOrWhiteSpace($Nonce)) {
        $nonceBytes = New-AesGcmNonce -Size 12
    }
    else {
        $nonceBytes = ConvertFrom-HexString $Nonce
    }

    # Convert AAD if provided
    $aadBytes = if ([string]::IsNullOrWhiteSpace($AdditionalData)) {
        $null
    }
    else {
        ConvertFrom-HexString $AdditionalData
    }

    # Encrypt
    $result = Invoke-AesGcmEncrypt -Key $keyBytes -Nonce $nonceBytes -Plaintext $plaintextBytes -Aad $aadBytes

    return @{
        Ciphertext = ConvertTo-HexString $result.Ciphertext
        Tag = ConvertTo-HexString $result.Tag
        Nonce = ConvertTo-HexString $nonceBytes
    }
}

function ConvertFrom-AesGcmEncrypted {
    <#
    .SYNOPSIS
    Decrypts data using AES-256-GCM.

    .DESCRIPTION
    Decrypts ciphertext using AES-256-GCM authenticated encryption with tag verification.
    All inputs and outputs are hexadecimal strings.

    .PARAMETER Key
    The decryption key as a hexadecimal string (64 hex characters for 256-bit key).

    .PARAMETER Ciphertext
    The ciphertext to decrypt as a hexadecimal string.

    .PARAMETER Tag
    The authentication tag as a hexadecimal string (32 hex characters for 128-bit tag).

    .PARAMETER Nonce
    The nonce (IV) used during encryption as a hexadecimal string.

    .PARAMETER AdditionalData
    Optional additional authenticated data (AAD) as a hexadecimal string. Must match the AAD used during encryption.

    .OUTPUTS
    Returns the decrypted plaintext as a hexadecimal string.

    .EXAMPLE
    $plaintext = ConvertFrom-AesGcmEncrypted -Key $key -Ciphertext $result.Ciphertext -Tag $result.Tag -Nonce $result.Nonce
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Ciphertext,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Tag,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Nonce,

        [Parameter()]
        [AllowEmptyString()]
        [string]$AdditionalData
    )

    Initialize-AesGcmImplementation

    # Convert hex inputs to bytes
    $keyBytes = ConvertFrom-HexString $Key
    $ciphertextBytes = ConvertFrom-HexString $Ciphertext
    $tagBytes = ConvertFrom-HexString $Tag
    $nonceBytes = ConvertFrom-HexString $Nonce

    if ($keyBytes.Length -ne 32) {
        throw "Key must be 256 bits (32 bytes, 64 hex characters). Got $($keyBytes.Length) bytes."
    }

    if ($tagBytes.Length -ne 16) {
        throw "Tag must be 128 bits (16 bytes, 32 hex characters). Got $($tagBytes.Length) bytes."
    }

    # Convert AAD if provided
    $aadBytes = if ([string]::IsNullOrWhiteSpace($AdditionalData)) {
        $null
    }
    else {
        ConvertFrom-HexString $AdditionalData
    }

    # Decrypt
    try {
        $plaintextBytes = Invoke-AesGcmDecrypt -Key $keyBytes -Nonce $nonceBytes -Ciphertext $ciphertextBytes -Tag $tagBytes -Aad $aadBytes

        # Handle null or empty result
        if ($null -eq $plaintextBytes) {
            $plaintextBytes = [byte[]]@()
        }

        return ConvertTo-HexString $plaintextBytes
    }
    catch {
        throw "Decryption failed: $_"
    }
}

function Test-AesGcmImplementation {
    <#
    .SYNOPSIS
    Tests the AES-GCM implementation using Wycheproof test vectors.

    .DESCRIPTION
    Runs comprehensive tests using Google's Wycheproof cryptographic test suite.
    Tests include known test vectors, edge cases, and vulnerability checks.

    .PARAMETER TestVectorPath
    Path to the aes_gcm_test.json file. Defaults to TestVectors/aes_gcm_test.json.

    .PARAMETER Quick
    Run only a subset of tests for quick validation.

    .EXAMPLE
    Test-AesGcmImplementation -Verbose
    #>
    [CmdletBinding()]
    param(
        [string]$TestVectorPath = "$PSScriptRoot/TestVectors/aes_gcm_test.json",
        [switch]$Quick
    )

    if (-not (Test-Path $TestVectorPath)) {
        throw "Test vector file not found: $TestVectorPath"
    }

    Write-Host "Loading Wycheproof test vectors from $TestVectorPath"
    $testData = Get-Content $TestVectorPath -Raw | ConvertFrom-Json

    Write-Host "Testing AES-GCM implementation"
    Write-Host "Algorithm: $($testData.algorithm)"
    Write-Host "Total tests: $($testData.numberOfTests)"
    Write-Host ""

    Initialize-AesGcmImplementation

    $totalTests = 0
    $passedTests = 0
    $failedTests = 0
    $skippedTests = 0

    foreach ($group in $testData.testGroups) {
        $ivSize = $group.ivSize
        $keySize = $group.keySize
        $tagSize = $group.tagSize

        Write-Host "Testing group: IV=$ivSize bits, Key=$keySize bits, Tag=$tagSize bits"

        # Skip non-256-bit keys if Quick mode
        if ($Quick -and $keySize -ne 256) {
            $skippedTests += $group.tests.Count
            Write-Host "  Skipped $($group.tests.Count) tests (Quick mode)" -ForegroundColor Yellow
            continue
        }

        # Skip non-256-bit keys (we only support AES-256)
        if ($keySize -ne 256) {
            $skippedTests += $group.tests.Count
            Write-Verbose "  Skipped $($group.tests.Count) tests (only AES-256 supported)"
            continue
        }

        foreach ($test in $group.tests) {
            $totalTests++

            $tcId = $test.tcId
            $comment = $test.comment
            $expectedResult = $test.result

            try {
                # Test encryption
                $result = Invoke-AesGcmEncrypt `
                    -Key (ConvertFrom-HexString $test.key) `
                    -Nonce (ConvertFrom-HexString $test.iv) `
                    -Plaintext (ConvertFrom-HexString $test.msg) `
                    -Aad (ConvertFrom-HexString $test.aad)

                $actualCt = ConvertTo-HexString $result.Ciphertext
                $actualTag = ConvertTo-HexString $result.Tag

                # For valid tests, verify ciphertext and tag match
                if ($expectedResult -eq "valid") {
                    if ($actualCt -eq $test.ct -and $actualTag -eq $test.tag) {
                        # Also test decryption
                        $decrypted = Invoke-AesGcmDecrypt `
                            -Key (ConvertFrom-HexString $test.key) `
                            -Nonce (ConvertFrom-HexString $test.iv) `
                            -Ciphertext $result.Ciphertext `
                            -Tag $result.Tag `
                            -Aad (ConvertFrom-HexString $test.aad)

                        $decryptedHex = ConvertTo-HexString $decrypted
                        if ($decryptedHex -eq $test.msg) {
                            $passedTests++
                            Write-Verbose "  Test $tcId PASSED: $comment"
                        }
                        else {
                            $failedTests++
                            Write-Warning "  Test $tcId FAILED: Decryption mismatch - $comment"
                        }
                    }
                    else {
                        $failedTests++
                        Write-Warning "  Test $tcId FAILED: Encryption mismatch - $comment"
                    }
                }
                # For invalid tests, attempt decryption with provided tag
                elseif ($expectedResult -eq "invalid") {
                    try {
                        $decrypted = Invoke-AesGcmDecrypt `
                            -Key (ConvertFrom-HexString $test.key) `
                            -Nonce (ConvertFrom-HexString $test.iv) `
                            -Ciphertext (ConvertFrom-HexString $test.ct) `
                            -Tag (ConvertFrom-HexString $test.tag) `
                            -Aad (ConvertFrom-HexString $test.aad)

                        # If decryption succeeded, it should fail
                        $failedTests++
                        Write-Warning "  Test $tcId FAILED: Invalid tag was accepted - $comment"
                    }
                    catch {
                        # Expected to fail
                        $passedTests++
                        Write-Verbose "  Test $tcId PASSED: Invalid tag rejected - $comment"
                    }
                }
                else {
                    # Acceptable result - test may pass or fail
                    $passedTests++
                    Write-Verbose "  Test $tcId PASSED (acceptable): $comment"
                }
            }
            catch {
                if ($expectedResult -eq "invalid") {
                    $passedTests++
                    Write-Verbose "  Test $tcId PASSED: Correctly failed - $comment"
                }
                else {
                    $failedTests++
                    Write-Warning "  Test $tcId FAILED: Unexpected error - $comment"
                    Write-Verbose "    Error: $_"
                }
            }
        }

        Write-Host ""
    }

    # Summary
    Write-Host "============================================"
    Write-Host "Test Summary"
    Write-Host "============================================"
    Write-Host "Total tests:   $totalTests"
    Write-Host "Passed:        $passedTests" -ForegroundColor Green
    Write-Host "Failed:        $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" })
    Write-Host "Skipped:       $skippedTests" -ForegroundColor Yellow
    Write-Host "Success rate:  $([math]::Round($passedTests * 100.0 / $totalTests, 2))%"
    Write-Host "============================================"

    return @{
        Total = $totalTests
        Passed = $passedTests
        Failed = $failedTests
        Skipped = $skippedTests
    }
}

# Export cmdlets
Export-ModuleMember -Function @(
    'New-AesGcmKey',
    'New-AesGcmNonce',
    'ConvertTo-AesGcmEncrypted',
    'ConvertFrom-AesGcmEncrypted',
    'Test-AesGcmImplementation'
)
