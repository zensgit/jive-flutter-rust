#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Import comprehensive category hierarchy with parent-child relationships
"""

import json
import psycopg2
import os
import uuid
from pathlib import Path
from pypinyin import lazy_pinyin, Style

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5433'),
    'database': os.getenv('DB_NAME', 'jive_money'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', 'postgres')
}

# File paths
HIERARCHY_FILE = '/Users/huazhou/Library/CloudStorage/SynologyDrive-mac/github/resources/category_hierarchy.json'

def get_pinyin(text):
    """Generate pinyin and abbreviation for Chinese text"""
    if not text:
        return None, None

    # Full pinyin
    pinyin_list = lazy_pinyin(text, style=Style.NORMAL)
    full_pinyin = ''.join(pinyin_list)

    # Abbreviation (first letter of each character)
    abbr_list = lazy_pinyin(text, style=Style.FIRST_LETTER)
    abbr = ''.join(abbr_list)

    return full_pinyin, abbr

def main():
    print("Loading category hierarchy...")
    with open(HIERARCHY_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Connect to database
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    # Clear existing categories (optional - comment out to append)
    print("Clearing existing categories...")
    cur.execute("DELETE FROM system_category_templates")

    # Statistics
    total_imported = 0
    parent_map = {}  # Map original IDs to new UUIDs

    # Process categories by type
    for cat_type in ['expense', 'income']:
        type_name = cat_type
        categories = data[cat_type]['primary']

        print(f"\n{'='*60}")
        print(f"Processing {cat_type} categories: {len(categories)} primary")

        # First pass: Import parent categories
        for category in categories:
            cat_id = str(uuid.uuid4())
            parent_map[category['id']] = cat_id

            name = category['name']
            icon_file = category.get('icon_file') or 'default.png'  # Default icon if none

            # Generate pinyin
            pinyin_full, pinyin_abbr = get_pinyin(name)

            # Default colors for categories
            default_color = '#4CAF50' if type_name == 'income' else '#FF5252'

            # Insert parent category
            cur.execute("""
                INSERT INTO system_category_templates
                (id, name, name_en, name_pinyin, name_pinyin_abbr, icon, type, parent_id, is_active, color)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO NOTHING
            """, (
                cat_id,
                name,
                name,  # Use Chinese name as English temporarily
                pinyin_full,
                pinyin_abbr,
                icon_file,
                type_name,
                None,  # No parent for top-level categories
                True,
                default_color
            ))

            if cur.rowcount > 0:
                total_imported += 1
                print(f"✓ {name} ({cat_type}) - {len(category.get('children', []))} children")

            # Second pass: Import child categories
            for child in category.get('children', []):
                child_id = str(uuid.uuid4())
                child_name = child['name']
                child_icon = child.get('icon_file') or 'default.png'  # Default icon if none

                # Generate pinyin for child
                child_pinyin_full, child_pinyin_abbr = get_pinyin(child_name)

                # Insert child category
                cur.execute("""
                    INSERT INTO system_category_templates
                    (id, name, name_en, name_pinyin, name_pinyin_abbr, icon, type, parent_id, is_active, color)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (id) DO NOTHING
                """, (
                    child_id,
                    child_name,
                    child_name,  # Use Chinese name as English temporarily
                    child_pinyin_full,
                    child_pinyin_abbr,
                    child_icon,
                    type_name,
                    cat_id,  # Link to parent
                    True,
                    default_color
                ))

                if cur.rowcount > 0:
                    total_imported += 1
                    print(f"  → {child_name}")

    # Commit changes
    conn.commit()

    # Get summary statistics
    cur.execute("""
        SELECT type, COUNT(*) as count,
               SUM(CASE WHEN parent_id IS NULL THEN 1 ELSE 0 END) as parent_count,
               SUM(CASE WHEN parent_id IS NOT NULL THEN 1 ELSE 0 END) as child_count
        FROM system_category_templates
        WHERE is_active = true
        GROUP BY type
    """)
    stats = cur.fetchall()

    # Close connection
    cur.close()
    conn.close()

    # Print summary
    print("\n" + "="*60)
    print(f"✅ Import Summary:")
    print(f"  - Total categories imported: {total_imported}")

    for type_name, total, parents, children in stats:
        print(f"\n  {type_name.capitalize()}:")
        print(f"    - Parent categories: {parents}")
        print(f"    - Child categories: {children}")
        print(f"    - Total: {total}")

    print("\n✨ Category hierarchy import completed!")

if __name__ == '__main__':
    main()