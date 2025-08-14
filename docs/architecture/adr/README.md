# Architecture Decision Records (ADRs)

This directory contains the Architecture Decision Records for the BetterBooks platform. ADRs document significant architectural decisions made during the development of the system.

## What is an ADR?

An Architecture Decision Record (ADR) is a document that captures an important architectural decision made along with its context and consequences. ADRs help:
- Document the reasoning behind architectural choices
- Provide context for future developers
- Track the evolution of the system architecture
- Facilitate onboarding of new team members

## ADR Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [000](ADR-000-template.md) | ADR Template | Template | - |
| [001](ADR-001-microservices-architecture.md) | Microservices Architecture | Accepted | 2025-01-01 |
| [002](ADR-002-fastapi-framework.md) | FastAPI as Web Framework | Accepted | 2025-01-02 |
| [003](ADR-003-postgresql-pgvector.md) | PostgreSQL with pgvector for Embeddings | Accepted | 2025-01-03 |
| [004](ADR-004-redis-caching.md) | Redis for Caching and Session Management | Accepted | 2025-01-05 |

## How to Create a New ADR

1. Copy the template from `ADR-000-template.md`
2. Name it `ADR-XXX-brief-description.md` where XXX is the next number
3. Fill in all sections of the template
4. Update this README with the new ADR entry
5. Link related ADRs if applicable
6. Submit for review via pull request

## ADR Status Values

- **Proposed**: The decision is being discussed
- **Accepted**: The decision has been agreed upon and implemented
- **Deprecated**: The decision is no longer relevant but kept for historical context
- **Superseded**: The decision has been replaced by another ADR

## Categories

### Architecture Patterns
- [ADR-001](ADR-001-microservices-architecture.md): Microservices Architecture

### Technology Choices
- [ADR-002](ADR-002-fastapi-framework.md): FastAPI Framework
- [ADR-003](ADR-003-postgresql-pgvector.md): PostgreSQL with pgvector
- [ADR-004](ADR-004-redis-caching.md): Redis for Caching

## Contributing

When proposing architectural changes:
1. Create an ADR documenting the decision
2. Include all considered options
3. Clearly state the trade-offs
4. Get review from team members
5. Update status once decision is made

## Resources

- [Michael Nygard's ADR Introduction](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub Organization](https://adr.github.io/)
- [MADR Format](https://adr.github.io/madr/)