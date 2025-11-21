# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PowerShell module for AES-256-GCM authenticated encryption designed for **air-gapped Windows systems** (Windows 7/10/11). It uses only native .NET capabilities with no external dependencies.

## Architecture

### Dual-Implementation Strategy

The module implements **automatic runtime detection with graceful fallback**:

1. **Modern Path** (`Classes/AesGcmNative.ps1`):
   - Uses `System.Security.Cryptography.AesGcm` class
   - Available in .NET Core 3.0+, .NET 5+, PowerShell 7+
   - Simple wrapper functions around native API

2. **Legacy Path** (`Classes/AesGcmLegacy.ps1`):
   - Uses P/Invoke to Windows BCrypt CNG APIs (`bcrypt.dll`)
   - Compatible with .NET Framework 3.5+ (Windows 7+)
   - Implements full BCrypt interop with proper handle management
   - Defines C# P/Invoke signatures via `Add-Type` at runtime

**Selection Logic** (`AesGcm.psm1:Initialize-AesGcmImplementation`):
- First attempts to detect `System.Security.Cryptography.AesGcm` type
- Falls back to BCrypt P/Invoke if native type unavailable
- Selection happens once per module load and is cached

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

### Namespace Conventions

- BCrypt code uses `AesGcmBCrypt` namespace
- All P/Invoke definitions are in nested `BCryptNative` static class
- Main implementation is in `AesGcmCng` static class

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
- **66+ tests should pass** (62.86%+)
- **39 failures are expected** (edge cases with non-standard IV sizes)
- Tests 92-93 validate empty plaintext handling
- Tests 240-258 are counter wrap tests that may fail on some platforms

## Key Files

- **AesGcm.psm1**: Main module with public cmdlets and implementation routing
- **AesGcm.psd1**: Module manifest (defines exported functions)
- **Classes/AesGcmNative.ps1**: .NET Core/5+ implementation
- **Classes/AesGcmLegacy.ps1**: BCrypt P/Invoke for .NET Framework
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
