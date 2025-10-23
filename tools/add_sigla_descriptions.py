#!/usr/bin/env python3
"""
Script to automatically add sigla descriptions to XML payroll files
"""

import re
import sys
from pathlib import Path

# Sigla mapping from novedades_nomina table
SIGLA_DESCRIPTIONS = {
    'IG': 'Incapacidad General',
    'IL': 'Incapacidad Laboral', 
    'LM': 'Licencia de Maternidad',
    'LP': 'Licencia de Paternidad',
    'LR': 'Licencia Remunerada',
    'LN': 'Licencia No Remunerada',
    'SC': 'Suspensión de Contrato',
    'IN': 'Ingreso',
    'RE': 'Retiro',
    'VC': 'Vacaciones Disfrutadas',
    'VP': 'Vacaciones Pagadas',
    'IE': 'Incapacidad x cobrar a EPS'
}

def add_sigla_descriptions(xml_content: str) -> str:
    """
    Add sigla descriptions to XML subarg comments
    """
    
    def replace_sigla_comment(match):
        letter_var = match.group(1)  # The letter variable (t, u, v, etc.)
        sigla = match.group(2)       # The sigla (IG, IL, LM, etc.)
        
        if sigla in SIGLA_DESCRIPTIONS:
            description = SIGLA_DESCRIPTIONS[sigla]
            return f'<subarg><!-- {letter_var} - {sigla}: {description} -->'
        else:
            return match.group(0)  # Return unchanged if sigla not found
    
    # Pattern to match: <subarg><!-- letter --> followed by <arg attribute="name">SIGLA</arg>
    pattern = r'<subarg><!-- ([a-z]+) -->\s*\n\s*<arg attribute="name">([A-Z]{2})</arg>'
    
    # Replace the pattern
    result = re.sub(pattern, replace_sigla_comment, xml_content, flags=re.MULTILINE)
    
    return result

def main():
    if len(sys.argv) != 2:
        print("Usage: python add_sigla_descriptions.py <xml_file_path>")
        sys.exit(1)
    
    file_path = Path(sys.argv[1])
    
    if not file_path.exists():
        print(f"File not found: {file_path}")
        sys.exit(1)
    
    # Read the file
    content = file_path.read_text(encoding='utf-8')
    
    # Process sigla descriptions
    updated_content = add_sigla_descriptions(content)
    
    # Write back to file
    file_path.write_text(updated_content, encoding='utf-8')
    
    print(f"Successfully updated sigla descriptions in {file_path}")

if __name__ == "__main__":
    main()