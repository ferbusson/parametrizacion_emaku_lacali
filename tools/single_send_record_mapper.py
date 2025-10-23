#!/usr/bin/env python3
"""
SingleSendRecord Mapper for Payroll XML Files
Analyzes singleSendRecord and adds position mapping comments
"""

import re
import sys
from pathlib import Path
from typing import Dict, List

def extract_column_mapping(content: str) -> Dict[str, str]:
    """Extract column mapping from file header"""
    mapping = {}
    
    # Pattern to match mapping lines like "a (0) → Documento"
    pattern = r'([a-z]+) \((\d+)\) → (.+)'
    
    lines = content.split('\n')
    for line in lines:
        line = line.strip()
        match = re.match(pattern, line)
        if match:
            letter, position, description = match.groups()
            mapping[letter] = description.strip()
    
    return mapping

def position_to_letter(position: int) -> str:
    """Convert position number to corresponding letter variable"""
    if position < 26:
        return chr(ord('a') + position)
    else:
        # Handle aa, ab, ac, etc. (26=aa, 27=ab, etc.)
        first_index = (position - 26) // 26
        second_index = (position - 26) % 26
        first = chr(ord('a') + first_index)
        second = chr(ord('a') + second_index)
        return first + second

def analyze_single_send_record(content: str) -> str:
    """Analyze and add mapping for singleSendRecord"""
    
    # Extract column mapping
    column_mapping = extract_column_mapping(content)
    
    if not column_mapping:
        print("⚠️  No column mapping found in file")
        return content
    
    print(f"📋 Found {len(column_mapping)} column mappings")
    
    # Find singleSendRecord
    pattern = r'(<arg attribute="singleSendRecord">)([^<]+)(</arg>)'
    
    def add_mapping_comment(match):
        prefix, record, suffix = match.groups()
        
        # Skip if already has mapping comment
        post_match_content = content[match.end():match.end()+300]
        if "<!-- mapping singleSendRecord" in post_match_content:
            print("📝 SingleSendRecord mapping comment already exists, skipping...")
            return match.group(0)
        
        # Parse the record
        values = [v.strip() for v in record.split(',')]
        non_nr_positions = []
        
        print(f"🔍 Analyzing singleSendRecord with {len(values)} positions...")
        
        for i, value in enumerate(values):
            if value != 'NR':
                letter = position_to_letter(i)
                if letter in column_mapping:
                    description = column_mapping[letter]
                    non_nr_positions.append(f"Position {i} → {description}")
                    print(f"  ✓ Position {i} ({letter}): {value} → {description}")
                else:
                    non_nr_positions.append(f"Position {i} → Unknown ({letter})")
                    print(f"  ⚠️  Position {i} ({letter}): {value} → Unknown mapping")
        
        if non_nr_positions:
            mapping_text = ", ".join(non_nr_positions)
            comment = f"\n                            <!-- mapping singleSendRecord (positions != NR): {mapping_text} -->"
            print(f"✨ Added mapping comment for {len(non_nr_positions)} non-NR positions")
            return f"{prefix}{record}{suffix}{comment}"
        else:
            print("ℹ️  No non-NR positions found in singleSendRecord")
        
        return match.group(0)
    
    result = re.sub(pattern, add_mapping_comment, content)
    return result

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 single_send_record_mapper.py <xml_file_path>")
        sys.exit(1)
    
    file_path = Path(sys.argv[1])
    
    if not file_path.exists():
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    
    try:
        print(f"🔄 Analyzing singleSendRecord in {file_path}")
        
        # Read file
        content = file_path.read_text(encoding='utf-8')
        
        # Analyze singleSendRecord
        updated_content = analyze_single_send_record(content)
        
        # Write back
        file_path.write_text(updated_content, encoding='utf-8')
        
        print(f"✅ Successfully updated {file_path}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()