#!/usr/bin/env python3
import os
import re
import sys

"""
Scan Dart files and ensure `package:flutter/material.dart` is imported when
Icons/Colors/ElevatedButton/etc. are referenced without an existing material import.
This is a conservative fixer: it only adds the import if none of these are present:
  - package:flutter/material.dart
  - package:flutter/widgets.dart (not sufficient by itself for Icons/Colors)
"""

NEEDLES = [
    r"\bIcons\.", r"\bColors\.", r"\bElevatedButton\b", r"\bOutlinedButton\b", r"\bTextButton\b",
]

def file_needs_material(text: str) -> bool:
    if 'package:flutter/material.dart' in text:
        return False
    for pat in NEEDLES:
        if re.search(pat, text):
            return True
    return False

def add_material_import(path: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            text = f.read()
        if not file_needs_material(text):
            return False
        lines = text.splitlines(True)
        # Insert after first import line block, or at top if none
        insert_idx = 0
        while insert_idx < len(lines) and lines[insert_idx].strip().startswith('import '):
            insert_idx += 1
        lines.insert(insert_idx, "import 'package:flutter/material.dart';\n")
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print(f"Added material import to {path}")
        return True
    except Exception as e:
        print(f"Error processing {path}: {e}")
        return False

def main():
    root = os.path.join(os.path.dirname(__file__), 'lib')
    changed = 0
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            if not fn.endswith('.dart'):
                continue
            path = os.path.join(dirpath, fn)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    text = f.read()
                if file_needs_material(text):
                    if add_material_import(path):
                        changed += 1
            except Exception as e:
                print(f"Skip {path}: {e}")
                continue
    print(f"Material import added to {changed} files")
    return 0

if __name__ == '__main__':
    sys.exit(main())
