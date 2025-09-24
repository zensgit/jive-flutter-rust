#!/usr/bin/env python3
import os
import re
import sys
import argparse

"""
Phase 1.3 helper: remove invalid/over-aggressive `const` from common widgets
that frequently carry dynamic values (e.g., Text/Icon with theme colors or
interpolated strings). This aims to unblock analyzer/build_runner by trading
errors for (acceptable) prefer_const_constructors warnings.

Heuristics:
- Strip leading `const ` before constructors: Text(, Icon(, SizedBox(?, no),
  Padding(?, no). We only target Text and Icon by default.
- Also strip `const ` in patterns like `child: const Text(` and
  `child: const Icon(`.

Usage:
  python3 fix_const_misuse.py --apply        # in repo root
  python3 fix_const_misuse.py --dry-run
"""

TARGETS = [
    'Text',
    'Icon',
]

def process_text(text: str):
    # Replace leading const before targeted constructors.
    # Cases:
    #  - "const Text("  -> "Text("
    #  - "child: const Text(" -> "child: Text("
    #  - trailing spaces and alignment preserved
    changed = text
    for target in TARGETS:
        changed = re.sub(rf"(^|\b)(const\s+)({target}\s*\()", r"\1\3", changed)
        # also in named args like "child:\s+const\s+Text("
        changed = re.sub(rf"(\b[A-Za-z_][A-Za-z0-9_]*\s*:\s*)(const\s+)({target}\s*\()", r"\1\3", changed)
    return changed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true', help='Write changes to files')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--root', default=os.path.join(os.path.dirname(__file__), 'lib'))
    args = parser.parse_args()

    total = 0
    changed_files = 0
    for dirpath, _, filenames in os.walk(args.root):
        for fn in filenames:
            if not fn.endswith('.dart'):
                continue
            path = os.path.join(dirpath, fn)
            with open(path, 'r', encoding='utf-8') as f:
                original = f.read()
            updated = process_text(original)
            if updated != original:
                changed_files += 1
                total += original.count('const Text(') + original.count('const Icon(')
                if args.apply and not args.dry_run:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(updated)
                print(f"Stripped const from {path}")
    print(f"Files changed: {changed_files}")
    print(f"Occurrences touched (approx): {total}")
    return 0

if __name__ == '__main__':
    sys.exit(main())

