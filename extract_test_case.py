#!/usr/bin/env python3
import json

with open('/home/user/pwsh-aes-gcm/TestVectors/aes_gcm_test.json', 'r') as f:
    data = json.load(f)

# Extract test case 299 (8-bit IV, empty plaintext)
# and test case 300 (8-bit IV, 16-byte plaintext)
for group in data['testGroups']:
    if group['keySize'] == 256:
        for test in group['tests']:
            if test['tcId'] in [299, 300, 92, 93]:
                print(f"\nTest {test['tcId']}:")
                print(f"  Comment: {test.get('comment', '')}")
                print(f"  IV size: {group['ivSize']} bits ({group['ivSize']//8} bytes)")
                print(f"  Result: {test['result']}")
                print(f"  Key: {test['key']}")
                print(f"  IV:  {test['iv']}")
                print(f"  AAD: {test['aad']}")
                print(f"  Msg: {test['msg']}")
                print(f"  CT:  {test['ct']}")
                print(f"  Tag: {test['tag']}")
                print(f"  Msg length: {len(test['msg'])//2} bytes")
                print(f"  AAD length: {len(test['aad'])//2} bytes")
