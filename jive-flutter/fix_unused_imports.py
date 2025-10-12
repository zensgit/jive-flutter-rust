#!/usr/bin/env python3
import os
import re
import subprocess

def fix_unused_imports():
    """Remove unused imports based on flutter analyze output"""
    # Get unused imports from flutter analyze
    result = subprocess.run(['flutter', 'analyze'], capture_output=True, text=True, cwd='.')
    output = result.stderr

    unused_imports = []
    for line in output.split('\n'):
        if 'unused_import' in line:
            # Parse the line to extract file and import
            match = re.search(r"Unused import: '([^']+)' • ([^:]+):(\d+):(\d+)", line)
            if match:
                import_name = match.group(1)
                file_path = match.group(2)
                line_num = int(match.group(3))
                unused_imports.append((file_path, import_name, line_num))

    fixed_count = 0
    for file_path, import_name, line_num in unused_imports:
        if os.path.exists(file_path):
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()

                # Find and remove the import line
                for i, line in enumerate(lines):
                    # Check if this line contains the import
                    if f"import '{import_name}'" in line or f'import "{import_name}"' in line:
                        # Remove the line
                        lines.pop(i)

                        # Write back the file
                        with open(file_path, 'w', encoding='utf-8') as f:
                            f.writelines(lines)

                        print(f"Removed unused import '{import_name}' from {file_path}")
                        fixed_count += 1
                        break

            except Exception as e:
                print(f"Error fixing {file_path}: {e}")

    return fixed_count

def main():
    print("Fixing unused imports...")
    fixed_count = fix_unused_imports()
    print(f"Fixed {fixed_count} unused imports")

if __name__ == '__main__':
    main()