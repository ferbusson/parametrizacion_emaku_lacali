#!/usr/bin/env python3
"""
Comprehensive XML Payroll File Processor
Automates column mapping, formula translation, and singleSendRecord mapping
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional

class PayrollXMLProcessor:
    def __init__(self):
        # Sigla mapping from novedades_nomina table
        self.sigla_descriptions = {
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
        
        self.column_mapping = {}
        self.external_values = {}
    
    def extract_column_mapping(self, content: str) -> Dict[str, str]:
        """Extract existing column mapping from the file"""
        mapping = {}
        external_vals = {}
        
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
                external_vals[letter] = ext_name.strip()
        
        self.column_mapping = mapping
        self.external_values = external_vals
        return mapping
    
    def generate_column_mapping_from_subargs(self, content: str) -> str:
        """Generate column mapping by analyzing subarg elements"""
        mapping_lines = []
        subarg_pattern = r'<subarg><!-- ([a-z]+).*?-->\s*\n\s*<arg attribute="name">(.+?)</arg>'
        
        matches = re.findall(subarg_pattern, content, re.DOTALL)
        
        for i, (letter, name) in enumerate(matches):
            mapping_lines.append(f"{letter} ({i}) → {name}")
        
        # Add common external value
        mapping_lines.append('zz → External value "dias"')
        
        return '\n'.join(mapping_lines)
    
    def add_column_mapping(self, content: str) -> str:
        """Add column mapping at the beginning of the file"""
        
        # Check if mapping already exists
        if '→' in content and 'External value' in content:
            print("Column mapping already exists, skipping...")
            return content
        
        # Generate mapping from subargs
        mapping = self.generate_column_mapping_from_subargs(content)
        
        # Find insertion point after the task comments
        insertion_pattern = r'(-->\s*\n)(table: novedades_nomina)'
        
        def replace_with_mapping(match):
            return f"{match.group(1)}\n{mapping}\n\n{match.group(2)}"
        
        result = re.sub(insertion_pattern, replace_with_mapping, content)
        
        return result
    
    def translate_formula(self, formula: str) -> str:
        """Translate beanshell formula using column mapping"""
        if not self.column_mapping:
            return formula
        
        translated = formula
        
        # Sort by length (longest first) to avoid partial replacements
        sorted_letters = sorted(self.column_mapping.keys(), key=len, reverse=True)
        
        for letter in sorted_letters:
            description = self.column_mapping[letter]
            # Clean description for variable names
            var_name = self._clean_variable_name(description)
            
            # Replace letter variables with descriptive names
            # Use word boundaries to avoid partial matches
            pattern = r'\b' + re.escape(letter) + r'\b'
            translated = re.sub(pattern, var_name, translated)
        
        # Handle external values
        for ext_letter, ext_name in self.external_values.items():
            pattern = r'\b' + re.escape(ext_letter) + r'\b'
            translated = re.sub(pattern, ext_name, translated)
        
        return translated
    
    def _clean_variable_name(self, description: str) -> str:
        """Convert description to valid variable name"""
        # Handle specific cases
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
            'Vacaciones Pagadas': 'VP_VacacionesPagadas'
        }
        
        if description in replacements:
            return replacements[description]
        
        # General cleanup
        return description.replace(' ', '_').replace('-', '_')
    
    def add_formula_translations(self, content: str) -> str:
        """Add translated formulas as comments"""
        
        # Pattern to match beanshell and formula attributes
        patterns = [
            (r'(<arg attribute="formula">)([^<]+)(</arg>)', 'formula'),
            (r'(<arg attribute="beanshell">)([^<]+)(</arg>)', 'beanshell'),
            (r'(<arg attribute="conditionalColor">)([^<]+)(</arg>)', 'conditionalColor')
        ]
        
        result = content
        
        for pattern, attr_type in patterns:
            def translate_match(match):
                prefix, formula, suffix = match.groups()
                
                # Skip if already has translation comment
                if f"<!-- Translated {attr_type}:" in result[match.start()-200:match.start()]:
                    return match.group(0)
                
                translated = self.translate_formula(formula.strip())
                comment = f"\n                            <!-- Translated {attr_type}: {translated} -->"
                
                return f"{prefix}{formula}{suffix}{comment}"
            
            result = re.sub(pattern, translate_match, result, flags=re.DOTALL)
        
        return result
    
    def analyze_single_send_record(self, content: str) -> str:
        """Analyze and add mapping for singleSendRecord"""
        
        # Find singleSendRecord
        pattern = r'(<arg attribute="singleSendRecord">)([^<]+)(</arg>)'
        
        def add_mapping_comment(match):
            prefix, record, suffix = match.groups()
            
            # Skip if already has mapping comment
            if "<!-- mapping singleSendRecord" in content[match.end():match.end()+200]:
                return match.group(0)
            
            # Parse the record
            values = [v.strip() for v in record.split(',')]
            non_nr_positions = []
            
            for i, value in enumerate(values):
                if value != 'NR':
                    # Find corresponding column description
                    letter = self._position_to_letter(i)
                    if letter in self.column_mapping:
                        description = self.column_mapping[letter]
                        non_nr_positions.append(f"Position {i} → {description}")
            
            if non_nr_positions:
                mapping_text = ", ".join(non_nr_positions)
                comment = f"\n                            <!-- mapping singleSendRecord (positions != NR): {mapping_text} -->"
                return f"{prefix}{record}{suffix}{comment}"
            
            return match.group(0)
        
        return re.sub(pattern, add_mapping_comment, content)
    
    def _position_to_letter(self, position: int) -> str:
        """Convert position number to corresponding letter variable"""
        if position < 26:
            return chr(ord('a') + position)
        else:
            # Handle aa, ab, ac, etc.
            first = chr(ord('a') + (position - 26) // 26)
            second = chr(ord('a') + (position - 26) % 26)
            return first + second
    
    def add_sigla_descriptions(self, content: str) -> str:
        """Add sigla descriptions to XML subarg comments"""
        
        def replace_sigla_comment(match):
            letter_var = match.group(1)
            sigla = match.group(2)
            
            if sigla in self.sigla_descriptions:
                description = self.sigla_descriptions[sigla]
                return f'<subarg><!-- {letter_var} - {sigla}: {description} -->'
            else:
                return match.group(0)
        
        # Pattern to match sigla subargs
        pattern = r'<subarg><!-- ([a-z]+) -->\s*\n\s*<arg attribute="name">([A-Z]{2})</arg>'
        
        return re.sub(pattern, replace_sigla_comment, content, flags=re.MULTILINE)
    
    def process_file(self, file_path: Path) -> bool:
        """Process XML file with all transformations"""
        try:
            print(f"Processing {file_path}...")
            
            # Read file
            content = file_path.read_text(encoding='utf-8')
            
            # Extract existing mapping or generate new one
            self.extract_column_mapping(content)
            
            # Apply transformations
            content = self.add_column_mapping(content)
            
            # Re-extract mapping after potential addition
            self.extract_column_mapping(content)
            
            content = self.add_sigla_descriptions(content)
            content = self.add_formula_translations(content)
            content = self.analyze_single_send_record(content)
            
            # Write back
            file_path.write_text(content, encoding='utf-8')
            
            print(f"✅ Successfully processed {file_path}")
            return True
            
        except Exception as e:
            print(f"❌ Error processing {file_path}: {e}")
            return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 payroll_xml_processor.py <xml_file_path> [xml_file_path2] ...")
        print("       python3 payroll_xml_processor.py --batch <directory_path>")
        sys.exit(1)
    
    processor = PayrollXMLProcessor()
    
    if sys.argv[1] == '--batch':
        # Process all XML files in directory
        if len(sys.argv) != 3:
            print("Error: --batch requires directory path")
            sys.exit(1)
        
        directory = Path(sys.argv[2])
        xml_files = list(directory.glob("*.xml"))
        
        if not xml_files:
            print(f"No XML files found in {directory}")
            sys.exit(1)
        
        success_count = 0
        for xml_file in xml_files:
            if processor.process_file(xml_file):
                success_count += 1
        
        print(f"\n🎉 Processed {success_count}/{len(xml_files)} files successfully")
    
    else:
        # Process individual files
        success_count = 0
        for file_arg in sys.argv[1:]:
            file_path = Path(file_arg)
            
            if not file_path.exists():
                print(f"❌ File not found: {file_path}")
                continue
            
            if processor.process_file(file_path):
                success_count += 1
        
        total_files = len(sys.argv) - 1
        print(f"\n🎉 Processed {success_count}/{total_files} files successfully")

if __name__ == "__main__":
    main()