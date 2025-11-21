# AesGcmNative.ps1
# Modern implementation using System.Security.Cryptography.AesGcm
# Available in .NET Core 3.0+, .NET 5+, PowerShell 7+

function Test-AesGcmNativeAvailable {
    try {
        return $null -ne ([System.Security.Cryptography.AesGcm] -as [type])
    }
    catch {
        return $false
    }
}

function Invoke-AesGcmNativeEncrypt {
    param(
        [byte[]]$Key,
        [byte[]]$Nonce,
        [byte[]]$Plaintext,
        [byte[]]$Aad
    )

    $ciphertext = New-Object byte[] $Plaintext.Length
    $tag = New-Object byte[] 16  # GCM tag is always 128 bits (16 bytes)

    $aesGcm = [System.Security.Cryptography.AesGcm]::new($Key)

    try {
        if ($null -eq $Aad -or $Aad.Length -eq 0) {
            $aesGcm.Encrypt($Nonce, $Plaintext, $ciphertext, $tag)
        }
        else {
            $aesGcm.Encrypt($Nonce, $Plaintext, $ciphertext, $tag, $Aad)
        }

        return @{
            Ciphertext = $ciphertext
            Tag = $tag
        }
    }
    finally {
        $aesGcm.Dispose()
    }
}

function Invoke-AesGcmNativeDecrypt {
    param(
        [byte[]]$Key,
        [byte[]]$Nonce,
        [byte[]]$Ciphertext,
        [byte[]]$Tag,
        [byte[]]$Aad
    )

    $plaintext = New-Object byte[] $Ciphertext.Length

    $aesGcm = [System.Security.Cryptography.AesGcm]::new($Key)

    try {
        if ($null -eq $Aad -or $Aad.Length -eq 0) {
            $aesGcm.Decrypt($Nonce, $Ciphertext, $Tag, $plaintext)
        }
        else {
            $aesGcm.Decrypt($Nonce, $Ciphertext, $Tag, $plaintext, $Aad)
        }

        return $plaintext
    }
    catch [System.Security.Cryptography.CryptographicException] {
        throw "Authentication tag verification failed"
    }
    finally {
        $aesGcm.Dispose()
    }
}
