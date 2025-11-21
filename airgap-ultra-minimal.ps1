# ULTRA-MINIMAL AES-GCM - 30 lines (Modern only, no error handling)
# Use ONLY if you confirmed System.Security.Cryptography.AesGcm exists
# Trade-offs: No validation, no error messages, assumes valid input

function H2B($h){if(!$h){return @()};$b=[byte[]]::new($h.Length/2);for($i=0;$i -lt $h.Length;$i+=2){$b[$i/2]=[Convert]::ToByte($h.Substring($i,2),16)};$b}
function B2H($b){($b|%{$_.ToString('x2')})-join ''}
function E($k,$n,$p,$a=''){$K=H2B $k;$N=H2B $n;$P=H2B $p;$A=H2B $a;$c=[byte[]]::new($P.Length);$t=[byte[]]::new(16);$x=[System.Security.Cryptography.AesGcm]::new($K);$x.Encrypt($N,$P,$c,$t,$A);$x.Dispose();@{c=B2H $c;t=B2H $t}}
function D($k,$n,$c,$t,$a=''){$K=H2B $k;$N=H2B $n;$C=H2B $c;$T=H2B $t;$A=H2B $a;$p=[byte[]]::new($C.Length);$x=[System.Security.Cryptography.AesGcm]::new($K);$x.Decrypt($N,$C,$T,$p,$A);$x.Dispose();B2H $p}

# Test: Expected tag = 3247184b3c4f69a44dbcd22887bbb418
$r=E 'c3d99825f2181f4808acd2068eac7441a65bd428f14d2aab43fefc0129091139' 'cafebabefacedbaddecaf888' ''
if($r.t -eq '3247184b3c4f69a44dbcd22887bbb418'){"PASS: $($r.t)"}else{"FAIL: $($r.t)"}

<#
USAGE:
  $result = E '<key-hex>' '<nonce-hex>' '<plaintext-hex>' '<aad-hex>'
  Returns: @{c='<ciphertext-hex>'; t='<tag-hex>'}

  $plain = D '<key-hex>' '<nonce-hex>' '<ciphertext-hex>' '<tag-hex>' '<aad-hex>'
  Returns: '<plaintext-hex>'

FUNCTIONS:
  E = Encrypt-AesGcm
  D = Decrypt-AesGcm
  H2B = Hex to Bytes
  B2H = Bytes to Hex

EXAMPLE:
  $k = -join ((1..32)|%{'{0:x2}'-f (Get-Random -Max 256)})
  $n = -join ((1..12)|%{'{0:x2}'-f (Get-Random -Max 256)})
  $r = E $k $n '48656c6c6f'  # 'Hello' in hex
  $p = D $k $n $r.c $r.t
  # Convert hex back to text: [System.Text.Encoding]::UTF8.GetString((H2B $p))
#>
