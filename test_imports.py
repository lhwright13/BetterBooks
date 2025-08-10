#!/usr/bin/env python3
"""
Simple test script to verify the reorganized structure works
"""

import sys
from pathlib import Path

# Add core to path
sys.path.insert(0, str(Path(__file__).parent / "core"))

try:
    print("Testing core module imports...")
    
    # Test infrastructure imports
    print("Testing infrastructure...")
    from core.infrastructure import setup_logging
    print("✅ Infrastructure imports working")
    
    # Test AI imports  
    print("Testing AI modules...")
    from core.ai import summary_types
    print("✅ AI imports working")
    
    # Test database imports
    print("Testing database...")
    from core.database import database_manager
    print("✅ Database imports working")
    
    print("\n🎉 All core modules import successfully!")
    print("The reorganized structure is working correctly!")

except Exception as e:
    print(f"❌ Import failed: {e}")
    import traceback
    traceback.print_exc()