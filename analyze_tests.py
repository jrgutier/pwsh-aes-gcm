#!/usr/bin/env python3
import json
import sys

with open('/home/user/pwsh-aes-gcm/TestVectors/aes_gcm_test.json', 'r') as f:
    data = json.load(f)

print(f"Total tests: {data['numberOfTests']}")
print(f"Algorithm: {data['algorithm']}")
print()

aes256_groups = []
total_aes256_tests = 0
iv_size_stats = {}

for group in data['testGroups']:
    if group['keySize'] == 256:
        iv_size = group['ivSize']
        num_tests = len(group['tests'])
        total_aes256_tests += num_tests

        if iv_size not in iv_size_stats:
            iv_size_stats[iv_size] = 0
        iv_size_stats[iv_size] += num_tests

        aes256_groups.append({
            'ivSize': iv_size,
            'tagSize': group['tagSize'],
            'numTests': num_tests
        })

print(f"AES-256 test groups: {len(aes256_groups)}")
print(f"Total AES-256 tests: {total_aes256_tests}")
print()
print("IV size distribution:")
for iv_size in sorted(iv_size_stats.keys()):
    print(f"  IV={iv_size:3d} bits: {iv_size_stats[iv_size]:3d} tests")
print()

# Print details of each group
print("Test group details:")
for i, group in enumerate(aes256_groups, 1):
    print(f"  Group {i}: IV={group['ivSize']:3d} bits, Tag={group['tagSize']:3d} bits, Tests={group['numTests']}")
