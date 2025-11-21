Import-Module ./AesGcm.psd1 -Force

$key = '29d3a44f8723dc640239100c365423a312934ac80239212ac3df3421a2098123'
$nonce = '00112233445566778899aabb'
$aad = 'aabbccddeeff'
$plaintext = ''

try {
    $result = ConvertTo-AesGcmEncrypted -Key $key -Plaintext $plaintext -Nonce $nonce -AdditionalData $aad
    Write-Host "Success: CT=$($result.Ciphertext) Tag=$($result.Tag)"
    Write-Host "Expected Tag: 2a7d77fa526b8250cb296078926b5020"
}
catch {
    Write-Host "Error: $_"
    Write-Host $_.Exception
    Write-Host $_.ScriptStackTrace
}
