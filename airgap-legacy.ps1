# LEGACY Implementation - For Windows 7+ with BCrypt CNG
# Use this if airgap-detect.ps1 shows LEGACY (no modern AesGcm)

function ConvertFrom-Hex($h) {
    if (!$h) { return @() }
    $b = [byte[]]::new($h.Length/2)
    for ($i=0; $i -lt $h.Length; $i+=2) {
        $b[$i/2] = [Convert]::ToByte($h.Substring($i,2),16)
    }
    return $b
}

function ConvertTo-Hex($b) {
    return ($b | ForEach-Object { $_.ToString('x2') }) -join ''
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class BCrypt {
    [DllImport("bcrypt.dll")]
    public static extern uint BCryptOpenAlgorithmProvider(out IntPtr h, string id, string impl, uint flags);
    [DllImport("bcrypt.dll")]
    public static extern uint BCryptCloseAlgorithmProvider(IntPtr h, uint flags);
    [DllImport("bcrypt.dll")]
    public static extern uint BCryptSetProperty(IntPtr h, string prop, byte[] val, int len, uint flags);
    [DllImport("bcrypt.dll")]
    public static extern uint BCryptGenerateSymmetricKey(IntPtr h, out IntPtr hKey, IntPtr buf, int bufLen, byte[] key, int keyLen, uint flags);
    [DllImport("bcrypt.dll")]
    public static extern uint BCryptDestroyKey(IntPtr hKey);
    [DllImport("bcrypt.dll")]
    public static extern uint BCryptEncrypt(IntPtr hKey, byte[] input, int inputLen, ref BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO authInfo, byte[] iv, int ivLen, byte[] output, int outputLen, out int written, uint flags);
    [DllImport("bcrypt.dll")]
    public static extern uint BCryptDecrypt(IntPtr hKey, byte[] input, int inputLen, ref BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO authInfo, byte[] iv, int ivLen, byte[] output, int outputLen, out int written, uint flags);
    [StructLayout(LayoutKind.Sequential)]
    public struct BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO {
        public int cbSize;
        public uint dwInfoVersion;
        public IntPtr pbNonce;
        public int cbNonce;
        public IntPtr pbAuthData;
        public int cbAuthData;
        public IntPtr pbTag;
        public int cbTag;
        public IntPtr pbMacContext;
        public int cbMacContext;
        public int cbAAD;
        public long cbData;
        public uint dwFlags;
    }
}
'@

function Encrypt-AesGcm($key, $nonce, $plaintext, $aad='') {
    $k = ConvertFrom-Hex $key
    $n = ConvertFrom-Hex $nonce
    $p = ConvertFrom-Hex $plaintext
    $a = ConvertFrom-Hex $aad
    $hAlg = [IntPtr]::Zero
    $hKey = [IntPtr]::Zero
    $ghN = $null; $ghT = $null; $ghA = $null
    try {
        [BCrypt]::BCryptOpenAlgorithmProvider([ref]$hAlg, 'AES', $null, 0) | Out-Null
        $mode = [System.Text.Encoding]::Unicode.GetBytes('ChainingModeGCM')
        [BCrypt]::BCryptSetProperty($hAlg, 'ChainingMode', $mode, $mode.Length, 0) | Out-Null
        [BCrypt]::BCryptGenerateSymmetricKey($hAlg, [ref]$hKey, [IntPtr]::Zero, 0, $k, $k.Length, 0) | Out-Null
        $tag = [byte[]]::new(16)
        $authInfo = New-Object BCrypt+BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO
        $authInfo.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($authInfo)
        $authInfo.dwInfoVersion = 1
        $ghN = [System.Runtime.InteropServices.GCHandle]::Alloc($n, [System.Runtime.InteropServices.GCHandleType]::Pinned)
        $authInfo.pbNonce = $ghN.AddrOfPinnedObject()
        $authInfo.cbNonce = $n.Length
        $ghT = [System.Runtime.InteropServices.GCHandle]::Alloc($tag, [System.Runtime.InteropServices.GCHandleType]::Pinned)
        $authInfo.pbTag = $ghT.AddrOfPinnedObject()
        $authInfo.cbTag = $tag.Length
        if ($a.Length -gt 0) {
            $ghA = [System.Runtime.InteropServices.GCHandle]::Alloc($a, [System.Runtime.InteropServices.GCHandleType]::Pinned)
            $authInfo.pbAuthData = $ghA.AddrOfPinnedObject()
            $authInfo.cbAuthData = $a.Length
        }
        $inputData = if ($p.Length -eq 0) { $null } else { $p }
        $c = [byte[]]::new($p.Length)
        $outputData = if ($c.Length -eq 0) { $null } else { $c }
        $written = 0
        [BCrypt]::BCryptEncrypt($hKey, $inputData, $p.Length, [ref]$authInfo, $null, 0, $outputData, $c.Length, [ref]$written, 0) | Out-Null
        return @{ Ciphertext = (ConvertTo-Hex $c); Tag = (ConvertTo-Hex $tag) }
    } finally {
        if ($ghN) { $ghN.Free() }
        if ($ghT) { $ghT.Free() }
        if ($ghA) { $ghA.Free() }
        if ($hKey -ne [IntPtr]::Zero) { [BCrypt]::BCryptDestroyKey($hKey) | Out-Null }
        if ($hAlg -ne [IntPtr]::Zero) { [BCrypt]::BCryptCloseAlgorithmProvider($hAlg, 0) | Out-Null }
    }
}

function Decrypt-AesGcm($key, $nonce, $ciphertext, $tag, $aad='') {
    $k = ConvertFrom-Hex $key
    $n = ConvertFrom-Hex $nonce
    $c = ConvertFrom-Hex $ciphertext
    $t = ConvertFrom-Hex $tag
    $a = ConvertFrom-Hex $aad
    $hAlg = [IntPtr]::Zero
    $hKey = [IntPtr]::Zero
    $ghN = $null; $ghT = $null; $ghA = $null
    try {
        [BCrypt]::BCryptOpenAlgorithmProvider([ref]$hAlg, 'AES', $null, 0) | Out-Null
        $mode = [System.Text.Encoding]::Unicode.GetBytes('ChainingModeGCM')
        [BCrypt]::BCryptSetProperty($hAlg, 'ChainingMode', $mode, $mode.Length, 0) | Out-Null
        [BCrypt]::BCryptGenerateSymmetricKey($hAlg, [ref]$hKey, [IntPtr]::Zero, 0, $k, $k.Length, 0) | Out-Null
        $authInfo = New-Object BCrypt+BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO
        $authInfo.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($authInfo)
        $authInfo.dwInfoVersion = 1
        $ghN = [System.Runtime.InteropServices.GCHandle]::Alloc($n, [System.Runtime.InteropServices.GCHandleType]::Pinned)
        $authInfo.pbNonce = $ghN.AddrOfPinnedObject()
        $authInfo.cbNonce = $n.Length
        $ghT = [System.Runtime.InteropServices.GCHandle]::Alloc($t, [System.Runtime.InteropServices.GCHandleType]::Pinned)
        $authInfo.pbTag = $ghT.AddrOfPinnedObject()
        $authInfo.cbTag = $t.Length
        if ($a.Length -gt 0) {
            $ghA = [System.Runtime.InteropServices.GCHandle]::Alloc($a, [System.Runtime.InteropServices.GCHandleType]::Pinned)
            $authInfo.pbAuthData = $ghA.AddrOfPinnedObject()
            $authInfo.cbAuthData = $a.Length
        }
        $inputData = if ($c.Length -eq 0) { $null } else { $c }
        $p = [byte[]]::new($c.Length)
        $outputData = if ($p.Length -eq 0) { $null } else { $p }
        $written = 0
        [BCrypt]::BCryptDecrypt($hKey, $inputData, $c.Length, [ref]$authInfo, $null, 0, $outputData, $p.Length, [ref]$written, 0) | Out-Null
        return ConvertTo-Hex $p
    } finally {
        if ($ghN) { $ghN.Free() }
        if ($ghT) { $ghT.Free() }
        if ($ghA) { $ghA.Free() }
        if ($hKey -ne [IntPtr]::Zero) { [BCrypt]::BCryptDestroyKey($hKey) | Out-Null }
        if ($hAlg -ne [IntPtr]::Zero) { [BCrypt]::BCryptCloseAlgorithmProvider($hAlg, 0) | Out-Null }
    }
}

# Test
Write-Host "Testing Legacy BCrypt AES-GCM..." -ForegroundColor Cyan
$k = 'c3d99825f2181f4808acd2068eac7441a65bd428f14d2aab43fefc0129091139'
$n = 'cafebabefacedbaddecaf888'
$p = ''
$result = Encrypt-AesGcm $k $n $p
Write-Host "Encrypt empty: Tag=$($result.Tag)" -ForegroundColor Green
$plain = Decrypt-AesGcm $k $n $result.Ciphertext $result.Tag
Write-Host "Decrypt empty: Plain=$plain" -ForegroundColor Green
Write-Host "SUCCESS - Legacy implementation working" -ForegroundColor Green
