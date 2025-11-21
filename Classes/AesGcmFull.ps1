# AesGcmFull.ps1
# Full GCM implementation with support for variable IV sizes
# Implements GHASH and uses AES-ECB primitives

$script:AesGcmFullInitialized = $false

function Initialize-AesGcmFull {
    if ($script:AesGcmFullInitialized) {
        return
    }

    $gcmCode = @'
using System;
using System.Security.Cryptography;

namespace AesGcmFull
{
    public class GaloisFieldMultiplier
    {
        private static readonly byte[] ReductionTable = new byte[256];

        static GaloisFieldMultiplier()
        {
            // Precompute reduction table for GF(2^128) multiplication
            for (int i = 0; i < 256; i++)
            {
                byte result = 0;
                byte value = (byte)i;
                for (int bit = 0; bit < 8; bit++)
                {
                    if ((value & 1) != 0)
                    {
                        result ^= 0xE1;
                    }
                    value >>= 1;
                }
                ReductionTable[i] = result;
            }
        }

        // Multiply two 128-bit blocks in GF(2^128)
        public static void GFMul(byte[] x, byte[] y, byte[] result)
        {
            Array.Clear(result, 0, 16);
            byte[] v = new byte[16];
            Array.Copy(y, v, 16);

            for (int i = 0; i < 16; i++)
            {
                for (int bit = 0; bit < 8; bit++)
                {
                    if ((x[i] & (0x80 >> bit)) != 0)
                    {
                        for (int j = 0; j < 16; j++)
                        {
                            result[j] ^= v[j];
                        }
                    }

                    // Right shift V with special reduction
                    bool lsb = (v[15] & 1) != 0;
                    for (int j = 15; j > 0; j--)
                    {
                        v[j] = (byte)((v[j] >> 1) | ((v[j - 1] & 1) << 7));
                    }
                    v[0] >>= 1;

                    if (lsb)
                    {
                        v[0] ^= 0xE1;
                    }
                }
            }
        }
    }

    public class AesGcmEngine
    {
        // Compute GHASH(H, A, C) where H is the hash key, A is AAD, C is ciphertext
        public static byte[] GHASH(byte[] h, byte[] aad, byte[] data)
        {
            byte[] y = new byte[16];
            byte[] temp = new byte[16];

            // Process AAD
            if (aad != null && aad.Length > 0)
            {
                int aadBlocks = (aad.Length + 15) / 16;
                for (int i = 0; i < aadBlocks; i++)
                {
                    int offset = i * 16;
                    int blockLen = Math.Min(16, aad.Length - offset);

                    for (int j = 0; j < blockLen; j++)
                    {
                        y[j] ^= aad[offset + j];
                    }

                    GaloisFieldMultiplier.GFMul(y, h, temp);
                    Array.Copy(temp, y, 16);
                }
            }

            // Process data (ciphertext for encryption, empty for tag-only)
            if (data != null && data.Length > 0)
            {
                int dataBlocks = (data.Length + 15) / 16;
                for (int i = 0; i < dataBlocks; i++)
                {
                    int offset = i * 16;
                    int blockLen = Math.Min(16, data.Length - offset);

                    for (int j = 0; j < blockLen; j++)
                    {
                        y[j] ^= data[offset + j];
                    }

                    GaloisFieldMultiplier.GFMul(y, h, temp);
                    Array.Copy(temp, y, 16);
                }
            }

            // Process lengths (AAD length || data length in bits, 64-bit each, big-endian)
            ulong aadBitLen = aad != null ? (ulong)aad.Length * 8 : 0;
            ulong dataBitLen = data != null ? (ulong)data.Length * 8 : 0;

            for (int i = 0; i < 8; i++)
            {
                y[i] ^= (byte)(aadBitLen >> (56 - i * 8));
                y[i + 8] ^= (byte)(dataBitLen >> (56 - i * 8));
            }

            GaloisFieldMultiplier.GFMul(y, h, temp);
            return temp;
        }

        // Compute J0 from IV (initial counter block)
        public static byte[] ComputeJ0(byte[] h, byte[] iv)
        {
            if (iv.Length == 12)
            {
                // Special case: 96-bit IV is used directly with counter = 1
                byte[] j0 = new byte[16];
                Array.Copy(iv, 0, j0, 0, 12);
                j0[15] = 0x01;
                return j0;
            }
            else
            {
                // For other sizes: J0 = GHASH(H, {}, IV || 0^s || [len(IV)]_64)
                // where s is padding to make total length a multiple of 128 bits
                int paddedLen = ((iv.Length + 15) / 16) * 16;
                byte[] paddedIv = new byte[paddedLen + 16]; // +16 for length field

                Array.Copy(iv, paddedIv, iv.Length);
                // Zero padding is implicit

                // Append IV bit length as 64-bit big-endian at the end
                ulong ivBitLen = (ulong)iv.Length * 8;
                for (int i = 0; i < 8; i++)
                {
                    paddedIv[paddedLen + 8 + i] = (byte)(ivBitLen >> (56 - i * 8));
                }

                return GHASH(h, null, paddedIv);
            }
        }

        // Increment counter (rightmost 32 bits as big-endian integer)
        public static void IncrementCounter(byte[] counter)
        {
            for (int i = 15; i >= 12; i--)
            {
                if (++counter[i] != 0)
                {
                    break;
                }
            }
        }

        // XOR two byte arrays
        public static void XOR(byte[] a, byte[] b, byte[] result, int length)
        {
            for (int i = 0; i < length; i++)
            {
                result[i] = (byte)(a[i] ^ b[i]);
            }
        }

        public static byte[][] Encrypt(byte[] key, byte[] iv, byte[] plaintext, byte[] aad)
        {
            if (iv == null || iv.Length == 0)
            {
                throw new ArgumentException("IV cannot be null or empty");
            }

            using (Aes aes = Aes.Create())
            {
                aes.Key = key;
                aes.Mode = CipherMode.ECB;
                aes.Padding = PaddingMode.None;

                using (ICryptoTransform encryptor = aes.CreateEncryptor())
                {
                    // Compute H = AES(K, 0^128)
                    byte[] h = new byte[16];
                    byte[] zeroBlock = new byte[16];
                    encryptor.TransformBlock(zeroBlock, 0, 16, h, 0);

                    // Compute J0
                    byte[] j0 = ComputeJ0(h, iv);

                    // Encrypt plaintext using CTR mode
                    byte[] ciphertext = new byte[plaintext.Length];
                    byte[] counter = new byte[16];
                    Array.Copy(j0, counter, 16);

                    for (int i = 0; i * 16 < plaintext.Length; i++)
                    {
                        IncrementCounter(counter);
                        byte[] keystream = new byte[16];
                        encryptor.TransformBlock(counter, 0, 16, keystream, 0);

                        int offset = i * 16;
                        int blockLen = Math.Min(16, plaintext.Length - offset);
                        for (int j = 0; j < blockLen; j++)
                        {
                            ciphertext[offset + j] = (byte)(plaintext[offset + j] ^ keystream[j]);
                        }
                    }

                    // Compute GHASH
                    byte[] ghash = GHASH(h, aad, ciphertext);

                    // Compute tag = GHASH ^ AES(K, J0)
                    byte[] tag = new byte[16];
                    byte[] encryptedJ0 = new byte[16];
                    encryptor.TransformBlock(j0, 0, 16, encryptedJ0, 0);
                    XOR(ghash, encryptedJ0, tag, 16);

                    return new byte[][] { ciphertext, tag };
                }
            }
        }

        public static byte[] Decrypt(byte[] key, byte[] iv, byte[] ciphertext, byte[] tag, byte[] aad)
        {
            if (iv == null || iv.Length == 0)
            {
                throw new ArgumentException("IV cannot be null or empty");
            }

            using (Aes aes = Aes.Create())
            {
                aes.Key = key;
                aes.Mode = CipherMode.ECB;
                aes.Padding = PaddingMode.None;

                using (ICryptoTransform encryptor = aes.CreateEncryptor())
                {
                    // Compute H = AES(K, 0^128)
                    byte[] h = new byte[16];
                    byte[] zeroBlock = new byte[16];
                    encryptor.TransformBlock(zeroBlock, 0, 16, h, 0);

                    // Compute J0
                    byte[] j0 = ComputeJ0(h, iv);

                    // Compute expected tag
                    byte[] ghash = GHASH(h, aad, ciphertext);
                    byte[] expectedTag = new byte[16];
                    byte[] encryptedJ0 = new byte[16];
                    encryptor.TransformBlock(j0, 0, 16, encryptedJ0, 0);
                    XOR(ghash, encryptedJ0, expectedTag, 16);

                    // Verify tag
                    bool tagMatch = true;
                    for (int i = 0; i < tag.Length && i < 16; i++)
                    {
                        if (tag[i] != expectedTag[i])
                        {
                            tagMatch = false;
                            break;
                        }
                    }

                    if (!tagMatch)
                    {
                        throw new CryptographicException("Authentication tag verification failed");
                    }

                    // Decrypt ciphertext using CTR mode
                    byte[] plaintext = new byte[ciphertext.Length];
                    byte[] counter = new byte[16];
                    Array.Copy(j0, counter, 16);

                    for (int i = 0; i * 16 < ciphertext.Length; i++)
                    {
                        IncrementCounter(counter);
                        byte[] keystream = new byte[16];
                        encryptor.TransformBlock(counter, 0, 16, keystream, 0);

                        int offset = i * 16;
                        int blockLen = Math.Min(16, ciphertext.Length - offset);
                        for (int j = 0; j < blockLen; j++)
                        {
                            plaintext[offset + j] = (byte)(ciphertext[offset + j] ^ keystream[j]);
                        }
                    }

                    return plaintext;
                }
            }
        }
    }
}
'@

    try {
        Add-Type -TypeDefinition $gcmCode -ErrorAction Stop
        $script:AesGcmFullInitialized = $true
    }
    catch {
        # Type may already be loaded
        if ($_.Exception.Message -notlike "*already exists*") {
            throw "Failed to initialize full GCM implementation: $_"
        }
        $script:AesGcmFullInitialized = $true
    }
}

