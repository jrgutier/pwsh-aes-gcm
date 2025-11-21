# Contributing to AES-GCM PowerShell Module

Thank you for your interest in contributing! This guide will help you get started.

## Development Workflow

### 1. Setting Up Your Environment

```powershell
# Clone the repository
git clone https://github.com/YOUR_USERNAME/pwsh-aes-gcm.git
cd pwsh-aes-gcm

# Import the module
Import-Module .\AesGcm.psd1 -Force -Verbose
```

### 2. Making Changes

1. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make your changes** following the coding standards below

3. **Test your changes** thoroughly:
   ```powershell
   # Run the full test suite
   Import-Module .\AesGcm.psd1 -Force
   Test-AesGcmImplementation -Verbose

   # Run example scripts
   .\example.ps1
   .\test-empty.ps1
   ```

### 3. Pre-Push Verification

**Before pushing**, run the pre-push verification script to catch issues early:

```powershell
# Full check (recommended)
.\pre-push-check.ps1

# Quick check (syntax and imports only)
.\pre-push-check.ps1 -Quick

# Skip test suite
.\pre-push-check.ps1 -SkipTests
```

This script validates:
- ✓ PowerShell syntax
- ✓ Module manifest
- ✓ PSScriptAnalyzer rules
- ✓ Module import and smoke test
- ✓ Full test suite (unless skipped)

### 4. Submitting Changes

```bash
# Commit your changes
git add .
git commit -m "feat: add new feature"

# Push to your branch
git push origin feature/my-feature
```

Then create a pull request on GitHub.

## Coding Standards

### PowerShell Style Guide

1. **Use approved verbs** for function names: `Get-`, `Set-`, `New-`, `Remove-`, etc.
2. **Follow PascalCase** for function and parameter names
3. **Add comment-based help** to all public functions
4. **Use explicit parameter types** with validation attributes
5. **Handle empty data** with `[AllowEmptyString()]` and `[AllowEmptyCollection()]` where appropriate

### Example Function

```powershell
function Get-Example {
    <#
    .SYNOPSIS
    Brief description of what the function does.

    .DESCRIPTION
    Detailed description with more context.

    .PARAMETER Name
    Description of the parameter.

    .EXAMPLE
    Get-Example -Name "test"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    # Implementation
}
```

### Code Quality

- **Run PSScriptAnalyzer** before committing:
  ```powershell
  Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
  Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery
  ```

- **Fix all errors** and address warnings where reasonable
- **Write tests** for new features (add to `Test-AesGcmImplementation`)
- **Update documentation** as needed

## Project-Specific Guidelines

### Air-Gapped Compatibility

This module **must work on air-gapped systems**:

- ❌ **NO external dependencies** (NuGet packages, external DLLs)
- ❌ **NO internet-dependent features**
- ✓ **Only native .NET** and Windows BCrypt APIs

### Hex String Interface

All public APIs use **hexadecimal strings**, not byte arrays:

```powershell
# ✓ Correct
$key = New-AesGcmKey -AsHex
$result = ConvertTo-AesGcmEncrypted -Key $key -Plaintext "48656c6c6f"

# ❌ Wrong (internal use only)
$keyBytes = New-Object byte[] 32
Invoke-AesGcmEncrypt -Key $keyBytes -Plaintext $plaintextBytes
```

### Implementation Selection

The module uses **automatic runtime detection**:

1. Tries native `System.Security.Cryptography.AesGcm` (.NET Core/5+, PowerShell 7+)
2. Falls back to BCrypt P/Invoke (.NET Framework, PowerShell 5.1)

**Do not hardcode** implementation selection.

### BCrypt P/Invoke Changes

If modifying `Classes/AesGcmLegacy.ps1`:

- ⚠ Changes require **module reload** (PowerShell caches compiled types)
- Test in **fresh session**: `powershell.exe -NoProfile -File test.ps1`
- Handle **zero-length arrays** by passing `null` to BCrypt
- Ensure **proper cleanup** of `GCHandle` in finally blocks

## Testing

### Running Tests

```powershell
# Full test suite (105 AES-256 tests)
Import-Module .\AesGcm.psd1 -Force
Test-AesGcmImplementation -Verbose

# Quick validation
Test-AesGcmImplementation -Quick

# Test with PowerShell 5.1 (if on Windows)
powershell.exe -NoProfile -Command "Import-Module .\AesGcm.psd1 -Force; Test-AesGcmImplementation"
```

### Expected Test Results

- **105 tests executed** (AES-256 only, from 316 total Wycheproof vectors)
- **66+ tests should pass** (62.86%+)
- **39 failures are expected** (edge cases with non-standard IV sizes)

### Adding Tests

Wycheproof test vectors are in `TestVectors/aes_gcm_test.json`. The test function filters for AES-256 only.

## CI/CD Workflows

All pull requests automatically run:

1. **CI Workflow** - Matrix testing on Windows 2019/2022/latest with PowerShell 5.1 and 7.x
2. **Code Quality** - PSScriptAnalyzer linting and security scanning
3. **Implementation Verification** - Tests both native and BCrypt paths

Workflows must pass before merging.

## Common Pitfalls

1. **Type Compilation Caching**: Changes to `Add-Type` C# code require new PowerShell session
2. **Empty Array Handling**: BCrypt expects `null` for zero-length arrays, not `byte[0]`
3. **Parameter Validation**: Use `[AllowEmptyString()]` for hex strings that can be empty
4. **Module Version**: Remember to update version in `AesGcm.psd1` for releases

## Getting Help

- **Documentation**: See [README.md](README.md) and [CLAUDE.md](CLAUDE.md)
- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions for questions

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing! 🎉
