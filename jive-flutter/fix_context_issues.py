#!/usr/bin/env python3
import os
import re
import glob

def fix_build_context_synchronously(file_path):
    """Fix use_build_context_synchronously issues in a Dart file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        lines = content.split('\n')
        new_lines = []
        changed = False

        i = 0
        while i < len(lines):
            line = lines[i]

            # Pattern to detect context usage after await
            # Look for patterns like: await something; ... context.method()
            if 'await ' in line and i < len(lines) - 10:  # Look ahead up to 10 lines
                # Check following lines for context usage
                for j in range(i + 1, min(i + 10, len(lines))):
                    next_line = lines[j].strip()

                    # Skip empty lines and comments
                    if not next_line or next_line.startswith('//'):
                        continue

                    # If we hit a return, break, continue, or closing brace, stop searching
                    if next_line.startswith(('return', 'break', 'continue')) or next_line == '}':
                        break

                    # Check for context usage patterns
                    context_patterns = [
                        r'context\.',
                        r'Navigator\.of\(context\)',
                        r'ScaffoldMessenger\.of\(context\)',
                        r'Theme\.of\(context\)',
                        r'MediaQuery\.of\(context\)',
                        r'showDialog\(',
                        r'showModalBottomSheet\(',
                    ]

                    for pattern in context_patterns:
                        if re.search(pattern, next_line):
                            # Add mounted check before context usage
                            indent = len(lines[j]) - len(lines[j].lstrip())
                            indent_str = ' ' * indent

                            # Check if mounted check already exists in the vicinity
                            has_mounted_check = False
                            for k in range(max(0, j-3), j):
                                if 'mounted' in lines[k] and ('if' in lines[k] or 'return' in lines[k]):
                                    has_mounted_check = True
                                    break

                            if not has_mounted_check and 'mounted' not in lines[j]:
                                # Add mounted check
                                new_lines.append(line)  # Current line with await
                                # Add lines between
                                for k in range(i + 1, j):
                                    new_lines.append(lines[k])
                                # Add mounted check
                                new_lines.append(f'{indent_str}if (!mounted) return;')
                                # Add the context usage line
                                new_lines.append(lines[j])
                                # Skip processed lines
                                i = j + 1
                                changed = True
                                break

                    if changed:
                        break

                if not changed:
                    new_lines.append(line)
                    i += 1
            else:
                new_lines.append(line)
                i += 1

        # Write back if changes were made
        if changed:
            new_content = '\n'.join(new_lines)
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Fixed context issues in: {file_path}")
            return True

    except Exception as e:
        print(f"Error processing {file_path}: {e}")

    return False

def fix_simple_context_issues(file_path):
    """Fix simple patterns of context usage after await"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Pattern 1: await something; context.method()
        pattern1 = r'([ \t]*)(await [^;]+;)\s*\n([ \t]*)(context\.[^;]+;)'
        replacement1 = r'\1\2\n\3if (!mounted) return;\n\4\5'

        # Pattern 2: await something; Navigator.of(context)
        pattern2 = r'([ \t]*)(await [^;]+;)\s*\n([ \t]*)(Navigator\.of\(context\)[^;]+;)'
        replacement2 = r'\1\2\n\3if (!mounted) return;\n\4\5'

        # Pattern 3: await something; ScaffoldMessenger.of(context)
        pattern3 = r'([ \t]*)(await [^;]+;)\s*\n([ \t]*)(ScaffoldMessenger\.of\(context\)[^;]+;)'
        replacement3 = r'\1\2\n\3if (!mounted) return;\n\4\5'

        new_content = content
        changed = False

        for pattern, replacement in [(pattern1, replacement1), (pattern2, replacement2), (pattern3, replacement3)]:
            if re.search(pattern, new_content, re.MULTILINE):
                new_content = re.sub(pattern, replacement, new_content, flags=re.MULTILINE)
                changed = True

        # Write back if changes were made
        if changed:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Fixed simple context patterns in: {file_path}")
            return True

    except Exception as e:
        print(f"Error processing {file_path}: {e}")

    return False

def main():
    # Get list of files with context issues
    result = os.popen('flutter analyze 2>&1 | grep "use_build_context_synchronously"').read()

    files_with_issues = set()
    for line in result.strip().split('\n'):
        if line.strip():
            # Extract file path from analyze output
            match = re.search(r'• ([^•]+):(\d+):(\d+) •', line)
            if match:
                file_path = match.group(1)
                if file_path.startswith('lib/'):
                    files_with_issues.add(file_path)

    fixed_count = 0
    for file_path in files_with_issues:
        if os.path.exists(file_path):
            if fix_simple_context_issues(file_path):
                fixed_count += 1

    print(f"Attempted to fix {fixed_count} files with context issues")

if __name__ == '__main__':
    main()