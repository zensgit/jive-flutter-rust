#!/usr/bin/env python3
"""
Script to fix all use_build_context_synchronously warnings in Flutter project.
"""

import os
import re
import subprocess

def get_context_warnings():
    """Get all use_build_context_synchronously warnings from flutter analyze."""
    try:
        result = subprocess.run(
            ['flutter', 'analyze', '--no-fatal-infos'],
            capture_output=True,
            text=True,
            cwd='/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter'
        )

        warnings = []
        for line in result.stdout.split('\n') + result.stderr.split('\n'):
            if 'use_build_context_synchronously' in line:
                # Parse line format: warning • message • filepath:line:col • use_build_context_synchronously
                parts = line.split(' • ')
                if len(parts) >= 3:
                    filepath_info = parts[2].strip()
                    if ':' in filepath_info:
                        filepath, line_num, col = filepath_info.split(':')
                        warnings.append({
                            'file': filepath,
                            'line': int(line_num),
                            'column': int(col),
                            'message': parts[1].strip()
                        })

        return warnings
    except Exception as e:
        print(f"Error running flutter analyze: {e}")
        return []

def fix_file_warnings(filepath, warnings_for_file):
    """Fix all warnings in a specific file."""
    full_path = f"/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter/{filepath}"

    if not os.path.exists(full_path):
        print(f"File not found: {full_path}")
        return

    print(f"Fixing {len(warnings_for_file)} warnings in {filepath}")

    with open(full_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Sort warnings by line number in descending order to avoid line number shifting
    warnings_for_file.sort(key=lambda x: x['line'], reverse=True)

    changes_made = False

    for warning in warnings_for_file:
        line_idx = warning['line'] - 1  # Convert to 0-based index

        if line_idx >= len(lines):
            continue

        line_content = lines[line_idx].strip()

        # Find the previous async operation
        async_line_idx = None
        for i in range(line_idx - 1, max(0, line_idx - 20), -1):
            if 'await ' in lines[i]:
                async_line_idx = i
                break

        if async_line_idx is not None:
            # Check if we're in a StatefulWidget (has 'mounted') or function with BuildContext parameter
            is_stateful = False
            for i in range(max(0, line_idx - 50), line_idx):
                if 'class ' in lines[i] and 'State<' in lines[i]:
                    is_stateful = True
                    break

            # Insert the appropriate mounted check
            indent = len(lines[async_line_idx]) - len(lines[async_line_idx].lstrip())
            indent_str = ' ' * indent

            if is_stateful:
                check_line = f"{indent_str}if (!mounted) return;\n"
            else:
                check_line = f"{indent_str}if (!context.mounted) return;\n"

            # Insert after the await line
            next_line_idx = async_line_idx + 1

            # Check if check already exists
            if next_line_idx < len(lines) and 'mounted' in lines[next_line_idx]:
                continue

            lines.insert(next_line_idx, check_line)
            changes_made = True
            print(f"  Added mounted check at line {next_line_idx + 1}")

    if changes_made:
        with open(full_path, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print(f"  Saved changes to {filepath}")

def main():
    print("Getting use_build_context_synchronously warnings...")
    warnings = get_context_warnings()

    if not warnings:
        print("No warnings found!")
        return

    print(f"Found {len(warnings)} warnings")

    # Group warnings by file
    files_with_warnings = {}
    for warning in warnings:
        filepath = warning['file']
        if filepath not in files_with_warnings:
            files_with_warnings[filepath] = []
        files_with_warnings[filepath].append(warning)

    # Fix each file
    for filepath, file_warnings in files_with_warnings.items():
        if not filepath.startswith('lib/'):
            continue
        fix_file_warnings(filepath, file_warnings)

    print("\nDone! Re-running flutter analyze to check results...")

    # Re-run flutter analyze to check remaining warnings
    remaining_warnings = get_context_warnings()
    context_warnings = [w for w in remaining_warnings if 'use_build_context_synchronously' in str(w)]

    if context_warnings:
        print(f"Still have {len(context_warnings)} use_build_context_synchronously warnings")
        for warning in context_warnings[:10]:  # Show first 10
            print(f"  {warning['file']}:{warning['line']} - {warning['message']}")
    else:
        print("All use_build_context_synchronously warnings fixed!")

if __name__ == "__main__":
    main()