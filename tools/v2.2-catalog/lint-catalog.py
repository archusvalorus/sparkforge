#!/usr/bin/env python3
"""Duplicate-key lint for the authored ability catalog (v2.2 J2).

`JSONSerialization` (and most parsers) keep the LAST of two equal keys in one
object and say nothing, so a card with two `face` lines would load with the
second and never be reported. This lint fails on any repeated key anywhere in
the file. Run by tools/catalog-harness/run.sh before the harness compiles, in
the harness's own PASS/FAIL line format.

Usage:  python3 tools/v2.2-catalog/lint-catalog.py <catalog.json>   # exit 1 on a duplicate
"""
import json, sys

def pairs_hook(pairs, path=('$',), found=[]):
    seen = {}
    for k, v in pairs:
        if k in seen:
            found.append('.'.join(path + (k,)))
        seen[k] = v
    return dict(pairs)

def main(path):
    found = []
    def hook(pairs):
        seen = set()
        for k, _ in pairs:
            if k in seen:
                found.append(k)
            seen.add(k)
        return dict(pairs)
    try:
        json.load(open(path), object_pairs_hook=hook)
    except (OSError, ValueError) as e:
        print(f'FAIL  JD1 the authored catalog parses with no repeated key  {path}: {e}')
        return 1
    if found:
        print(f'FAIL  JD1 the authored catalog parses with no repeated key  repeated: {sorted(set(found))}')
        return 1
    print('PASS  JD1 the authored catalog parses with no repeated key')
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else 'Sparkforge/Catalog/ability-catalog.json'))
