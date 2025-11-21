# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PowerShell module for AES-256-GCM authenticated encryption designed for **air-gapped Windows systems** (Windows 7/10/11). It uses only native .NET capabilities with no external dependencies.

## Architecture

### Triple-Implementation Strategy

The module implements **automatic runtime detection with graceful fallback** and **variable IV size support**:

1. **Modern Path** (`Classes/AesGcmNative.ps1`):
   - Uses `System.Security.Cryptography.AesGcm` class
   - Available in .NET Core 3.0+, .NET 5+, PowerShell 7+
   - Simple wrapper functions around native API
   - **IV Support**: 96 bits (12 bytes) only

2. **Legacy Path** (`Classes/AesGcmLegacy.ps1`):
   - Uses P/Invoke to Windows BCrypt CNG APIs (`bcrypt.dll`)
   - Compatible with .NET Framework 3.5+ (Windows 7+)
   - Implements full BCrypt interop with proper handle management
   - Defines C# P/Invoke signatures via `Add-Type` at runtime
   - **IV Support**: 96 bits (12 bytes) only

3. **Full GCM Path** (`Classes/AesGcmFull.ps1`):
   - Custom GHASH and CTR mode implementation using AES-ECB primitives
   - Supports **variable IV sizes** (1-2056+ bits, any length except 0)
   - Implements NIST SP 800-38D specification fully
   - Automatic fallback for non-standard IV sizes
   - **IV Support**: All sizes (1 bit to 2^61 bits, except 0)

**Selection Logic** (`AesGcm.psm1:Invoke-AesGcmEncrypt/Decrypt`):
- If IV size is not 12 bytes: Uses Full GCM implementation (supports all sizes)
- Else if `System.Security.Cryptography.AesGcm` available: Uses Native implementation
- Else: Uses Legacy BCrypt implementation
- Selection happens per operation based on IV size

### Module Entry Points

**Main module** (`AesGcm.psm1`):
- Loads both implementation classes via dot-sourcing
- Provides unified wrapper functions: `Invoke-AesGcmEncrypt`, `Invoke-AesGcmDecrypt`
- Exposes public cmdlets with hex string interface
- Handles parameter validation and empty data edge cases

**Hex string conversion** is centralized in `ConvertFrom-HexString` and `ConvertTo-HexString` functions.

## Critical Implementation Details

### Empty Plaintext/Ciphertext Handling

Empty data (authentication-only mode) requires special handling:

1. **PowerShell side**: Must use `[AllowEmptyString()]` and `[AllowEmptyCollection()]` attributes
2. **BCrypt side**: Pass `null` to `BCryptEncrypt`/`BCryptDecrypt` instead of zero-length arrays
3. **Return values**: Ensure empty arrays are returned, not null

### BCrypt P/Invoke Structure

The `AesGcmLegacy.ps1` implementation:
- Compiles C# code at runtime using `Add-Type`
- Defines `BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO` struct with proper layout
- Uses `GCHandle.Alloc` with pinning for nonce, tag, and AAD pointers
- Requires proper resource cleanup in finally blocks
- Zero-length data must be handled with null pointers, not empty arrays

### Full GCM Implementation Structure

The `AesGcmFull.ps1` implementation:
- Compiles C# code at runtime using `Add-Type`
- Implements GHASH using Galois field GF(2^128) multiplication
- Implements CTR mode using AES-ECB primitives
- Computes J0 (initial counter) according to NIST SP 800-38D:
  * For 96-bit IVs: `J0 = IV || 0^31 || 1`
  * For other sizes: `J0 = GHASH(H, {}, IV || 0^s || [len(IV)]64)`
- Correctly handles all IV sizes except zero-length
- Uses `AesGcmFull` namespace for all classes

### Namespace Conventions

- Native code (when available): Uses `System.Security.Cryptography.AesGcm`
- BCrypt code uses `AesGcmBCrypt` namespace (P/Invoke definitions in `BCryptNative`, implementation in `AesGcmCng`)
- Full GCM code uses `AesGcmFull` namespace (`GaloisFieldMultiplier` and `AesGcmEngine` classes)

## Testing

### Run Full Test Suite
```powershell
Import-Module .\AesGcm.psd1 -Force
Test-AesGcmImplementation -Verbose
```

### Run Quick Validation
```powershell
Test-AesGcmImplementation -Quick
```

### Test Specific Scenario
```powershell
powershell.exe -NoProfile -File .\test-empty.ps1
```

### Run Usage Examples
```powershell
powershell.exe -NoProfile -File .\example.ps1
```

### Test Results Expectations
- **105 tests executed** (AES-256 only, out of 316 total)
- **103 tests should pass** (98.10%)
- **2 failures are expected** (zero-length IV tests, correctly rejected as invalid)
- Tests 92-93 validate empty plaintext handling (should pass)
- Tests 299-310 validate small IV sizes 8-80 bits (should pass with full GCM)
- Tests 263-276 validate long IV sizes 120-2056 bits (should pass with full GCM)
- Tests 315-316 validate zero-length IV rejection (should fail with error)

## Key Files

- **AesGcm.psm1**: Main module with public cmdlets and implementation routing
- **AesGcm.psd1**: Module manifest (defines exported functions)
- **Classes/AesGcmNative.ps1**: .NET Core/5+ implementation (96-bit IV only)
- **Classes/AesGcmLegacy.ps1**: BCrypt P/Invoke for .NET Framework (96-bit IV only)
- **Classes/AesGcmFull.ps1**: Full GCM with GHASH (all IV sizes)
- **TestVectors/aes_gcm_test.json**: 316 Wycheproof test vectors (v0.9rc5)

## Development Constraints

### Critical Requirements
- **No external dependencies**: Cannot use NuGet packages or external DLLs
- **Air-gapped compatible**: Must work without internet access
- **Hex string interface**: All public APIs use hex strings, not byte arrays
- **Only AES-256**: AES-128 and AES-192 are not supported

### Parameter Validation
When modifying cmdlets, remember:
- Use `[AllowEmptyString()]` for hex string parameters that can be empty
- Use `[AllowEmptyCollection()]` for byte arrays that can be empty
- Use `[ValidateNotNullOrEmpty()]` for required non-empty parameters
- Empty plaintext/ciphertext is valid (authentication-only mode)

### BCrypt Modifications
If modifying `AesGcmLegacy.ps1`:
- Changes to C# code require module reload (PowerShell caches compiled types)
- Test with fresh PowerShell session: `powershell.exe -NoProfile -File test.ps1`
- Always handle zero-length arrays by passing null to BCrypt functions
- Ensure proper `GCHandle` cleanup in finally blocks

## Common Pitfalls

1. **PowerShell Class Limitations**: PowerShell 5.1 has poor class support - use functions, not classes
2. **Type Compilation Caching**: `Add-Type` compiles once per session - changing C# code requires new session
3. **Empty Array Handling**: BCrypt expects null for zero-length arrays, not `byte[0]`
4. **Hex String Validation**: Must allow empty strings with `[AllowEmptyString()]` attribute
5. **Implementation Selection**: Don't hardcode implementation choice - let runtime detection decide

## Module Installation

```powershell
Import-Module .\AesGcm.psd1
```

No build or compilation step needed - module loads dynamically.
