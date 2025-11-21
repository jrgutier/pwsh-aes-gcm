# AesGcmLegacy.ps1
# Legacy implementation using P/Invoke to Windows BCrypt CNG APIs
# Compatible with .NET Framework 3.5+ on Windows Vista and later

$script:AesGcmLegacyInitialized = $false

function Initialize-AesGcmLegacy {
    if ($script:AesGcmLegacyInitialized) {
        return
    }

    $bcryptCode = @'
using System;
using System.Runtime.InteropServices;
using System.Security;

namespace AesGcmBCrypt
{
    public enum NTSTATUS : uint
    {
        STATUS_SUCCESS = 0x00000000,
        STATUS_AUTH_TAG_MISMATCH = 0xC000A002,
        STATUS_BUFFER_TOO_SMALL = 0xC0000023,
        STATUS_INVALID_PARAMETER = 0xC000000D
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO
    {
        public uint cbSize;
        public uint dwInfoVersion;
        public IntPtr pbNonce;
        public uint cbNonce;
        public IntPtr pbAuthData;
        public uint cbAuthData;
        public IntPtr pbTag;
        public uint cbTag;
        public IntPtr pbMacContext;
        public uint cbMacContext;
        public uint cbAAD;
        public ulong cbData;
        public uint dwFlags;

        public const uint BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO_VERSION = 1;
        public const uint BCRYPT_AUTH_MODE_CHAIN_CALLS_FLAG = 0x00000001;
        public const uint BCRYPT_AUTH_MODE_IN_PROGRESS_FLAG = 0x00000002;
    }

    public static class BCryptNative
    {
        public const string BCRYPT_AES_ALGORITHM = "AES";
        public const string BCRYPT_CHAIN_MODE_GCM = "ChainingModeGCM";
        public const string BCRYPT_CHAINING_MODE = "ChainingMode";
        public const string BCRYPT_KEY_DATA_BLOB = "KeyDataBlob";
        public const uint BCRYPT_KEY_DATA_BLOB_MAGIC = 0x4d42444b;
        public const uint BCRYPT_KEY_DATA_BLOB_VERSION1 = 0x1;

        [DllImport("bcrypt.dll", CharSet = CharSet.Unicode, SetLastError = false)]
        public static extern NTSTATUS BCryptOpenAlgorithmProvider(
            out IntPtr phAlgorithm,
            [MarshalAs(UnmanagedType.LPWStr)] string pszAlgId,
            [MarshalAs(UnmanagedType.LPWStr)] string pszImplementation,
            uint dwFlags);

        [DllImport("bcrypt.dll", SetLastError = false)]
        public static extern NTSTATUS BCryptCloseAlgorithmProvider(IntPtr hAlgorithm, uint dwFlags);

        [DllImport("bcrypt.dll", CharSet = CharSet.Unicode, SetLastError = false)]
        public static extern NTSTATUS BCryptSetProperty(
            IntPtr hObject,
            [MarshalAs(UnmanagedType.LPWStr)] string pszProperty,
            byte[] pbInput,
            uint cbInput,
            uint dwFlags);

        [DllImport("bcrypt.dll", SetLastError = false)]
        public static extern NTSTATUS BCryptGenerateSymmetricKey(
            IntPtr hAlgorithm,
            out IntPtr phKey,
            IntPtr pbKeyObject,
            uint cbKeyObject,
            byte[] pbSecret,
            uint cbSecret,
            uint dwFlags);

        [DllImport("bcrypt.dll", SetLastError = false)]
        public static extern NTSTATUS BCryptDestroyKey(IntPtr hKey);

        [DllImport("bcrypt.dll", SetLastError = false)]
        public static extern NTSTATUS BCryptEncrypt(
            IntPtr hKey,
            byte[] pbInput,
            uint cbInput,
            ref BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO pPaddingInfo,
            IntPtr pbIV,
            uint cbIV,
            byte[] pbOutput,
            uint cbOutput,
            out uint pcbResult,
            uint dwFlags);

        [DllImport("bcrypt.dll", SetLastError = false)]
        public static extern NTSTATUS BCryptDecrypt(
            IntPtr hKey,
            byte[] pbInput,
            uint cbInput,
            ref BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO pPaddingInfo,
            IntPtr pbIV,
            uint cbIV,
            byte[] pbOutput,
            uint cbOutput,
            out uint pcbResult,
            uint dwFlags);
    }

    public class AesGcmCng
    {
        public static byte[][] Encrypt(byte[] key, byte[] nonce, byte[] plaintext, byte[] aad)
        {
            IntPtr hAlgorithm = IntPtr.Zero;
            IntPtr hKey = IntPtr.Zero;
            GCHandle nonceHandle = new GCHandle();
            GCHandle aadHandle = new GCHandle();
            GCHandle tagHandle = new GCHandle();

            try
            {
                // Open algorithm provider
                NTSTATUS status = BCryptNative.BCryptOpenAlgorithmProvider(
                    out hAlgorithm,
                    BCryptNative.BCRYPT_AES_ALGORITHM,
                    null,
                    0);

                if (status != NTSTATUS.STATUS_SUCCESS)
                    throw new InvalidOperationException("BCryptOpenAlgorithmProvider failed: 0x" + ((uint)status).ToString("X8"));

                // Set GCM mode
                byte[] gcmMode = System.Text.Encoding.Unicode.GetBytes(BCryptNative.BCRYPT_CHAIN_MODE_GCM);
                status = BCryptNative.BCryptSetProperty(
                    hAlgorithm,
                    BCryptNative.BCRYPT_CHAINING_MODE,
                    gcmMode,
                    (uint)gcmMode.Length,
                    0);

                if (status != NTSTATUS.STATUS_SUCCESS)
                    throw new InvalidOperationException("BCryptSetProperty failed: 0x" + ((uint)status).ToString("X8"));

                // Generate symmetric key
                status = BCryptNative.BCryptGenerateSymmetricKey(
                    hAlgorithm,
                    out hKey,
                    IntPtr.Zero,
                    0,
                    key,
                    (uint)key.Length,
                    0);

                if (status != NTSTATUS.STATUS_SUCCESS)
                    throw new InvalidOperationException("BCryptGenerateSymmetricKey failed: 0x" + ((uint)status).ToString("X8"));

                // Prepare auth info structure
                byte[] tag = new byte[16];
                nonceHandle = GCHandle.Alloc(nonce, GCHandleType.Pinned);
                tagHandle = GCHandle.Alloc(tag, GCHandleType.Pinned);

                BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO authInfo = new BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO();
                authInfo.cbSize = (uint)Marshal.SizeOf(typeof(BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO));
                authInfo.dwInfoVersion = BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO.BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO_VERSION;
                authInfo.pbNonce = nonceHandle.AddrOfPinnedObject();
                authInfo.cbNonce = (uint)nonce.Length;
                authInfo.pbTag = tagHandle.AddrOfPinnedObject();
                authInfo.cbTag = 16;

                if (aad != null && aad.Length > 0)
                {
                    aadHandle = GCHandle.Alloc(aad, GCHandleType.Pinned);
                    authInfo.pbAuthData = aadHandle.AddrOfPinnedObject();
                    authInfo.cbAuthData = (uint)aad.Length;
                }

                // Encrypt
                byte[] ciphertext = new byte[plaintext.Length];
                uint resultLength;

                // Handle empty plaintext specially
                if (plaintext.Length == 0)
                {
                    // For zero-length plaintexts, we still need to call BCryptEncrypt to compute the tag
                    // but we can pass null for input and output buffers
                    status = BCryptNative.BCryptEncrypt(
                        hKey,
                        null,
                        0,
                        ref authInfo,
                        IntPtr.Zero,
                        0,
                        null,
                        0,
                        out resultLength,
                        0);
                }
                else
                {
                    status = BCryptNative.BCryptEncrypt(
                        hKey,
                        plaintext,
                        (uint)plaintext.Length,
                        ref authInfo,
                        IntPtr.Zero,
                        0,
                        ciphertext,
                        (uint)ciphertext.Length,
                        out resultLength,
                        0);
                }

                if (status != NTSTATUS.STATUS_SUCCESS)
                    throw new InvalidOperationException("BCryptEncrypt failed: 0x" + ((uint)status).ToString("X8"));

                return new byte[][] { ciphertext, tag };
            }
            finally
            {
                if (nonceHandle.IsAllocated) nonceHandle.Free();
                if (aadHandle.IsAllocated) aadHandle.Free();
                if (tagHandle.IsAllocated) tagHandle.Free();
                if (hKey != IntPtr.Zero) BCryptNative.BCryptDestroyKey(hKey);
                if (hAlgorithm != IntPtr.Zero) BCryptNative.BCryptCloseAlgorithmProvider(hAlgorithm, 0);
            }
        }

        public static byte[] Decrypt(byte[] key, byte[] nonce, byte[] ciphertext, byte[] tag, byte[] aad)
        {
            IntPtr hAlgorithm = IntPtr.Zero;
            IntPtr hKey = IntPtr.Zero;
            GCHandle nonceHandle = new GCHandle();
            GCHandle aadHandle = new GCHandle();
            GCHandle tagHandle = new GCHandle();

            try
            {
                // Open algorithm provider
                NTSTATUS status = BCryptNative.BCryptOpenAlgorithmProvider(
                    out hAlgorithm,
                    BCryptNative.BCRYPT_AES_ALGORITHM,
                    null,
                    0);

                if (status != NTSTATUS.STATUS_SUCCESS)
                    throw new InvalidOperationException("BCryptOpenAlgorithmProvider failed: 0x" + ((uint)status).ToString("X8"));

                // Set GCM mode
                byte[] gcmMode = System.Text.Encoding.Unicode.GetBytes(BCryptNative.BCRYPT_CHAIN_MODE_GCM);
                status = BCryptNative.BCryptSetProperty(
                    hAlgorithm,
                    BCryptNative.BCRYPT_CHAINING_MODE,
                    gcmMode,
                    (uint)gcmMode.Length,
                    0);

                if (status != NTSTATUS.STATUS_SUCCESS)
                    throw new InvalidOperationException("BCryptSetProperty failed: 0x" + ((uint)status).ToString("X8"));

                // Generate symmetric key
                status = BCryptNative.BCryptGenerateSymmetricKey(
                    hAlgorithm,
                    out hKey,
                    IntPtr.Zero,
                    0,
                    key,
                    (uint)key.Length,
                    0);

                if (status != NTSTATUS.STATUS_SUCCESS)
                    throw new InvalidOperationException("BCryptGenerateSymmetricKey failed: 0x" + ((uint)status).ToString("X8"));

                // Prepare auth info structure
                nonceHandle = GCHandle.Alloc(nonce, GCHandleType.Pinned);
                tagHandle = GCHandle.Alloc(tag, GCHandleType.Pinned);

                BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO authInfo = new BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO();
                authInfo.cbSize = (uint)Marshal.SizeOf(typeof(BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO));
                authInfo.dwInfoVersion = BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO.BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO_VERSION;
                authInfo.pbNonce = nonceHandle.AddrOfPinnedObject();
                authInfo.cbNonce = (uint)nonce.Length;
                authInfo.pbTag = tagHandle.AddrOfPinnedObject();
                authInfo.cbTag = (uint)tag.Length;

                if (aad != null && aad.Length > 0)
                {
                    aadHandle = GCHandle.Alloc(aad, GCHandleType.Pinned);
                    authInfo.pbAuthData = aadHandle.AddrOfPinnedObject();
                    authInfo.cbAuthData = (uint)aad.Length;
                }

                // Decrypt
                byte[] plaintext = new byte[ciphertext.Length];
                uint resultLength;

                // Handle empty ciphertext specially
                if (ciphertext.Length == 0)
                {
                    // For zero-length ciphertexts, we still need to call BCryptDecrypt to verify the tag
                    // but we can pass null for input and output buffers
                    status = BCryptNative.BCryptDecrypt(
                        hKey,
                        null,
                        0,
                        ref authInfo,
                        IntPtr.Zero,
                        0,
                        null,
                        0,
                        out resultLength,
                        0);
                }
                else
                {
                    status = BCryptNative.BCryptDecrypt(
                        hKey,
                        ciphertext,
                        (uint)ciphertext.Length,
                        ref authInfo,
                        IntPtr.Zero,
                        0,
                        plaintext,
                        (uint)plaintext.Length,
                        out resultLength,
                        0);
                }

                if (status == NTSTATUS.STATUS_AUTH_TAG_MISMATCH)
                    throw new System.Security.Cryptography.CryptographicException("Authentication tag verification failed");

                if (status != NTSTATUS.STATUS_SUCCESS)
                    throw new InvalidOperationException("BCryptDecrypt failed: 0x" + ((uint)status).ToString("X8"));

                return plaintext;
            }
            finally
            {
                if (nonceHandle.IsAllocated) nonceHandle.Free();
                if (aadHandle.IsAllocated) aadHandle.Free();
                if (tagHandle.IsAllocated) tagHandle.Free();
                if (hKey != IntPtr.Zero) BCryptNative.BCryptDestroyKey(hKey);
                if (hAlgorithm != IntPtr.Zero) BCryptNative.BCryptCloseAlgorithmProvider(hAlgorithm, 0);
            }
        }
    }
}
'@

    try {
        Add-Type -TypeDefinition $bcryptCode -ErrorAction Stop
        $script:AesGcmLegacyInitialized = $true
    }
    catch {
        throw "Failed to initialize BCrypt P/Invoke: $_"
    }
}

function Invoke-AesGcmLegacyEncrypt {
    param(
        [byte[]]$Key,
        [byte[]]$Nonce,
        [byte[]]$Plaintext,
        [byte[]]$Aad
    )

    Initialize-AesGcmLegacy

    # Ensure we have valid arrays (convert null to empty arrays)
    if ($null -eq $Plaintext) {
        $Plaintext = [byte[]]@()
    }
    if ($null -eq $Aad) {
        $Aad = [byte[]]@()
    }

    $result = [AesGcmBCrypt.AesGcmCng]::Encrypt($Key, $Nonce, $Plaintext, $Aad)

    return @{
        Ciphertext = $result[0]
        Tag = $result[1]
    }
}

function Invoke-AesGcmLegacyDecrypt {
    param(
        [byte[]]$Key,
        [byte[]]$Nonce,
        [byte[]]$Ciphertext,
        [byte[]]$Tag,
        [byte[]]$Aad
    )

    Initialize-AesGcmLegacy

    # Ensure we have valid arrays (convert null to empty arrays)
    if ($null -eq $Ciphertext) {
        $Ciphertext = [byte[]]@()
    }
    if ($null -eq $Aad) {
        $Aad = [byte[]]@()
    }

    return [AesGcmBCrypt.AesGcmCng]::Decrypt($Key, $Nonce, $Ciphertext, $Tag, $Aad)
}
