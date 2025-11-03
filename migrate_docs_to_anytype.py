#!/usr/bin/env python3
"""
docs ディレクトリの全Markdownファイルを Anytype の meiso スペースに移行するスクリプト
"""

import os
import glob
import json
import subprocess
import time

# Anytype meiso スペースID
SPACE_ID = "bafyreifchnuh4afkfy4l2zlla3n4rz3gjdtukztbbzw5gyzepguy4bxi7a.hu7i6rup4ith"

# docsディレクトリのパス
DOCS_DIR = "/Users/apple/work/meiso/docs"

def read_markdown_file(filepath):
    """Markdownファイルを読み込む"""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def get_title_from_content(content):
    """Markdownの最初の # タイトルを抽出"""
    lines = content.split('\n')
    for line in lines:
        if line.startswith('# '):
            return line[2:].strip()
    # タイトルが見つからない場合はファイル名を使用
    return None

def create_anytype_object_via_mcp(space_id, name, body):
    """MCP経由でAnytypeオブジェクトを作成"""
    # この関数は実際にはCursor内のMCP関数を使う必要があります
    # ここではプレースホルダーです
    print(f"  Creating: {name}")
    return True

def main():
    # Markdownファイルを取得
    md_files = glob.glob(os.path.join(DOCS_DIR, "*.md"))
    md_files.sort()
    
    print(f"Found {len(md_files)} Markdown files")
    print(f"Target Anytype space: {SPACE_ID}")
    print()
    
    success_count = 0
    fail_count = 0
    
    for md_file in md_files:
        filename = os.path.basename(md_file)
        title = filename.replace('.md', '').replace('_', ' ')
        
        print(f"Processing: {filename}")
        
        try:
            # ファイル内容を読み込み
            content = read_markdown_file(md_file)
            
            # タイトルを抽出（最初の # 見出しから）
            content_title = get_title_from_content(content)
            if content_title:
                title = content_title
            
            # Anytypeオブジェクトを作成（実際の実装は手動で行う必要があります）
            # create_anytype_object_via_mcp(SPACE_ID, title, content)
            
            # ここでは情報を出力するのみ
            print(f"  Title: {title}")
            print(f"  Size: {len(content)} bytes")
            print()
            
            success_count += 1
            
        except Exception as e:
            print(f"  ERROR: {e}")
            fail_count += 1
    
    print(f"\nSummary:")
    print(f"  Success: {success_count}")
    print(f"  Failed: {fail_count}")
    print(f"  Total: {len(md_files)}")

if __name__ == "__main__":
    main()

