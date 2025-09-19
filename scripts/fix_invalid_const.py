#!/usr/bin/env python3
"""
Fix invalid const errors in Flutter code.
Removes const keywords where they're not allowed.
"""

import re
import os
import sys
from pathlib import Path

def extract_errors_from_analyzer(analyzer_log):
    """Extract invalid_constant and const_with_non_const errors from analyzer output."""
    errors = []

    # Pattern for invalid_constant errors
    # Example: error • Invalid constant value • jive-flutter/lib/path/file.dart:123:45 • invalid_constant
    pattern1 = r'error\s+•\s+Invalid constant value\s+•\s+(?P<file>[^:]+):(?P<line>\d+):(?P<col>\d+)\s+•\s+invalid_constant'

    # Pattern for const_with_non_const errors
    # Example: error • The constructor being called isn't a const constructor • jive-flutter/lib/path/file.dart:123:45 • const_with_non_const
    pattern2 = r'error\s+•\s+The constructor being called isn\'t a const constructor\s+•\s+(?P<file>[^:]+):(?P<line>\d+):(?P<col>\d+)\s+•\s+const_with_non_const'

    for line in analyzer_log.split('\n'):
        line = line.strip()
        if not line:
            continue

        match = re.match(pattern1, line)
        if not match:
            match = re.match(pattern2, line)

        if match:
            errors.append({
                'file': match.group('file'),
                'line': int(match.group('line')),
                'col': int(match.group('col'))
            })

    return errors

def remove_const_at_position(file_path, line_num, col_num):
    """Remove const keyword at specific position."""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()

        if line_num <= 0 or line_num > len(lines):
            print(f"Warning: Line {line_num} out of range in {file_path}")
            return False

        # Get the line (0-indexed)
        line_idx = line_num - 1
        line = lines[line_idx]

        # Find const keyword at or near the column position
        # Look for 'const ' (with space after)
        const_pattern = r'\bconst\s+'

        # Try to find const near the column position
        start = max(0, col_num - 20)  # Look back a bit
        end = min(len(line), col_num + 20)  # Look forward a bit
        segment = line[start:end]

        match = re.search(const_pattern, segment)
        if match:
            # Calculate actual position in line
            actual_pos = start + match.start()

            # Remove the const keyword
            new_line = line[:actual_pos] + line[actual_pos + len('const '):]
            lines[line_idx] = new_line

            # Write back
            with open(file_path, 'w') as f:
                f.writelines(lines)

            return True
        else:
            # Try removing const from the entire line if column match fails
            new_line = re.sub(r'\bconst\s+', '', line, count=1)
            if new_line != line:
                lines[line_idx] = new_line
                with open(file_path, 'w') as f:
                    f.writelines(lines)
                return True

        print(f"Warning: Could not find const at {file_path}:{line_num}:{col_num}")
        return False

    except Exception as e:
        print(f"Error processing {file_path}:{line_num}:{col_num}: {e}")
        return False

def main():
    # Read analyzer output from artifacts or temp file
    analyzer_file = '/tmp/analyzer_output.txt'

    # Fall back to artifacts if temp file doesn't exist
    if not os.path.exists(analyzer_file):
        analyzer_file = 'artifacts/analyzer_output.txt'

    if not os.path.exists(analyzer_file):
        print(f"Error: No analyzer output found. Run 'flutter analyze > /tmp/analyzer_output.txt' first.")
        sys.exit(1)

    with open(analyzer_file, 'r') as f:
        analyzer_output = f.read()

    # Extract errors
    errors = extract_errors_from_analyzer(analyzer_output)

    # Filter for jive-flutter directory only (files may have jive-flutter/ prefix)
    filtered_errors = []
    for e in errors:
        file_path = e['file']
        # Remove jive-flutter/ prefix if present
        if file_path.startswith('jive-flutter/'):
            file_path = file_path[len('jive-flutter/'):]
        # Only keep lib/ files
        if file_path.startswith('lib/'):
            e['file'] = file_path
            filtered_errors.append(e)
    errors = filtered_errors

    if not errors:
        print("No invalid const errors found.")
        return

    print(f"Found {len(errors)} invalid const errors to fix")

    # Group errors by file
    errors_by_file = {}
    for error in errors:
        if error['file'] not in errors_by_file:
            errors_by_file[error['file']] = []
        errors_by_file[error['file']].append(error)

    # Sort errors by line number in reverse order (process from bottom to top)
    for file_path in errors_by_file:
        errors_by_file[file_path].sort(key=lambda e: e['line'], reverse=True)

    # Process each file
    fixed_count = 0
    for file_path, file_errors in errors_by_file.items():
        # Try both with and without jive-flutter prefix
        full_path = file_path
        if not os.path.exists(full_path):
            full_path = f"jive-flutter/{file_path}"

        if not os.path.exists(full_path):
            print(f"Warning: File not found: {file_path}")
            continue

        print(f"Processing {file_path} ({len(file_errors)} errors)...")

        for error in file_errors:
            if remove_const_at_position(full_path, error['line'], error['col']):
                fixed_count += 1

    print(f"\nFixed {fixed_count} out of {len(errors)} invalid const errors")

if __name__ == '__main__':
    main()