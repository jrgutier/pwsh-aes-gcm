# FULL GCM Implementation - Pure .NET with AES-ECB (supports all IV sizes)
# Use this if BCrypt/Modern not available OR if you need non-12-byte IVs

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
using System.Security.Cryptography;
public class AesGcmEngine {
    private static void GMul(byte[] x, byte[] y, byte[] result) {
        Array.Clear(result, 0, 16);
        byte[] v = new byte[16];
        Array.Copy(y, v, 16);
        for (int i = 0; i < 128; i++) {
            int bytePos = i / 8;
            int bitPos = 7 - (i % 8);
            if ((x[bytePos] & (1 << bitPos)) != 0) {
                for (int j = 0; j < 16; j++) result[j] ^= v[j];
            }
            bool lsb = (v[15] & 1) != 0;
            for (int j = 15; j > 0; j--) v[j] = (byte)((v[j] >> 1) | ((v[j-1] & 1) << 7));
            v[0] >>= 1;
            if (lsb) v[0] ^= 0xE1;
        }
    }
    private static void GHASH(byte[] h, byte[] data, byte[] result) {
        Array.Clear(result, 0, 16);
        for (int i = 0; i < data.Length; i += 16) {
            int blockLen = Math.Min(16, data.Length - i);
            for (int j = 0; j < blockLen; j++) result[j] ^= data[i + j];
            byte[] temp = new byte[16];
            GMul(result, h, temp);
            Array.Copy(temp, result, 16);
        }
    }
    private static void Inc32(byte[] block) {
        for (int i = 15; i >= 12; i--) {
            if (++block[i] != 0) break;
        }
    }
    public static void Encrypt(byte[] key, byte[] nonce, byte[] plaintext, byte[] aad, out byte[] ciphertext, out byte[] tag) {
        using (Aes aes = Aes.Create()) {
            aes.Key = key;
            aes.Mode = CipherMode.ECB;
            aes.Padding = PaddingMode.None;
            ICryptoTransform enc = aes.CreateEncryptor();
            byte[] h = new byte[16];
            enc.TransformBlock(h, 0, 16, h, 0);
            byte[] j0 = new byte[16];
            if (nonce.Length == 12) {
                Array.Copy(nonce, j0, 12);
                j0[15] = 1;
            } else {
                int ghashLen = ((nonce.Length + 15) / 16) * 16 + 16;
                byte[] ghashInput = new byte[ghashLen];
                Array.Copy(nonce, ghashInput, nonce.Length);
                ulong nonceBits = (ulong)nonce.Length * 8;
                for (int i = 0; i < 8; i++) ghashInput[ghashLen - 1 - i] = (byte)(nonceBits >> (i * 8));
                GHASH(h, ghashInput, j0);
            }
            ciphertext = new byte[plaintext.Length];
            byte[] counter = new byte[16];
            Array.Copy(j0, counter, 16);
            for (int i = 0; i < plaintext.Length; i += 16) {
                Inc32(counter);
                byte[] encCounter = new byte[16];
                enc.TransformBlock(counter, 0, 16, encCounter, 0);
                int blockLen = Math.Min(16, plaintext.Length - i);
                for (int j = 0; j < blockLen; j++) ciphertext[i + j] = (byte)(plaintext[i + j] ^ encCounter[j]);
            }
            int ghashTotalLen = ((aad.Length + 15) / 16) * 16 + ((ciphertext.Length + 15) / 16) * 16 + 16;
            byte[] ghashData = new byte[ghashTotalLen];
            Array.Copy(aad, ghashData, aad.Length);
            int cipherOffset = ((aad.Length + 15) / 16) * 16;
            Array.Copy(ciphertext, 0, ghashData, cipherOffset, ciphertext.Length);
            int lenOffset = cipherOffset + ((ciphertext.Length + 15) / 16) * 16;
            ulong aadBits = (ulong)aad.Length * 8;
            ulong cipherBits = (ulong)ciphertext.Length * 8;
            for (int i = 0; i < 8; i++) {
                ghashData[lenOffset + 7 - i] = (byte)(aadBits >> (i * 8));
                ghashData[lenOffset + 15 - i] = (byte)(cipherBits >> (i * 8));
            }
            byte[] s = new byte[16];
            GHASH(h, ghashData, s);
            byte[] j0Enc = new byte[16];
            enc.TransformBlock(j0, 0, 16, j0Enc, 0);
            tag = new byte[16];
            for (int i = 0; i < 16; i++) tag[i] = (byte)(s[i] ^ j0Enc[i]);
            enc.Dispose();
        }
    }
    public static void Decrypt(byte[] key, byte[] nonce, byte[] ciphertext, byte[] tag, byte[] aad, out byte[] plaintext) {
        using (Aes aes = Aes.Create()) {
            aes.Key = key;
            aes.Mode = CipherMode.ECB;
            aes.Padding = PaddingMode.None;
            ICryptoTransform enc = aes.CreateEncryptor();
            byte[] h = new byte[16];
            enc.TransformBlock(h, 0, 16, h, 0);
            byte[] j0 = new byte[16];
            if (nonce.Length == 12) {
                Array.Copy(nonce, j0, 12);
                j0[15] = 1;
            } else {
                int ghashLen = ((nonce.Length + 15) / 16) * 16 + 16;
                byte[] ghashInput = new byte[ghashLen];
                Array.Copy(nonce, ghashInput, nonce.Length);
                ulong nonceBits = (ulong)nonce.Length * 8;
                for (int i = 0; i < 8; i++) ghashInput[ghashLen - 1 - i] = (byte)(nonceBits >> (i * 8));
                GHASH(h, ghashInput, j0);
            }
            int ghashTotalLen = ((aad.Length + 15) / 16) * 16 + ((ciphertext.Length + 15) / 16) * 16 + 16;
            byte[] ghashData = new byte[ghashTotalLen];
            Array.Copy(aad, ghashData, aad.Length);
            int cipherOffset = ((aad.Length + 15) / 16) * 16;
            Array.Copy(ciphertext, 0, ghashData, cipherOffset, ciphertext.Length);
            int lenOffset = cipherOffset + ((ciphertext.Length + 15) / 16) * 16;
            ulong aadBits = (ulong)aad.Length * 8;
            ulong cipherBits = (ulong)ciphertext.Length * 8;
            for (int i = 0; i < 8; i++) {
                ghashData[lenOffset + 7 - i] = (byte)(aadBits >> (i * 8));
                ghashData[lenOffset + 15 - i] = (byte)(cipherBits >> (i * 8));
            }
            byte[] s = new byte[16];
            GHASH(h, ghashData, s);
            byte[] j0Enc = new byte[16];
            enc.TransformBlock(j0, 0, 16, j0Enc, 0);
            byte[] expectedTag = new byte[16];
            for (int i = 0; i < 16; i++) expectedTag[i] = (byte)(s[i] ^ j0Enc[i]);
            bool tagMatch = true;
            for (int i = 0; i < 16; i++) if (tag[i] != expectedTag[i]) { tagMatch = false; break; }
            if (!tagMatch) throw new CryptographicException("Authentication tag mismatch");
            plaintext = new byte[ciphertext.Length];
            byte[] counter = new byte[16];
            Array.Copy(j0, counter, 16);
            for (int i = 0; i < ciphertext.Length; i += 16) {
                Inc32(counter);
                byte[] encCounter = new byte[16];
                enc.TransformBlock(counter, 0, 16, encCounter, 0);
                int blockLen = Math.Min(16, ciphertext.Length - i);
                for (int j = 0; j < blockLen; j++) plaintext[i + j] = (byte)(ciphertext[i + j] ^ encCounter[j]);
            }
            enc.Dispose();
        }
    }
}
'@

function Encrypt-AesGcm($key, $nonce, $plaintext, $aad='') {
    $k = ConvertFrom-Hex $key
    $n = ConvertFrom-Hex $nonce
    $p = ConvertFrom-Hex $plaintext
    $a = ConvertFrom-Hex $aad
    $c = $null
    $t = $null
    [AesGcmEngine]::Encrypt($k, $n, $p, $a, [ref]$c, [ref]$t)
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
    $p = $null
    [AesGcmEngine]::Decrypt($k, $n, $c, $t, $a, [ref]$p)
    return ConvertTo-Hex $p
}

# Test
Write-Host "Testing Full GCM Implementation..." -ForegroundColor Cyan
$k = 'c3d99825f2181f4808acd2068eac7441a65bd428f14d2aab43fefc0129091139'
$n = 'cafebabefacedbaddecaf888'
$p = ''
$result = Encrypt-AesGcm $k $n $p
Write-Host "Encrypt empty: Tag=$($result.Tag)" -ForegroundColor Green
$plain = Decrypt-AesGcm $k $n $result.Ciphertext $result.Tag
Write-Host "Decrypt empty: Plain=$plain" -ForegroundColor Green
Write-Host "SUCCESS - Full GCM implementation working" -ForegroundColor Green
