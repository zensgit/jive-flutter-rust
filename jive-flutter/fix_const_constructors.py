#!/usr/bin/env python3
import os
import re
import subprocess

def fix_const_constructors():
    """Add const to constructors that can be const"""
    # Common patterns to fix
    patterns = [
        # Simple widget constructors
        (r'(\s+)Text\(([^)]+)\)(\s*(?:,|\)))', r'\1const Text(\2)\3'),
        (r'(\s+)Icon\(([^)]+)\)(\s*(?:,|\)))', r'\1const Icon(\2)\3'),
        (r'(\s+)SizedBox\(([^)]+)\)(\s*(?:,|\)))', r'\1const SizedBox(\2)\3'),
        (r'(\s+)EdgeInsets\.([^)]+)\)(\s*(?:,|\)))', r'\1const EdgeInsets.\2)\3'),
        (r'(\s+)Padding\(\s*padding:\s*EdgeInsets\.([^}]+)\})', r'\1const Padding(padding: EdgeInsets.\2}'),
        (r'(\s+)Container\(\s*child:\s*Text\(([^)]+)\)\s*\)', r'\1Container(child: const Text(\2))'),
    ]

    fixed_count = 0
    dart_files = []

    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))

    for file_path in dart_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            original_content = content

            for pattern, replacement in patterns:
                content = re.sub(pattern, replacement, content)

            # Additional manual fixes for common patterns
            # Fix: new Widget() -> const Widget()
            content = re.sub(r'(\s+)Text\s*\(', r'\1const Text(', content)
            content = re.sub(r'(\s+)Icon\s*\(', r'\1const Icon(', content)
            content = re.sub(r'(\s+)SizedBox\s*\(', r'\1const SizedBox(', content)

            # Remove duplicate const keywords
            content = re.sub(r'const\s+const\s+', 'const ', content)

            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Fixed const constructors in: {file_path}")
                fixed_count += 1

        except Exception as e:
            print(f"Error processing {file_path}: {e}")

    return fixed_count

def main():
    print("Fixing const constructors...")
    fixed_count = fix_const_constructors()
    print(f"Applied const fixes to {fixed_count} files")

if __name__ == '__main__':
    main()