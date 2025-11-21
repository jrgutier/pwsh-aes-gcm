#!/usr/bin/env python3
import json

with open('/home/user/pwsh-aes-gcm/TestVectors/aes_gcm_test.json', 'r') as f:
    data = json.load(f)

print("Analyzing potential failing tests for AES-256:\n")

# Focus on non-standard IV sizes
non_standard_ivs = []
standard_ivs_96 = []
standard_ivs_128 = []

for group in data['testGroups']:
    if group['keySize'] == 256:
        iv_size = group['ivSize']
        for test in group['tests']:
            test_info = {
                'tcId': test['tcId'],
                'ivSize': iv_size,
                'comment': test.get('comment', ''),
                'flags': test.get('flags', []),
                'result': test['result'],
                'msgLen': len(test['msg']) // 2,  # hex string
                'aadLen': len(test.get('aad', '')) // 2
            }

            if iv_size == 96:
                standard_ivs_96.append(test_info)
            elif iv_size == 128:
                standard_ivs_128.append(test_info)
            else:
                non_standard_ivs.append(test_info)

print(f"Standard 96-bit IV tests: {len(standard_ivs_96)}")
print(f"Standard 128-bit IV tests: {len(standard_ivs_128)}")
print(f"Non-standard IV tests: {len(non_standard_ivs)}")
print()

# Group non-standard by IV size
print("Non-standard IV size breakdown:")
from collections import defaultdict
by_iv = defaultdict(list)
for test in non_standard_ivs:
    by_iv[test['ivSize']].append(test)

for iv_size in sorted(by_iv.keys()):
    tests = by_iv[iv_size]
    print(f"\n  IV={iv_size} bits ({len(tests)} tests):")
    for test in tests:
        flags_str = ', '.join(test['flags']) if test['flags'] else 'none'
        print(f"    Test {test['tcId']:3d}: result={test['result']:7s}, "
              f"msgLen={test['msgLen']:2d}, aadLen={test['aadLen']:2d}, "
              f"flags=[{flags_str}]")
        if test['comment']:
            print(f"                   comment: {test['comment']}")

# Look for empty plaintext tests
print("\n\nEmpty plaintext/ciphertext tests:")
all_tests = standard_ivs_96 + standard_ivs_128 + non_standard_ivs
empty_tests = [t for t in all_tests if t['msgLen'] == 0]
print(f"Found {len(empty_tests)} tests with empty plaintext:")
for test in empty_tests:
    flags_str = ', '.join(test['flags']) if test['flags'] else 'none'
    print(f"  Test {test['tcId']:3d}: IV={test['ivSize']} bits, "
          f"result={test['result']}, aadLen={test['aadLen']}, "
          f"flags=[{flags_str}]")
