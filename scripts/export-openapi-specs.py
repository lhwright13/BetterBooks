#!/usr/bin/env python3
"""
Export OpenAPI specifications from all FastAPI services.

This script connects to each running service and exports their OpenAPI
specifications to JSON and YAML files for documentation and client generation.

Usage:
    python scripts/export-openapi-specs.py
    
The script will create an 'api-docs' directory with specifications for each service.
"""

import json
import os
import sys
from pathlib import Path
import requests
import yaml
from typing import Dict, Any

# Service endpoints
SERVICES = {
    "api_gateway": {
        "url": "http://localhost:8000",
        "name": "API Gateway",
        "description": "Central API gateway for BetterBooks platform"
    },
    "context_service": {
        "url": "http://localhost:8001", 
        "name": "Context Service",
        "description": "Vector embeddings and similarity search"
    },
    "llm_gateway": {
        "url": "http://localhost:8002",
        "name": "LLM Gateway",
        "description": "AI text generation and persona management"
    },
    "tts_service": {
        "url": "http://localhost:8004",
        "name": "TTS Service",
        "description": "Text-to-speech synthesis"
    },
    "transcription_service": {
        "url": "http://localhost:8003",
        "name": "Transcription Service",
        "description": "Audio transcription and chapter detection"
    }
}

def fetch_openapi_spec(service_url: str) -> Dict[str, Any]:
    """Fetch OpenAPI specification from a service."""
    try:
        response = requests.get(f"{service_url}/openapi.json", timeout=5)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"  ❌ Failed to fetch spec: {e}")
        return None

def enhance_spec(spec: Dict[str, Any], service_info: Dict[str, str]) -> Dict[str, Any]:
    """Enhance OpenAPI spec with additional information."""
    if not spec:
        return None
    
    # Add/update top-level information
    spec["info"]["title"] = service_info["name"]
    spec["info"]["description"] = service_info["description"]
    spec["info"]["contact"] = {
        "name": "BetterBooks Team",
        "email": "support@betterbooks.com"
    }
    spec["info"]["license"] = {
        "name": "MIT",
        "url": "https://opensource.org/licenses/MIT"
    }
    
    # Add server information
    spec["servers"] = [
        {
            "url": service_info["url"],
            "description": "Local development server"
        },
        {
            "url": f"https://api.betterbooks.com/{service_info['url'].split(':')[-1]}",
            "description": "Production server"
        }
    ]
    
    # Add security schemes if not present
    if "components" not in spec:
        spec["components"] = {}
    
    if "securitySchemes" not in spec["components"]:
        spec["components"]["securitySchemes"] = {
            "bearerAuth": {
                "type": "http",
                "scheme": "bearer",
                "bearerFormat": "JWT",
                "description": "JWT authentication token"
            },
            "apiKey": {
                "type": "apiKey",
                "in": "header",
                "name": "X-API-Key",
                "description": "API key authentication"
            }
        }
    
    # Add tags for better organization
    if "tags" not in spec:
        spec["tags"] = []
    
    # Add external documentation
    spec["externalDocs"] = {
        "description": "BetterBooks API Documentation",
        "url": "https://docs.betterbooks.com"
    }
    
    return spec

def save_spec(spec: Dict[str, Any], service_name: str, output_dir: Path):
    """Save OpenAPI spec to JSON and YAML files."""
    if not spec:
        return
    
    # Save as JSON
    json_file = output_dir / f"{service_name}.openapi.json"
    with open(json_file, 'w') as f:
        json.dump(spec, f, indent=2)
    print(f"  ✅ Saved JSON: {json_file}")
    
    # Save as YAML
    yaml_file = output_dir / f"{service_name}.openapi.yaml"
    with open(yaml_file, 'w') as f:
        yaml.dump(spec, f, default_flow_style=False, sort_keys=False)
    print(f"  ✅ Saved YAML: {yaml_file}")

def generate_combined_spec(specs: Dict[str, Dict[str, Any]], output_dir: Path):
    """Generate a combined OpenAPI spec for all services."""
    combined = {
        "openapi": "3.0.2",
        "info": {
            "title": "BetterBooks Platform API",
            "description": "Complete API documentation for the BetterBooks audiobook platform",
            "version": "1.0.0",
            "contact": {
                "name": "BetterBooks Team",
                "email": "support@betterbooks.com"
            },
            "license": {
                "name": "MIT",
                "url": "https://opensource.org/licenses/MIT"
            }
        },
        "servers": [
            {
                "url": "http://localhost:8000",
                "description": "Local API Gateway"
            },
            {
                "url": "https://api.betterbooks.com",
                "description": "Production API Gateway"
            }
        ],
        "paths": {},
        "components": {
            "schemas": {},
            "securitySchemes": {
                "bearerAuth": {
                    "type": "http",
                    "scheme": "bearer",
                    "bearerFormat": "JWT"
                }
            }
        },
        "tags": []
    }
    
    # Combine paths and schemas from all services
    for service_name, spec in specs.items():
        if not spec:
            continue
            
        # Add service tag
        combined["tags"].append({
            "name": service_name,
            "description": SERVICES[service_name]["description"]
        })
        
        # Add paths with service prefix
        if "paths" in spec:
            for path, path_info in spec["paths"].items():
                # Add service tag to all operations
                for method in path_info:
                    if isinstance(path_info[method], dict):
                        if "tags" not in path_info[method]:
                            path_info[method]["tags"] = []
                        path_info[method]["tags"].append(service_name)
                
                # Add prefixed path
                prefixed_path = f"/{service_name}{path}" if path != "/" else f"/{service_name}"
                combined["paths"][prefixed_path] = path_info
        
        # Merge schemas
        if "components" in spec and "schemas" in spec["components"]:
            for schema_name, schema_def in spec["components"]["schemas"].items():
                # Prefix schema name to avoid conflicts
                prefixed_name = f"{service_name}_{schema_name}"
                combined["components"]["schemas"][prefixed_name] = schema_def
    
    # Save combined spec
    save_spec(combined, "combined", output_dir)
    
