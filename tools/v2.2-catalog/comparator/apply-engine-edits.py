#!/usr/bin/env python3
"""Give the ACCEPTED draw engine the N1 pool (v2.2 N1 corrective pass, Oct 12).

usage: apply-engine-edits.py <edits.json> <engine.swift (as extracted from git)> <out.swift> [--none]

Refuses unless the engine file's SHA-256 is the pinned one, and unless every
edit's `find` text occurs exactly once (so an edit can never apply to the wrong
place or silently not at all). `--none` writes the engine unedited (the
comparator's self-check against the frozen legacy fixture). Exit 0 only on
success.
"""
import hashlib, json, sys

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    none = '--none' in sys.argv
    if len(args) != 3:
        print(__doc__, file=sys.stderr); return 2
    edits_path, engine_path, out_path = args
    spec = json.load(open(edits_path))
    text = open(engine_path, encoding='utf-8').read()
    digest = hashlib.sha256(text.encode('utf-8')).hexdigest()
    if digest != spec['engineSHA256']:
        print(f"apply-engine-edits: the accepted engine moved: sha256 {digest} != pinned {spec['engineSHA256']} "
              f"(commit {spec['engineCommit']}). A ruling is needed before the comparator can be trusted.", file=sys.stderr)
        return 1
    if not none:
        for edit in spec['edits']:
            n = text.count(edit['find'])
            if n != 1:
                print(f"apply-engine-edits: edit `{edit['name']}` matches {n} times, not once.", file=sys.stderr)
                return 1
            text = text.replace(edit['find'], edit['replace'])
    open(out_path, 'w', encoding='utf-8').write(text)
    print(f"apply-engine-edits: engine {digest[:12]} ok, {'no edits' if none else str(len(spec['edits'])) + ' edits'} → {out_path}")
    return 0

if __name__ == '__main__':
    sys.exit(main())
