#!/usr/bin/env python3
"""
Column Mapping Generator for Payroll XML Files
Automatically generates column mapping from subarg definitions
"""

import re
import sys
from pathlib import Path

def generate_column_mapping_from_subargs(content: str) -> str:
    """Generate column mapping by analyzing subarg elements"""
    mapping_lines = []
    
    # Pattern to match subarg elements with their comments and names
    subarg_pattern = r'<subarg><!-- ([a-z]+).*?-->\s*\n\s*<arg attribute="name">([^<]+)</arg>'
    
    matches = re.findall(subarg_pattern, content, re.DOTALL)
    
    print(f"🔍 Found {len(matches)} column definitions")
    
    for i, (letter, name) in enumerate(matches):
        name = name.strip()
        mapping_lines.append(f"{letter} ({i}) → {name}")
        print(f"  {letter} ({i}) → {name}")
    
    # Add common external value
    mapping_lines.append('zz → External value "dias"')
    
    return '\n'.join(mapping_lines)

def add_column_mapping(content: str) -> str:
    """Add column mapping at the beginning of the file"""
    
    # Check if mapping already exists
    if '→' in content and 'External value' in content:
        print("📝 Column mapping already exists, skipping...")
        return content
    
    print("🔄 Generating column mapping from subarg definitions...")
    
    # Generate mapping from subargs
    mapping = generate_column_mapping_from_subargs(content)
    
    if not mapping.strip():
        print("⚠️  No subarg definitions found")
        return content
    
    # Find insertion point after the task comments
    insertion_pattern = r'(-->\s*\n)(table: novedades_nomina)'
    
    def replace_with_mapping(match):
        return f"{match.group(1)}\n{mapping}\n\n{match.group(2)}"
    
    result = re.sub(insertion_pattern, replace_with_mapping, content)
    
    if result != content:
        print("✨ Added column mapping to file header")
    else:
        # Alternative insertion point - after task comments
        alt_pattern = r'(count the elements in the singleSendRecord.*?-->\s*\n)(\n*<)'
        
        def alt_replace_with_mapping(match):
            return f"{match.group(1)}\n{mapping}\n\n{match.group(2)}"
        
        result = re.sub(alt_pattern, alt_replace_with_mapping, content, flags=re.DOTALL)
        
        if result != content:
            print("✨ Added column mapping after task comments")
        else:
            print("⚠️  Could not find suitable insertion point")
    
    return result

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 column_mapping_generator.py <xml_file_path>")
        sys.exit(1)
    
    file_path = Path(sys.argv[1])
    
    if not file_path.exists():
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    
    try:
        print(f"🔄 Generating column mapping for {file_path}")
        
        # Read file
        content = file_path.read_text(encoding='utf-8')
        
        # Add column mapping
        updated_content = add_column_mapping(content)
        
        # Write back
        file_path.write_text(updated_content, encoding='utf-8')
        
        print(f"✅ Successfully updated {file_path}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()