function Invoke-AesGcmFullEncrypt {
    param(
        [byte[]]$Key,
        [byte[]]$Nonce,
        [byte[]]$Plaintext,
        [byte[]]$Aad
    )

    Initialize-AesGcmFull

    # Validate inputs
    if ($null -eq $Nonce -or $Nonce.Length -eq 0) {
        throw "IV/Nonce cannot be null or empty for GCM mode"
    }

    # Ensure we have valid arrays
    if ($null -eq $Plaintext) {
        $Plaintext = [byte[]]@()
    }
    if ($null -eq $Aad) {
        $Aad = [byte[]]@()
    }

    try {
        $result = [AesGcmFull.AesGcmEngine]::Encrypt($Key, $Nonce, $Plaintext, $Aad)

        return @{
            Ciphertext = $result[0]
            Tag = $result[1]
        }
    }
    catch {
        throw "Full GCM encryption failed: $_"
    }
}

function Invoke-AesGcmFullDecrypt {
    param(
        [byte[]]$Key,
        [byte[]]$Nonce,
        [byte[]]$Ciphertext,
        [byte[]]$Tag,
        [byte[]]$Aad
    )

    Initialize-AesGcmFull

    # Validate inputs
    if ($null -eq $Nonce -or $Nonce.Length -eq 0) {
        throw "IV/Nonce cannot be null or empty for GCM mode"
    }

    # Ensure we have valid arrays
    if ($null -eq $Ciphertext) {
        $Ciphertext = [byte[]]@()
    }
    if ($null -eq $Aad) {
        $Aad = [byte[]]@()
    }

    try {
        return [AesGcmFull.AesGcmEngine]::Decrypt($Key, $Nonce, $Ciphertext, $Tag, $Aad)
    }
    catch {
        throw "Full GCM decryption failed: $_"
    }
}
