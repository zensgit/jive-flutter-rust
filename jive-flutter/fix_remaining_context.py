#!/usr/bin/env python3
"""
Script to fix remaining use_build_context_synchronously warnings correctly.
"""

import os
import re
import subprocess

# Files with their specific fixes needed
MANUAL_FIXES = {
    'lib/widgets/custom_theme_editor.dart': [
        {
            'search': 'await _themeService.createCustomTheme(\n        if (!context.mounted) return;\n          name: finalTheme.name,',
            'replace': 'await _themeService.createCustomTheme(\n          name: finalTheme.name,'
        }
    ]
}

def fix_manual_issues():
    """Fix the specific manual issues."""
    base_path = "/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter"

    for file_path, fixes in MANUAL_FIXES.items():
        full_path = os.path.join(base_path, file_path)

        if not os.path.exists(full_path):
            continue

        with open(full_path, 'r', encoding='utf-8') as f:
            content = f.read()

        modified = False
        for fix in fixes:
            if fix['search'] in content:
                content = content.replace(fix['search'], fix['replace'])
                modified = True
                print(f"Fixed issue in {file_path}")

        if modified:
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(content)

def analyze_and_fix_remaining():
    """Analyze and fix remaining context issues."""
    # Run flutter analyze to get current warnings
    result = subprocess.run(
        ['flutter', 'analyze', '--no-fatal-infos'],
        capture_output=True,
        text=True,
        cwd='/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter'
    )

    context_warnings = []
    for line in result.stdout.split('\n') + result.stderr.split('\n'):
        if 'use_build_context_synchronously' in line and 'warning' in line:
            parts = line.split(' • ')
            if len(parts) >= 3:
                filepath_info = parts[2].strip()
                if ':' in filepath_info:
                    filepath, line_num, col = filepath_info.split(':')
                    context_warnings.append({
                        'file': filepath,
                        'line': int(line_num),
                        'column': int(col)
                    })

    print(f"Found {len(context_warnings)} remaining context warnings")

    # Group by file
    files_warnings = {}
    for warning in context_warnings:
        if warning['file'] not in files_warnings:
            files_warnings[warning['file']] = []
        files_warnings[warning['file']].append(warning)

    # Process each file
    base_path = "/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter"

    for filepath, warnings in files_warnings.items():
        if not filepath.startswith('lib/'):
            continue

        full_path = os.path.join(base_path, filepath)
        if not os.path.exists(full_path):
            continue

        with open(full_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        changes_made = False

        for warning in sorted(warnings, key=lambda x: x['line'], reverse=True):
            line_idx = warning['line'] - 1

            if line_idx >= len(lines):
                continue

            # Look for await pattern before this line
            await_line = None
            for i in range(line_idx - 1, max(0, line_idx - 10), -1):
                if 'await ' in lines[i] and not 'mounted' in lines[i+1:line_idx+1]:
                    await_line = i
                    break

            if await_line is not None:
                # Determine indentation
                indent = len(lines[await_line]) - len(lines[await_line].lstrip())

                # Check if it's in a StatefulWidget context
                is_stateful = any('State<' in line for line in lines[max(0, line_idx-50):line_idx])

                if is_stateful:
                    check = ' ' * indent + 'if (!mounted) return;\n'
                else:
                    check = ' ' * indent + 'if (!context.mounted) return;\n'

                # Insert after the await line(s) - find the end of the statement
                insert_idx = await_line + 1
                while insert_idx < len(lines) and (lines[insert_idx].strip() == '' or
                                                  (not lines[insert_idx].strip().endswith(';') and
                                                   not lines[insert_idx].strip().endswith(');'))):
                    insert_idx += 1

                if insert_idx < len(lines) and lines[insert_idx].strip().endswith((';', ');')):
                    insert_idx += 1

                # Don't insert if already exists
                if insert_idx < len(lines) and 'mounted' not in lines[insert_idx]:
                    lines.insert(insert_idx, '\n' + check)
                    changes_made = True
                    print(f"  Added context check in {filepath} at line {insert_idx + 1}")

        if changes_made:
            with open(full_path, 'w', encoding='utf-8') as f:
                f.writelines(lines)

def main():
    print("Fixing manual issues...")
    fix_manual_issues()

    print("Analyzing and fixing remaining context warnings...")
    analyze_and_fix_remaining()

    print("Done!")

if __name__ == "__main__":
    main()