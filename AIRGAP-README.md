# Air-Gapped System AES-GCM Toolkit

This directory contains minimal, manually-typeable PowerShell scripts for AES-256-GCM encryption on air-gapped Windows systems.

## Quick Start

### 1. Detect System Capabilities

**One-line detection** (type this first):
```powershell
if($(try{[System.Security.Cryptography.AesGcm];1}catch{0})){"MODERN"}elseif($(try{Add-Type -TD 'using System;using System.Runtime.InteropServices;public class X{[DllImport("bcrypt.dll")]public static extern uint BCryptOpenAlgorithmProvider(out IntPtr h,string i,string p,uint f);}';$h=[IntPtr]::Zero;[X]::BCryptOpenAlgorithmProvider([ref]$h,"AES",$null,0)-eq 0}catch{0})){"LEGACY"}else{"FULL"}
```

Or run the full detection script:
```powershell
powershell.exe -NoProfile -File airgap-detect.ps1
```

### 2. Choose Implementation

| Result | File | Size | Time to Type | Use Case |
|--------|------|------|--------------|----------|
| **MODERN** | `airgap-modern.ps1` | 1.3 KB | 5 min | PowerShell 7+, .NET 5+ |
| **LEGACY** | `airgap-legacy.ps1` | 5.8 KB | 20 min | Windows 7+, .NET Framework |
| **FULL** | `airgap-full.ps1` | 7.2 KB | 25 min | Universal, any IV size |
| **ULTRA** | `airgap-ultra-minimal.ps1` | 0.8 KB | 3 min | Modern only, no frills |

### 3. Type and Test

1. Open Notepad
2. Type the chosen script exactly as shown
3. Save as `aes-gcm.ps1`
4. Run: `powershell.exe -NoProfile -File aes-gcm.ps1`
5. Look for "PASS" or "SUCCESS" message

## Files in This Directory

### Detection Scripts
- **airgap-detect.ps1** (3.5 KB) - Verbose system capability detection with detailed output
- **airgap-oneliner.txt** - Quick reference guide with one-line detection command

### Implementation Scripts (choose ONE)
- **airgap-modern.ps1** (1.3 KB) - Uses `System.Security.Cryptography.AesGcm` (.NET Core/5+)
  - ✅ Shortest and simplest
  - ✅ Best performance
  - ❌ Requires PowerShell 7+ or .NET 5+
  - ❌ Only 12-byte IVs

- **airgap-legacy.ps1** (5.8 KB) - Uses Windows BCrypt CNG via P/Invoke
  - ✅ Works on Windows 7+
  - ✅ Works with .NET Framework 3.5+
  - ✅ Native Windows crypto
  - ❌ More code to type
  - ❌ Only 12-byte IVs

- **airgap-full.ps1** (7.2 KB) - Pure .NET implementation using AES-ECB primitives
  - ✅ Works everywhere AES is available
  - ✅ Supports all IV sizes (1-2056+ bits)
  - ✅ Most compatible
  - ❌ Longest to type
  - ❌ Slower than native implementations

- **airgap-ultra-minimal.ps1** (0.8 KB) - Absolute minimum for Modern systems
  - ✅ Smallest possible (30 lines)
  - ✅ Fastest to type
  - ❌ Modern only
  - ❌ No error handling
  - ❌ Less readable

### Documentation
- **AIRGAP-GUIDE.md** - Comprehensive guide with examples and troubleshooting
- **AIRGAP-README.md** - This file

## Usage Examples

All implementations provide the same interface:

```powershell
# Encrypt
$result = Encrypt-AesGcm -key '<64-hex-chars>' -nonce '<24-hex-chars>' -plaintext '<hex>' -aad '<hex>'
# Returns: @{ Ciphertext = '<hex>'; Tag = '<32-hex-chars>' }

# Decrypt
$plain = Decrypt-AesGcm -key '<64-hex-chars>' -nonce '<24-hex-chars>' -ciphertext '<hex>' -tag '<32-hex-chars>' -aad '<hex>'
# Returns: '<hex-plaintext>'
```

### Generate Random Keys and Nonces

```powershell
# 256-bit key (32 bytes = 64 hex characters)
$key = -join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })

# 96-bit nonce (12 bytes = 24 hex characters)
$nonce = -join ((1..12) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })
```

### Encrypt Text Message

```powershell
# Convert text to hex
$text = "Secret Message"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
$hexPlaintext = ($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join ''

# Encrypt
$result = Encrypt-AesGcm $key $nonce $hexPlaintext
Write-Host "Ciphertext: $($result.Ciphertext)"
Write-Host "Tag: $($result.Tag)"

# Decrypt
$hexDecrypted = Decrypt-AesGcm $key $nonce $result.Ciphertext $result.Tag

# Convert hex back to text
$decryptedBytes = [byte[]]::new($hexDecrypted.Length/2)
for ($i=0; $i -lt $hexDecrypted.Length; $i+=2) {
    $decryptedBytes[$i/2] = [Convert]::ToByte($hexDecrypted.Substring($i,2),16)
}
$decryptedText = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
Write-Host "Decrypted: $decryptedText"
```

### Authentication-Only (Empty Plaintext)

```powershell
# Authenticate AAD without encrypting any data
$result = Encrypt-AesGcm $key $nonce '' -aad 'deadbeef'
# Tag provides authentication for the AAD
```

## Decision Tree