def generate_markdown_docs(specs: Dict[str, Dict[str, Any]], output_dir: Path):
    """Generate markdown documentation from OpenAPI specs."""
    md_file = output_dir / "API_DOCUMENTATION.md"
    
    with open(md_file, 'w') as f:
        f.write("# BetterBooks API Documentation\n\n")
        f.write("Complete API documentation for the BetterBooks audiobook platform.\n\n")
        f.write("## Services\n\n")
        
        for service_name, spec in specs.items():
            if not spec:
                continue
                
            service_info = SERVICES[service_name]
            f.write(f"### {service_info['name']}\n\n")
            f.write(f"{service_info['description']}\n\n")
            f.write(f"- **Base URL**: `{service_info['url']}`\n")
            f.write(f"- **Version**: {spec['info'].get('version', '1.0.0')}\n")
            f.write(f"- **OpenAPI Spec**: [{service_name}.openapi.json]({service_name}.openapi.json)\n\n")
            
            # List endpoints
            if "paths" in spec:
                f.write("#### Endpoints\n\n")
                for path, methods in spec["paths"].items():
                    for method, details in methods.items():
                        if isinstance(details, dict):
                            summary = details.get('summary', 'No summary')
                            f.write(f"- `{method.upper()} {path}` - {summary}\n")
                f.write("\n")
        
        # Add usage examples
        f.write("## Usage Examples\n\n")
        f.write("### Authentication\n\n")
        f.write("```bash\n")
        f.write("# Get authentication token\n")
        f.write("curl -X POST http://localhost:8000/auth/login \\\n")
        f.write("  -H 'Content-Type: application/json' \\\n")
        f.write("  -d '{\"username\": \"user\", \"password\": \"pass\"}'\n")
        f.write("```\n\n")
        
        f.write("### Making API Calls\n\n")
        f.write("```bash\n")
        f.write("# Call LLM completion endpoint\n")
        f.write("curl -X POST http://localhost:8000/complete \\\n")
        f.write("  -H 'Authorization: Bearer YOUR_TOKEN' \\\n")
        f.write("  -H 'Content-Type: application/json' \\\n")
        f.write("  -d '{\"prompt\": \"Tell me about The Great Gatsby\"}'\n")
        f.write("```\n\n")
        
        f.write("## Client SDK Generation\n\n")
        f.write("You can generate client SDKs from the OpenAPI specifications:\n\n")
        f.write("```bash\n")
        f.write("# Generate Python client\n")
        f.write("openapi-generator generate -i combined.openapi.json -g python -o ./sdk/python\n\n")
        f.write("# Generate TypeScript client\n")
        f.write("openapi-generator generate -i combined.openapi.json -g typescript-axios -o ./sdk/typescript\n")
        f.write("```\n")
    
    print(f"  ✅ Generated markdown docs: {md_file}")

def main():
    """Main function to export all OpenAPI specifications."""
    print("🚀 Exporting OpenAPI specifications for BetterBooks services\n")
    
    # Create output directory
    output_dir = Path("api-docs")
    output_dir.mkdir(exist_ok=True)
    print(f"📁 Output directory: {output_dir}\n")
    
    # Check if services are running
    print("🔍 Checking service availability...\n")
    
    all_specs = {}
    
    for service_name, service_info in SERVICES.items():
        print(f"📡 {service_info['name']} ({service_info['url']})")
        
        # Fetch OpenAPI spec
        spec = fetch_openapi_spec(service_info["url"])
        
        if spec:
            # Enhance spec with additional information
            spec = enhance_spec(spec, service_info)
            
            # Save individual spec
            save_spec(spec, service_name, output_dir)
            
            all_specs[service_name] = spec
        else:
            print(f"  ⚠️  Skipping {service_name} - service not available")
        
        print()
    
    if all_specs:
        print("📝 Generating combined documentation...\n")
        generate_combined_spec(all_specs, output_dir)
        generate_markdown_docs(all_specs, output_dir)
        
        print("\n✨ Export complete! Check the 'api-docs' directory for:")
        print("  - Individual service OpenAPI specs (JSON and YAML)")
        print("  - Combined platform API spec")
        print("  - Markdown documentation")
        print("\n💡 To view interactive docs, run services and visit:")
        print("  - http://localhost:8000/docs (API Gateway)")
        print("  - http://localhost:8001/docs (Context Service)")
        print("  - http://localhost:8002/docs (LLM Gateway)")
        print("  - http://localhost:8004/docs (TTS Service)")
    else:
        print("❌ No services are running. Please start services with:")
        print("  docker-compose up")
        sys.exit(1)

if __name__ == "__main__":
    main()