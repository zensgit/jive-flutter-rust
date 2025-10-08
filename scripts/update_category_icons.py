#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
更新数据库中分类的图标文件名，使其与实际的PNG文件对应
"""

import json
import psycopg2
import os
from pathlib import Path

# 数据库配置
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5433'),
    'database': os.getenv('DB_NAME', 'jive_money'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', 'postgres')
}

# 资源文件路径
MAPPINGS_FILE = '/Users/huazhou/Library/CloudStorage/SynologyDrive-mac/github/resources/category_icon_mappings.json'
ICONS_DIR = '/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter/assets/icons/categories'

def main():
    # 加载分类映射数据
    print("Loading category mappings...")
    with open(MAPPINGS_FILE, 'r', encoding='utf-8') as f:
        mappings = json.load(f)

    # 创建分类名到图标文件名的映射
    category_icons = {}
    for item in mappings:
        name = item['category_name']
        icon_file = item.get('icon_file', '')
        if icon_file and name not in category_icons:
            category_icons[name] = icon_file

    print(f"Found {len(category_icons)} categories with icons")

    # 连接数据库
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    # 统计信息
    updated_count = 0
    missing_icons = []

    # 更新每个分类的图标
    for name, icon_file in category_icons.items():
        # 检查图标文件是否存在
        icon_path = Path(ICONS_DIR) / icon_file
        if not icon_path.exists():
            missing_icons.append((name, icon_file))
            continue

        # 更新数据库
        cur.execute("""
            UPDATE system_category_templates
            SET icon = %s
            WHERE name = %s
        """, (icon_file, name))

        if cur.rowcount > 0:
            updated_count += cur.rowcount
            print(f"✓ Updated {name} -> {icon_file} ({cur.rowcount} records)")

    # 提交更改
    conn.commit()

    # 查询没有图标的分类
    cur.execute("""
        SELECT DISTINCT name
        FROM system_category_templates
        WHERE icon IS NULL OR icon = ''
        ORDER BY name
    """)
    no_icon_categories = cur.fetchall()

    # 关闭连接
    cur.close()
    conn.close()

    # 打印统计信息
    print("\n" + "="*60)
    print(f"✅ Update Summary:")
    print(f"  - Total categories with icons: {len(category_icons)}")
    print(f"  - Records updated: {updated_count}")
    print(f"  - Missing icon files: {len(missing_icons)}")

    if missing_icons:
        print(f"\n⚠️  Missing icon files:")
        for name, icon_file in missing_icons[:10]:
            print(f"    - {name}: {icon_file}")
        if len(missing_icons) > 10:
            print(f"    ... and {len(missing_icons) - 10} more")

    if no_icon_categories:
        print(f"\n📋 Categories without icons: {len(no_icon_categories)}")
        for (name,) in no_icon_categories[:10]:
            print(f"    - {name}")
        if len(no_icon_categories) > 10:
            print(f"    ... and {len(no_icon_categories) - 10} more")

    print("\n✨ Icon update completed!")

if __name__ == '__main__':
    main()