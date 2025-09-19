#!/usr/bin/env python3
import os
import re
import sys
import argparse
import subprocess

"""
Remove unused imports based on Flutter analyzer output.

Usage:
  python3 fix_unused_imports.py [--from-file local-artifacts/flutter-analyze.txt] [--dry-run]
  python3 fix_unused_imports.py            # runs `flutter analyze` and parses stdout
"""

UNUSED_IMPORT_PATTERNS = [
    # Format: lib/file.dart:10:1 • Unused import: 'package:foo/bar.dart' • unused_import
    re.compile(r"^(?P<file>[^:]+):(?P<line>\d+):(?P<col>\d+)\s+•\s+Unused import: '(?P<import>[^']+)'\s+•\s+unused_import\b"),
    # Format: Unused import: 'package:foo/bar.dart' • lib/file.dart:10:1 • unused_import
    re.compile(r"^Unused import: '(?P<import>[^']+)'\s+•\s+(?P<file>[^:]+):(?P<line>\d+):(?P<col>\d+)\s+•\s+unused_import\b"),
    # Format: warning • Unused import: 'package:foo/bar.dart' • lib/file.dart:10:1 • unused_import
    re.compile(r"^warning\s+•\s+Unused import: '(?P<import>[^']+)'\s+•\s+(?P<file>[^:]+):(?P<line>\d+):(?P<col>\d+)\s+•\s+unused_import\b"),
]


def parse_analyzer_output(text: str):
    results = []  # list of tuples (file, import)
    for raw in text.splitlines():
        if 'unused_import' not in raw and 'Unused import:' not in raw:
            continue
        for pat in UNUSED_IMPORT_PATTERNS:
            m = pat.search(raw)
            if m:
                file_path = m.group('file').strip()
                imp = m.group('import').strip()
                results.append((file_path, imp))
                break
    return results


def remove_import_line(file_path: str, import_name: str, dry_run: bool = False) -> bool:
    if not os.path.exists(file_path):
        return False
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        changed = False
        new_lines = []
        for line in lines:
            if line.strip().startswith('import '):
                # match single or double quote
                if (f"import '{import_name}'" in line) or (f'import "{import_name}"' in line):
                    changed = True
                    continue  # skip this line
            new_lines.append(line)
        if changed and not dry_run:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
        return changed
    except Exception as e:
        print(f"Error fixing {file_path}: {e}")
        return False


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument('--from-file', help='Parse analyzer output from a file instead of running flutter analyze')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    if args.from_file and os.path.exists(args.from_file):
        with open(args.from_file, 'r', encoding='utf-8') as f:
            output = f.read()
    else:
        # Fallback: run flutter analyze and capture stdout
        try:
            proc = subprocess.run(['flutter', 'analyze'], cwd='.', text=True, capture_output=True, check=False)
            output = proc.stdout or ''
        except Exception as e:
            print(f"Failed to run flutter analyze: {e}")
            return 1

    findings = parse_analyzer_output(output)
    if not findings:
        print('No unused imports found in analyzer output.')
        return 0

    # de-duplicate by (file, import)
    seen = set()
    fixed = 0
    for file_path, imp in findings:
        key = (file_path, imp)
        if key in seen:
            continue
        seen.add(key)
        if remove_import_line(file_path, imp, dry_run=args.dry_run):
            print(f"Removed unused import '{imp}' from {file_path}")
            fixed += 1

    print(f"Fixed {fixed} unused imports")
    return 0


if __name__ == '__main__':
    sys.exit(run())
