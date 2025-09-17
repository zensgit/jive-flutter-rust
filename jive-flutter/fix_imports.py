#!/usr/bin/env python3
import os
import re
import glob

def fix_foundation_imports(file_path):
    """Fix misplaced foundation imports in a Dart file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check if there's a misplaced foundation import (not at the beginning with other imports)
        lines = content.split('\n')

        # Find all import lines at the beginning
        import_section_end = 0
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith('import ') or stripped.startswith('export ') or stripped == '' or stripped.startswith('//') or stripped.startswith('/*'):
                import_section_end = i
            else:
                break

        # Find any misplaced foundation imports after the import section
        foundation_import_pattern = r"import 'package:flutter/foundation\.dart';"

        # Check if foundation import exists in proper location
        has_foundation_at_top = any(re.search(foundation_import_pattern, lines[i]) for i in range(import_section_end + 1))

        # Find and remove misplaced foundation imports
        new_lines = []
        removed_foundation = False

        for i, line in enumerate(lines):
            if i > import_section_end and re.search(foundation_import_pattern, line.strip()):
                # This is a misplaced foundation import, remove it
                removed_foundation = True
                continue
            new_lines.append(line)

        # If we removed a foundation import and it's not at the top, add it
        if removed_foundation and not has_foundation_at_top:
            # Find where to insert the foundation import (after other flutter imports)
            insert_index = 0
            for i, line in enumerate(new_lines[:import_section_end + 1]):
                if line.strip().startswith("import 'package:flutter/"):
                    insert_index = i + 1
                elif line.strip().startswith("import ") and not line.strip().startswith("import 'package:flutter/"):
                    break

            # Insert foundation import
            new_lines.insert(insert_index, "import 'package:flutter/foundation.dart';")

        # Write back if changes were made
        new_content = '\n'.join(new_lines)
        if new_content != content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Fixed: {file_path}")
            return True

    except Exception as e:
        print(f"Error processing {file_path}: {e}")

    return False

def main():
    dart_files = glob.glob('lib/**/*.dart', recursive=True)

    fixed_count = 0
    for file_path in dart_files:
        if fix_foundation_imports(file_path):
            fixed_count += 1

    print(f"Fixed {fixed_count} files")

if __name__ == '__main__':
    main()