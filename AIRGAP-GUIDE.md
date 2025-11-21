# Air-Gapped System Quick Setup Guide

## Step 1: Detect Capabilities

Type and run `airgap-detect.ps1` first. This will tell you which implementation to use.

**Quick detection commands** (if you don't want to type the full script):

```powershell
# Test Modern (PowerShell 7+ or .NET 5+)
try { [System.Security.Cryptography.AesGcm]; "USE MODERN" } catch { "Not available" }

# Test Legacy (Windows 7+ BCrypt)
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class T { [DllImport("bcrypt.dll")] public static extern uint BCryptOpenAlgorithmProvider(out IntPtr h, string id, string impl, uint f); }'
$h=[IntPtr]::Zero; if([T]::BCryptOpenAlgorithmProvider([ref]$h,"AES",$null,0)-eq 0){"USE LEGACY"}else{"Not available"}

# Fallback (always available if AES works)
try { $a=[System.Security.Cryptography.Aes]::Create(); $a.Dispose(); "USE FULL" } catch { "Error" }
```

## Step 2: Type the Implementation

Based on detection results, type ONE of these files:

| Detection Result | File to Type | Lines | Complexity |
|-----------------|--------------|-------|------------|
| **MODERN** | `airgap-modern.ps1` | ~45 | ⭐ Easiest |
| **LEGACY** | `airgap-legacy.ps1` | ~120 | ⭐⭐ Medium |
| **FULL** | `airgap-full.ps1` | ~150 | ⭐⭐⭐ Complex |

## Step 3: Usage

After typing the implementation, you have these functions:

```powershell
# Encrypt
$result = Encrypt-AesGcm -key '<32-byte-hex>' -nonce '<12-byte-hex>' -plaintext '<hex>' -aad '<hex>'
# Returns: @{ Ciphertext = '<hex>'; Tag = '<hex>' }

# Decrypt
$plain = Decrypt-AesGcm -key '<32-byte-hex>' -nonce '<12-byte-hex>' -ciphertext '<hex>' -tag '<16-byte-hex>' -aad '<hex>'
# Returns: '<hex-plaintext>'
```

## Compact Decision Tree

```
┌─ Is System.Security.Cryptography.AesGcm available? ──YES─> Type MODERN (easiest)
│
├─ Is BCrypt CNG available? ──YES─> Type LEGACY (recommended for .NET Framework)
│
└─ Fallback ──> Type FULL (works everywhere, supports all IV sizes)
```

## Key Differences

| Feature | Modern | Legacy | Full |
|---------|--------|--------|------|
| **Lines to type** | 45 | 120 | 150 |
| **PowerShell 7+** | ✅ | ✅ | ✅ |
| **PowerShell 5.1** | ❌ | ✅ | ✅ |
| **Windows 7** | ❌ | ✅ | ✅ |
| **12-byte IV** | ✅ | ✅ | ✅ |
| **Other IV sizes** | ❌ | ❌ | ✅ |
| **Performance** | Fastest | Fast | Slower |

## Examples

### Generate Random Key/Nonce (any implementation)
```powershell
# 32-byte (256-bit) key
$key = -join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })

# 12-byte (96-bit) nonce
$nonce = -join ((1..12) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })
```

### Encrypt Text Message
```powershell
# Convert text to hex
$text = "Hello World"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
$hex = ($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join ''

# Encrypt
$result = Encrypt-AesGcm $key $nonce $hex
Write-Host "Ciphertext: $($result.Ciphertext)"
Write-Host "Tag: $($result.Tag)"

# Decrypt
$plainHex = Decrypt-AesGcm $key $nonce $result.Ciphertext $result.Tag
$plainBytes = [byte[]]::new($plainHex.Length/2)
for ($i=0; $i -lt $plainHex.Length; $i+=2) {
    $plainBytes[$i/2] = [Convert]::ToByte($plainHex.Substring($i,2),16)
}
$plainText = [System.Text.Encoding]::UTF8.GetString($plainBytes)
Write-Host "Decrypted: $plainText"
```

### Authentication-Only (Empty Plaintext)
```powershell
$result = Encrypt-AesGcm $key $nonce '' -aad 'deadbeef'
# Tag authenticates the AAD only
```

## Minimal One-Liner Detection

If you only want to know which to use without typing the full detection script:

```powershell
if($(try{[System.Security.Cryptography.AesGcm];1}catch{0})){"MODERN"}elseif($(try{Add-Type -TD 'using System;using System.Runtime.InteropServices;public class X{[DllImport("bcrypt.dll")]public static extern uint BCryptOpenAlgorithmProvider(out IntPtr h,string i,string p,uint f);}';$h=[IntPtr]::Zero;[X]::BCryptOpenAlgorithmProvider([ref]$h,"AES",$null,0)-eq 0}catch{0})){"LEGACY"}else{"FULL"}
```

## Tips for Manual Typing

1. **Start with detection** - Know which implementation you need before typing
2. **Modern is shortest** - Only 45 lines, prefer if available
3. **Copy-paste hex values** - Don't type long hex strings manually
4. **Test as you go** - Each script has a built-in test at the end
5. **Save to file** - Type into notepad, save as `.ps1`, then run
6. **Watch for typos** - PowerShell is case-insensitive but symbols matter

## Troubleshooting

| Error | Cause | Solution |
|-------|-------|----------|
| "Cannot find type" | Add-Type failed | Restart PowerShell, try again |
| "Authentication tag mismatch" | Wrong key/nonce/tag | Verify all parameters match |
| "Invalid hex string" | Odd-length hex | Hex strings must have even length |
| BCrypt status != 0 | BCrypt call failed | Check Windows version, try FULL |

## Storage Recommendations

Once typed and tested on air-gapped system:
- Save to `.ps1` file for reuse
- Document which implementation you're using
- Keep key/nonce generation commands handy
- Test with known vectors before production use
