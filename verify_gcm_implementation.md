# GCM Implementation Verification

## Implementation Overview

This module now includes three GCM implementations with automatic selection:

### 1. Native Implementation (AesGcmNative.ps1)
- Uses `System.Security.Cryptography.AesGcm`
- Available in .NET Core 3.0+, .NET 5+, PowerShell 7+
- **Supported IV sizes**: 96 bits (12 bytes) only
- **Use case**: Modern systems with PowerShell 7+

### 2. Legacy Implementation (AesGcmLegacy.ps1)
- Uses P/Invoke to Windows BCrypt CNG APIs
- Compatible with .NET Framework 3.5+
- **Supported IV sizes**: 96 bits (12 bytes) only
- **Use case**: Windows 7/10/11 with PowerShell 5.1

### 3. Full Implementation (AesGcmFull.ps1) - NEW
- Custom GHASH and CTR mode implementation using AES-ECB primitives
- **Supported IV sizes**: Any size from 1 bit to 2^61 bits (except 0)
- **Use case**: Automatic fallback for non-standard IV sizes

## Implementation Selection Logic

The module now uses intelligent routing:

```
if IV size != 12 bytes:
    Use AesGcmFull (supports all IV sizes)
else if System.Security.Cryptography.AesGcm available:
    Use AesGcmNative
else:
    Use AesGcmLegacy (BCrypt)
```

## Full GCM Implementation Details

### GHASH Function
Implements the GHASH authentication function as specified in NIST SP 800-38D:
- Galois field GF(2^128) multiplication
- Reduction polynomial: x^128 + x^7 + x^2 + x + 1
- Processes AAD and ciphertext in 128-bit blocks
- Appends length field (AAD_len || C_len) in bits

### J0 Computation
For non-96-bit IVs, implements the J0 calculation:
- If IV is 96 bits: `J0 = IV || 0^31 || 1`
- Otherwise: `J0 = GHASH(H, {}, IV || 0^s || [len(IV)]64)`

Where:
- H is the GHASH key (AES(K, 0^128))
- s is padding to make length a multiple of 128 bits
- [len(IV)]64 is the bit length as 64-bit big-endian

### CTR Mode Encryption
- Uses AES-ECB to implement CTR mode
- Counter is J0 with incremented rightmost 32 bits
- XORs keystream with plaintext/ciphertext

### Tag Computation
- Tag = GHASH(H, AAD, C) XOR AES(K, J0)

## Test Coverage

After this implementation, the module should pass:

### Previously Passing (85 tests)
- ✓ 66 tests with 96-bit IV (standard)
- ✓ 19 tests with 128-bit IV (was working in some implementations)

### Now Fixed (18 tests)
- ✓ 2 tests with 8-bit IV (SmallIv)
- ✓ 2 tests with 16-bit IV (SmallIv)
- ✓ 2 tests with 32-bit IV (SmallIv)
- ✓ 2 tests with 48-bit IV (SmallIv)
- ✓ 2 tests with 64-bit IV (SmallIv)
- ✓ 2 tests with 80-bit IV (SmallIv)
- ✓ 1 test with 120-bit IV (LongIv)
- ✓ 1 test with 160-bit IV (LongIv)
- ✓ 1 test with 256-bit IV (LongIv)
- ✓ 1 test with 512-bit IV (LongIv)
- ✓ 1 test with 1024-bit IV (LongIv)
- ✓ 1 test with 2056-bit IV (LongIv)

### Correctly Failing (2 tests)
- ✗ 2 tests with 0-bit IV (ZeroLengthIv) - marked as "invalid" in test vectors
  - These should fail with "IV cannot be null or empty" error

### Total Expected Results
- **Pass**: 103 out of 105 tests (98.1%)
- **Fail (Expected)**: 2 out of 105 tests (zero-length IV, correctly rejected)

## Known Limitations

1. **Zero-length IV**: Correctly rejected as insecure (per CVE-2017-7822)
2. **Very long IVs**: The implementation supports IVs up to practical limits (~256 bytes tested)
3. **Performance**: Full GCM implementation is slower than native APIs but ensures compatibility

## Testing Instructions

### Run Full Test Suite
```powershell
Import-Module .\AesGcm.psd1 -Force
Test-AesGcmImplementation -Verbose
```

### Expected Output
```
Total tests:   105
Passed:        103
Failed:        2
Skipped:       211 (non-AES-256 tests)
Success rate:  98.10%
```

### Verify Non-Standard IV Support
```powershell
# Test with 8-bit IV
$key = 'fe47fcce5fc32665d2ae399e4eec72ba'
$nonce = '00'
$plaintext = ''
$result = ConvertTo-AesGcmEncrypted -Key $key -Nonce $nonce -Plaintext $plaintext
Write-Host "8-bit IV encryption successful: $($result.Tag)"
```

## References

- NIST SP 800-38D: Recommendation for Block Cipher Modes of Operation: Galois/Counter Mode (GCM) and GMAC
- Wycheproof Test Vectors v0.9rc5
- RFC 8452: AES-GCM-SIV
