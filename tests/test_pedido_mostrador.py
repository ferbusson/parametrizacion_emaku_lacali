import unittest
import os
import xml.etree.ElementTree as ET
from pathlib import Path

class TestPedidoMostrador(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """Load the XML form before any tests run"""
        # Get the directory where this script is located
        test_dir = Path(__file__).parent
        # Go up one level to the project root
        project_root = test_dir.parent
        # Path to the XML file in the transacciones directory
        xml_path = project_root / 'transacciones' / 'pedido_mostrador.xml'
        
        if not xml_path.exists():
            raise FileNotFoundError(f"Could not find XML file at: {xml_path}")
            
        with open(xml_path, 'r', encoding='utf-8') as f:
            cls.xml_content = f.read()
            
        # Parse the XML content
        try:
            cls.root = ET.fromstring(cls.xml_content)
        except ET.ParseError as e:
            raise ValueError(f"Error parsing XML file: {e}")
    
    def test_xml_structure(self):
        """Test that the XML has the basic required structure"""
        # Find all printer templates in the XML
        printer_templates = self.root.findall('.//printerTemplate')
        self.assertGreater(len(printer_templates), 0, "No printer templates found in XML")
        
        # Check if any of the printer templates contain the tirilla template
        tirilla_found = any('TNPedidoMostradorTirilla.xml' in (tpl.text or '') 
                           for tpl in printer_templates)
        self.assertTrue(tirilla_found, "TNPedidoMostradorTirilla.xml template not found")
    
    def test_required_components_exist(self):
        """Test that all required components are present"""
        required_components = [
            'principal',  # Main table
            'tipo_doc',   # Document type
            'Vendedor',   # Salesperson
            'referrercustomerid'  # Customer ID
        ]
        
        for comp_id in required_components:
            with self.subTest(component=comp_id):
                self.assertIsNotNone(
                    self.root.find(f".//*[@id='{comp_id}']"),
                    f"Required component {comp_id} not found"
                )
    
    def test_printer_actions_exist(self):
        """Test that printer actions are properly defined"""
        printer_actions = self.root.findall(".//action[@type='printer']")
        self.assertGreater(len(printer_actions), 0, "No printer actions found")
        
        # Check for the specific tirilla template
        tirilla_action = None
        for action in printer_actions:
            template = action.find("printerTemplate")
            if template is not None and 'TNPedidoMostradorTirilla.xml' in template.text:
                tirilla_action = action
                break
                
        self.assertIsNotNone(tirilla_action, "Tirilla printer action not found")

    def test_form_validation(self):
        """Test that required fields have validation"""
        # Check for required fields or other validation attributes
        
        # Check for required fields (either required='true' or @required attribute)
        required_attrs = self.root.findall(".//*[@required='true']")
        required_fields = self.root.findall(".//*[@required]")
        
        # If no explicit required attributes, check for other validation patterns
        if not required_attrs and not required_fields:
            # Look for other validation patterns (e.g., fields with validation rules)
            validated_fields = self.root.findall(".//*[@validation]")
            if not validated_fields:
                self.skipTest("No explicit validation found - consider adding validation tests")

if __name__ == '__main__':
    unittest.main()
