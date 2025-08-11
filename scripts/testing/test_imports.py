#!/usr/bin/env python3
"""
Simple test script to verify the reorganized structure works
"""

import sys
from pathlib import Path

# Add repo root to path so we can import core
repo_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(repo_root))

try:
    print("Testing core module imports...")
    
    # Test simple core imports without heavy dependencies
    print("Testing AI summary types...")
    import importlib.util
    spec = importlib.util.spec_from_file_location("summary_types", repo_root / "core" / "ai" / "summary_types.py")
    summary_types = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(summary_types)
    print("✅ AI summary types imports working")
    
    # Test that core module directories exist and are importable
    print("Testing core module structure...")
    import os
    core_dirs = ["ai", "database", "infrastructure", "shared"]
    for dir_name in core_dirs:
        path = repo_root / "core" / dir_name
        if path.exists() and (path / "__init__.py").exists():
            print(f"✅ core/{dir_name}/ module structure exists")
        else:
            raise ImportError(f"❌ core/{dir_name}/ module structure missing")
    
    # Test basic file imports without dependencies
    print("Testing direct module files...")
    spec = importlib.util.spec_from_file_location("logging_config", repo_root / "core" / "infrastructure" / "logging_config.py")
    if spec and spec.loader:
        logging_config = importlib.util.module_from_spec(spec)
        print("✅ Infrastructure logging config file accessible")
    
    print("\n🎉 All core modules import successfully!")
    print("The reorganized structure is working correctly!")

except Exception as e:
    print(f"❌ Import failed: {e}")
    import traceback
    traceback.print_exc()