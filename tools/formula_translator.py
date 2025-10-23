#!/usr/bin/env python3
"""
Formula Translation Tool for Payroll XML Files
Translates beanshell formulas using existing column mappings
"""

import re
import sys
from pathlib import Path
from typing import Dict

def extract_column_mapping(content: str) -> Dict[str, str]:
    """Extract column mapping from file header"""
    mapping = {}
    external_values = {}
    
    # Pattern to match mapping lines like "a (0) → Documento"
    pattern = r'([a-z]+) \((\d+)\) → (.+)'
    # Pattern for external values like "zz → External value "dias""
    external_pattern = r'([a-z]+) → External value "(.+)"'
    
    lines = content.split('\n')
    for line in lines:
        line = line.strip()
        
        # Check for regular mapping
        match = re.match(pattern, line)
        if match:
            letter, position, description = match.groups()
            mapping[letter] = description.strip()
            continue
        
        # Check for external values
        ext_match = re.match(external_pattern, line)
        if ext_match:
            letter, ext_name = ext_match.groups()
            mapping[letter] = ext_name.strip()
    
    return mapping

def clean_variable_name(description: str) -> str:
    """Convert description to valid variable name"""
    replacements = {
        'Salario Base': 'SalarioBase',
        'VR HED': 'VR_HED', 
        'VR HEN': 'VR_HEN',
        'Incapacidad General': 'IG_IncapacidadGeneral',
        'Incapacidad Laboral': 'IL_IncapacidadLaboral',
        'Licencia de Maternidad': 'LM_LicenciaMaternidad',
        'Licencia de Paternidad': 'LP_LicenciaPaternidad',
        'Licencia Remunerada': 'LR_LicenciaRemunerada',
        'Licencia No Remunerada': 'LN_LicenciaNoRemunerada',
        'Suspensión de Contrato': 'SC_SuspensionContrato',
        'Vacaciones Disfrutadas': 'VC_VacacionesDisfrutadas',
        'Vacaciones Pagadas': 'VP_VacacionesPagadas',
        'dias': 'dias'  # Keep external values as-is
    }
    
    if description in replacements:
        return replacements[description]
    
    # General cleanup
    return description.replace(' ', '_').replace('-', '_')

def translate_formula(formula: str, column_mapping: Dict[str, str]) -> str:
    """Translate formula using column mapping"""
    translated = formula
    
    # Sort by length (longest first) to avoid partial replacements
    sorted_letters = sorted(column_mapping.keys(), key=len, reverse=True)
    
    for letter in sorted_letters:
        description = column_mapping[letter]
        var_name = clean_variable_name(description)
        
        # Replace letter variables with descriptive names
        # Use word boundaries to avoid partial matches
        pattern = r'\b' + re.escape(letter) + r'\b'
        translated = re.sub(pattern, var_name, translated)
    
    return translated

def add_formula_translations(content: str) -> str:
    """Add translated formulas as comments"""
    
    # Extract column mapping
    column_mapping = extract_column_mapping(content)
    
    if not column_mapping:
        print("⚠️  No column mapping found in file")
        return content
    
    print(f"📋 Found {len(column_mapping)} column mappings")
    
    # Patterns for different formula types
    patterns = [
        (r'(<arg attribute="formula">)([^<]+)(</arg>)', 'formula'),
        (r'(<arg attribute="beanshell">)([^<]+?)(</arg>)', 'beanshell'),
        (r'(<arg attribute="conditionalColor">)([^<]+)(</arg>)', 'conditionalColor')
    ]
    
    result = content
    translations_added = 0
    
    for pattern, attr_type in patterns:
        def translate_match(match):
            nonlocal translations_added
            prefix, formula, suffix = match.groups()
            
            # Skip if already has translation comment right after
            post_match = result[match.end():match.end()+300]
            if f"<!-- Translated {attr_type}:" in post_match:
                return match.group(0)
            
            translated = translate_formula(formula.strip(), column_mapping)
            
            # Only add comment if translation actually changed something
            if translated != formula.strip():
                comment = f"\n                            <!-- Translated {attr_type}: {translated} -->"
                translations_added += 1
                return f"{prefix}{formula}{suffix}{comment}"
            
            return match.group(0)
        
        result = re.sub(pattern, translate_match, result, flags=re.DOTALL)
    
    print(f"✨ Added {translations_added} formula translations")
    return result

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 formula_translator.py <xml_file_path>")
        sys.exit(1)
    
    file_path = Path(sys.argv[1])
    
    if not file_path.exists():
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    
    try:
        print(f"🔄 Translating formulas in {file_path}")
        
        # Read file
        content = file_path.read_text(encoding='utf-8')
        
        # Translate formulas
        updated_content = add_formula_translations(content)
        
        # Write back
        file_path.write_text(updated_content, encoding='utf-8')
        
        print(f"✅ Successfully updated {file_path}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()