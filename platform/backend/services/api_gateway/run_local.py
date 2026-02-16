#!/usr/bin/env python3
import sys
import os
from pathlib import Path

current_dir = Path(__file__).parent
repo_root = current_dir.parents[3]
project_root = str(repo_root)

if project_root not in sys.path:
    sys.path.insert(0, project_root)

current_pythonpath = os.environ.get('PYTHONPATH', '')
new_paths = [project_root]
if current_pythonpath:
    new_paths.append(current_pythonpath)
os.environ['PYTHONPATH'] = ':'.join(new_paths)

print(f"Python path configured: {project_root}")

ENV_DEFAULTS = {
    'DATABASE_URL': 'postgresql://betterbooks:testpassword123@localhost:5432/betterbooks',
    'JWT_SECRET_KEY': 'test-secret-key-for-testing',
    'AZURE_OPENAI_API_KEY': 'test-key',
    'AZURE_OPENAI_ENDPOINT': 'https://your-resource.openai.azure.com/',
    'AZURE_OPENAI_DEPLOYMENT_NAME': 'gpt-4o-mini',
}

for key, default in ENV_DEFAULTS.items():
    if key not in os.environ:
        os.environ[key] = default

print("Starting API Gateway on port 8000...")
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
