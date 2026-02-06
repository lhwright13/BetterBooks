#!/usr/bin/env python3
"""
Local development startup script for API Gateway
Sets up proper PYTHONPATH and environment for local development
"""

import sys
import os
from pathlib import Path

# Add core modules to Python path
current_dir = Path(__file__).parent
repo_root = current_dir.parents[4]  # Navigate back to BetterBooks root
core_path = str(repo_root / "core")
project_root = str(repo_root)

# Add paths to Python path
if core_path not in sys.path:
    sys.path.insert(0, core_path)
if project_root not in sys.path:
    sys.path.insert(0, project_root)

# Set PYTHONPATH environment variable for subprocesses
current_pythonpath = os.environ.get('PYTHONPATH', '')
new_paths = [core_path, project_root]
if current_pythonpath:
    new_paths.append(current_pythonpath)
os.environ['PYTHONPATH'] = ':'.join(new_paths)

print(f"Python path configured: {project_root}")

# Set default environment variables for local development
if 'DATABASE_URL' not in os.environ:
    os.environ['DATABASE_URL'] = 'postgresql://betterbooks:testpassword123@localhost:5432/betterbooks'

if 'JWT_SECRET_KEY' not in os.environ:
    os.environ['JWT_SECRET_KEY'] = 'test-secret-key-for-testing'

if 'AZURE_OPENAI_API_KEY' not in os.environ:
    os.environ['AZURE_OPENAI_API_KEY'] = 'test-key'

if 'AZURE_OPENAI_ENDPOINT' not in os.environ:
    os.environ['AZURE_OPENAI_ENDPOINT'] = 'https://your-resource.openai.azure.com/'

if 'AZURE_OPENAI_DEPLOYMENT_NAME' not in os.environ:
    os.environ['AZURE_OPENAI_DEPLOYMENT_NAME'] = 'gpt-4o-mini'

# Import and run the main app
print("Starting API Gateway on port 8000...")
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
