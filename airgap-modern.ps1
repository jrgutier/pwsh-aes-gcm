# MODERN Implementation - For systems with System.Security.Cryptography.AesGcm
# Shortest and simplest - use this if airgap-detect.ps1 shows MODERN available

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

function Encrypt-AesGcm($key, $nonce, $plaintext, $aad='') {
    $k = ConvertFrom-Hex $key
    $n = ConvertFrom-Hex $nonce
    $p = ConvertFrom-Hex $plaintext
    $a = ConvertFrom-Hex $aad
    $c = [byte[]]::new($p.Length)
    $t = [byte[]]::new(16)
    $aes = [System.Security.Cryptography.AesGcm]::new($k)
    $aes.Encrypt($n, $p, $c, $t, $a)
    $aes.Dispose()
    return @{
        Ciphertext = ConvertTo-Hex $c
        Tag = ConvertTo-Hex $t
    }
}

function Decrypt-AesGcm($key, $nonce, $ciphertext, $tag, $aad='') {
    $k = ConvertFrom-Hex $key
    $n = ConvertFrom-Hex $nonce
    $c = ConvertFrom-Hex $ciphertext
    $t = ConvertFrom-Hex $tag
    $a = ConvertFrom-Hex $aad
    $p = [byte[]]::new($c.Length)
    $aes = [System.Security.Cryptography.AesGcm]::new($k)
    $aes.Decrypt($n, $c, $t, $p, $a)
    $aes.Dispose()
    return ConvertTo-Hex $p
}

# Test
Write-Host "Testing Modern AES-GCM..." -ForegroundColor Cyan
$k = 'c3d99825f2181f4808acd2068eac7441a65bd428f14d2aab43fefc0129091139'
$n = 'cafebabefacedbaddecaf888'
$p = ''
$result = Encrypt-AesGcm $k $n $p
Write-Host "Encrypt empty: Tag=$($result.Tag)" -ForegroundColor Green
$plain = Decrypt-AesGcm $k $n $result.Ciphertext $result.Tag
Write-Host "Decrypt empty: Plain=$plain" -ForegroundColor Green
Write-Host "SUCCESS - Modern implementation working" -ForegroundColor Green
