# API Versioning Strategy

## Overview
This document outlines the API versioning strategy for the BetterBooks platform, ensuring backward compatibility while enabling evolution of our services.

## Versioning Approach

### URL Path Versioning
We use URL path versioning as our primary strategy:
```
https://api.betterbooks.com/v1/complete
https://api.betterbooks.com/v1/context/search
https://api.betterbooks.com/v2/complete  # Future version
```

### Version Format
- **Format**: `v{major}` (e.g., v1, v2, v3)
- **Current Version**: v1 (implicit, no version prefix means v1)
- **Default Version**: Latest stable version

## Version Lifecycle

### Version States
1. **Development**: Active development, breaking changes allowed
2. **Stable**: Production-ready, no breaking changes
3. **Deprecated**: Legacy version, maintenance mode only
4. **Sunset**: Version will be removed, migration required

### Support Timeline
- **Current Version**: Full support with new features
- **Previous Version**: Security fixes and critical bugs only (12 months)
- **Deprecated Versions**: Security fixes only (6 months)
- **Sunset Notice**: 6 months advance notice before removal

## Breaking vs Non-Breaking Changes

### Non-Breaking Changes (Patch/Minor)
- Adding new endpoints
- Adding optional request fields
- Adding response fields
- Improving error messages
- Performance improvements
- Adding new HTTP methods to existing endpoints

### Breaking Changes (Major)
- Removing endpoints
- Removing request/response fields
- Changing field types
- Changing required fields
- Modifying error response structure
- Authentication changes

## API Versioning Implementation

### FastAPI Service Configuration
Each service should be configured with version information:

```python
from fastapi import FastAPI

# Version 1 (default)
app = FastAPI(
    title="BetterBooks API Gateway",
    description="Central API gateway for BetterBooks platform",
    version="1.0.0",
    openapi_url="/v1/openapi.json",
    docs_url="/v1/docs",
    redoc_url="/v1/redoc"
)

# Future version 2
app_v2 = FastAPI(
    title="BetterBooks API Gateway v2",
    version="2.0.0", 
    openapi_url="/v2/openapi.json",
    docs_url="/v2/docs",
    redoc_url="/v2/redoc"
)
```

### URL Structure
```
/v1/complete           # LLM completion
/v1/context/search     # Context search
/v1/tts/synthesize     # Text-to-speech
/v1/books/{id}         # Book operations
/v1/health             # Health checks
```

### Headers
Support version specification via headers as alternative:
```
Accept: application/json; version=1
API-Version: 1
```

## Client SDK Versioning

### SDK Structure
```
sdk/
├── python/
│   ├── v1/
│   │   └── betterbooks_client/
│   └── v2/
│       └── betterbooks_client/
├── typescript/
│   ├── v1/
│   └── v2/
└── README.md
```

### SDK Installation
```bash
# Python - specific version
pip install betterbooks-client==1.0.0

# TypeScript - specific version  
npm install @betterbooks/client@^1.0.0
```

## Migration Strategy

### Version Migration Process
1. **Announce New Version**: 3 months before release
2. **Beta Release**: Allow early testing
3. **Stable Release**: Full production support
4. **Deprecation Notice**: Mark old version as deprecated
5. **Sunset Warning**: 6 months notice before removal
6. **Version Removal**: Remove deprecated version

### Client Migration Guide
For each major version, provide:
- Migration guide with code examples
- Automated migration tools when possible
- Side-by-side comparison documentation
- Timeline for migration

### Example Migration (v1 → v2)
```python
# v1 API call
response = client.complete({
    "prompt": "Hello world",
    "config": "default"
})

# v2 API call (hypothetical)
response = client.generate({
    "messages": [{"role": "user", "content": "Hello world"}],
    "persona": "default"
})
```

## Documentation Strategy

### Version-Specific Documentation
- Each version maintains its own OpenAPI spec
- Separate documentation sites for each major version
- Clear version indicators on all documentation pages

### Documentation URLs
```
https://docs.betterbooks.com/v1/          # Current version
https://docs.betterbooks.com/v2/          # Future version
https://docs.betterbooks.com/migration/   # Migration guides
```

### OpenAPI Specifications
```
/v1/openapi.json    # Version 1 spec
/v2/openapi.json    # Version 2 spec  
/openapi.json       # Latest version (redirect)
```

## Error Handling

### Version-Specific Errors
```json
{
  "error": {
    "code": "UNSUPPORTED_VERSION",
    "message": "API version v3 is not supported",
    "supported_versions": ["v1", "v2"],
    "migration_guide": "https://docs.betterbooks.com/migration/v2-to-v3"
  }
}
```

### Deprecation Warnings
```json
{
  "data": { ... },
  "warnings": [
    {
      "code": "VERSION_DEPRECATED",
      "message": "API version v1 will be sunset on 2025-12-01",
      "migration_guide": "https://docs.betterbooks.com/migration/v1-to-v2"
    }
  ]
}
```

## Monitoring and Analytics

### Version Usage Metrics
Track API version usage to guide deprecation timeline:
- Requests per version
- Active clients per version  
- Error rates by version
- Response times by version

### Deprecation Metrics
Monitor deprecation adoption:
- Migration completion rate
- Time to migrate for clients
- Support tickets by version

## Content Negotiation

### Accept Headers
```
Accept: application/json                    # Latest version
Accept: application/json; version=1        # Specific version
Accept: application/vnd.betterbooks.v1+json  # Vendor-specific
```

### Response Headers
```
Content-Type: application/json
API-Version: 1
Deprecation: true
Sunset: Wed, 01 Dec 2025 00:00:00 GMT
Link: <https://docs.betterbooks.com/migration/>; rel="migration"
```

## Service-Specific Considerations

### API Gateway
- Routes versioned requests to appropriate service versions
- Handles version negotiation
- Provides version compatibility layer

### Individual Services
- Each service can evolve independently
- Internal service communication may use different versioning
- Services expose version information in health checks

## Testing Strategy

### Version Compatibility Tests
- Automated tests for each supported version
- Integration tests across version boundaries
- Migration tests to validate upgrade paths

### Regression Testing
- Ensure new versions don't break existing functionality
- Test version negotiation and fallback behavior
- Validate error responses for unsupported versions

## Rollback Strategy

### Version Rollback Scenarios
1. **Critical Bug in New Version**: Temporarily disable new version
2. **Performance Issues**: Route traffic back to stable version
3. **Client Compatibility**: Extend support for older version

### Rollback Procedures
```bash
# Disable v2 in API Gateway
kubectl patch configmap api-gateway-config \
  --patch '{"data":{"supported_versions":"v1"}}'

# Route all traffic to v1
kubectl patch ingress api-gateway \
  --patch '{"spec":{"rules":[{"http":{"paths":[{"path":"/v2","backend":null}]}}]}}'
```

## Related Documents
- [API Gateway Implementation](../../platform/backend/services/api_gateway/main.py)
- [OpenAPI Export Script](../../scripts/export-openapi-specs.py)
- [Client SDK Documentation](../clients/)
- [Deployment Procedures](../setup/DEPLOYMENT_CHECKLIST.md)