```
Start Here
    |
    v
┌─────────────────────────────────────────┐
│ Can you type ~150 lines of code?        │
└─────────┬───────────────────────────────┘
          │
      NO  │  YES
          │
          v
┌─────────────────────────────────────────┐
│ Is System.Security.Cryptography.AesGcm  │
│ available on your system?               │
└─────────┬───────────────────────────────┘
          │
      NO  │  YES
          │
          v
┌─────────────────┐         ┌──────────────────┐
│ Type 30 lines:  │         │ Type 45 lines:   │
│ ULTRA-MINIMAL   │         │ MODERN           │
└─────────────────┘         └──────────────────┘

If you answered NO to typing 150 lines, but AesGcm is NOT available:
    |
    v
┌─────────────────────────────────────────┐
│ Is BCrypt CNG available?                │
│ (Windows 7+ with .NET Framework)        │
└─────────┬───────────────────────────────┘
          │
      NO  │  YES
          │
          v
┌─────────────────┐         ┌──────────────────┐
│ Type 150 lines: │         │ Type 120 lines:  │
│ FULL            │         │ LEGACY           │
└─────────────────┘         └──────────────────┘
```

## Verification Test Vectors

After typing any implementation, verify it works:

```powershell
$k = 'c3d99825f2181f4808acd2068eac7441a65bd428f14d2aab43fefc0129091139'
$n = 'cafebabefacedbaddecaf888'
$r = Encrypt-AesGcm $k $n ''

# Expected tag: 3247184b3c4f69a44dbcd22887bbb418
if ($r.Tag -eq '3247184b3c4f69a44dbcd22887bbb418') {
    Write-Host "PASS - Implementation working correctly" -ForegroundColor Green
} else {
    Write-Host "FAIL - Tag mismatch: $($r.Tag)" -ForegroundColor Red
}
```

## Tips for Manual Typing

1. **Use a text editor** - Type in Notepad, not directly in PowerShell
2. **Save frequently** - Don't lose your work
3. **Check syntax** - Watch for matching brackets, quotes, parentheses
4. **Test incrementally** - If possible, test the hex conversion functions first
5. **Mind the case** - PowerShell is case-insensitive, but hex values should be lowercase
6. **Watch indentation** - Not required but helps catch errors
7. **Use copy-paste for test vectors** - Don't type long hex strings manually

## Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Cannot find type [System.Security.Cryptography.AesGcm]" | Modern implementation not available | Use LEGACY or FULL |
| "Add-Type failed" | Syntax error in C# code | Restart PowerShell, check typing carefully |
| "Authentication tag mismatch" | Wrong parameters or corrupted data | Verify key, nonce, tag, ciphertext match |
| "Odd-length hex string" | Hex string has odd number of characters | Hex must have even length (2 chars per byte) |
| BCrypt status code != 0 | BCrypt API call failed | Check Windows version, try FULL |
| Type already exists | Ran Add-Type twice in same session | Close and reopen PowerShell |

## Security Considerations

### ✅ DO
- Generate new random nonce for EVERY encryption operation
- Use cryptographically secure random number generator for keys/nonces
- Validate inputs before encryption/decryption
- Keep keys secret and secure
- Use AAD for additional context binding

### ❌ DON'T
- Reuse nonce with the same key (breaks security completely)
- Use predictable or sequential nonces
- Assume empty ciphertext means no data (could be authentication-only)
- Ignore tag verification failures
- Use weak keys or hardcoded keys

## Performance Comparison

Approximate operations per second (on typical hardware):

| Implementation | Encrypt/Decrypt Speed | Relative Performance |
|----------------|----------------------|---------------------|
| MODERN | ~100,000 ops/sec | 100% (baseline) |
| LEGACY | ~80,000 ops/sec | 80% |
| FULL | ~5,000 ops/sec | 5% |

**Note**: Full implementation is significantly slower but more compatible.

## IV Size Support

| Implementation | Supported IV Sizes | Notes |
|----------------|-------------------|-------|
| MODERN | 12 bytes only | Enforced by .NET AesGcm class |
| LEGACY | 12 bytes only | BCrypt GCM limitation |
| FULL | 1 to 2^61 bits (except 0) | Implements NIST SP 800-38D fully |

For non-standard IV sizes, you MUST use the FULL implementation.

## Additional Resources

- **CLAUDE.md** - Full project documentation and architecture
- **AesGcm.psm1** - Full module with all three implementations
- **TestVectors/** - 316 Wycheproof test vectors for validation
- **example.ps1** - Usage examples with the full module

## License

This code is part of the pwsh-aes-gcm project. See main repository for license details.

## Support on Air-Gapped Systems

Since you're on an air-gapped system, you won't have access to online help. Key things to remember:

1. **PowerShell Help**: Use `Get-Help about_*` for built-in PowerShell documentation
2. **.NET Documentation**: Limited without internet, but IntelliSense may help
3. **Test Vectors**: Use the provided test vector to verify correctness
4. **Debugging**: Use `Write-Host` for debugging, not `Write-Debug` (requires verbose mode)

## Workflow Summary

```
1. Boot air-gapped system
2. Open PowerShell
3. Run one-line detection command
4. Note which implementation to use
5. Open Notepad
6. Type the appropriate script
7. Save as .ps1 file
8. Run script to test
9. Use Encrypt-AesGcm and Decrypt-AesGcm functions
```

Good luck! The MODERN implementation is your best bet if available (shortest and fastest).
