# GraphQL + Azure Backend Deployment Guide

## 🏗️ Architecture Overview

Your full stack now consists of:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Mobile App    │    │    Web Client    │    │  GraphQL Client │
│   (Flutter)     │    │   (React/Vue)    │    │   (Apollo/etc)  │
└─────────┬───────┘    └────────┬─────────┘    └─────────┬───────┘
          │                     │                        │
          └─────────────────────┼────────────────────────┘
                                │
                    ┌───────────▼────────────┐
                    │   Azure LoadBalancer   │
                    │  52.255.222.174:8000   │
                    └───────────┬────────────┘
                                │
                    ┌───────────▼────────────┐
                    │     API Gateway        │
                    │   ┌─────────────────┐  │
                    │   │   REST APIs     │  │  
                    │   │   /auth/*       │  │
                    │   │   /bookstore/*  │  │
                    │   └─────────────────┘  │
                    │   ┌─────────────────┐  │
                    │   │   GraphQL       │  │
                    │   │   /graphql      │  │
                    │   └─────────────────┘  │
                    └───────────┬────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌───────▼────────┐    ┌─────────▼─────────┐    ┌───────▼────────┐
│ Context Service│    │   LLM Gateway     │    │  TTS Service   │
│     :8001      │    │      :8002        │    │     :8004      │
└────────────────┘    └───────────────────┘    └────────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                    ┌───────────▼────────────┐
                    │   PostgreSQL+pgvector  │
                    │      (AKS managed)     │
                    └────────────────────────┘
```

## 🚀 Deployment Steps

### 1. Update Your Azure Deployment

```bash
# Navigate to your project
cd /Users/lhwri/BetterBooks

# Build and push updated API Gateway with GraphQL
./deployment/build-and-push.sh

# Deploy to Azure
kubectl apply -f config/kubernetes/
helm upgrade api-gateway config/helm/infra/helm/api_gateway --namespace betterbooks
```

### 2. Verify GraphQL Endpoint

Once deployed, your GraphQL endpoint will be available at:

**Production**: `http://52.255.222.174:8000/graphql`
**Local Dev**: `http://localhost:8000/graphql`

Test the GraphQL playground:
```bash
curl -X POST http://52.255.222.174:8000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ books { id title author } }"
  }'
```

### 3. GraphQL Schema Features

#### Available Queries:
```graphql
query {
  # Get available books
  books(featured: false, limit: 20) {
    id
    title  
    author
    cover_image_url
    price_usd
    credit_price
    is_featured
  }
  
  # Get user's library (requires auth)
  user_library {
    id
    title
    author
    progress
  }
  
  # Get user's credits (requires auth)
  user_credits
  
  # Get book chapters
  book_chapters(book_id: "gatsby-001") {
    id
    chapter_number
    title
    start_time
    end_time
    duration
  }
}
```

#### Available Mutations:
```graphql
mutation {
  # Purchase a book
  purchase_book(book_id: "gatsby-001", credits_to_use: 1) {
    id
    title
    author
  }
  
  # Update playback position
  update_playback_position(book_id: "gatsby-001", position: 120.5)
}
```

## 📱 Client Integration

### Option 1: Mobile App (Flutter) 

Add GraphQL client to your Flutter app:

```yaml
# pubspec.yaml
dependencies:
  graphql_flutter: ^5.1.0
```

```dart
// lib/services/graphql_service.dart
import 'package:graphql_flutter/graphql_flutter.dart';

class GraphQLService {
  static GraphQLClient client = GraphQLClient(
    link: HttpLink('http://52.255.222.174:8000/graphql'),
    cache: GraphQLCache(store: HiveStore()),
  );
  
  static Future<List<Book>> getBooks({bool featured = false}) async {
    const String query = '''
      query GetBooks(\$featured: Boolean!) {
        books(featured: \$featured) {
          id
          title
          author
          cover_image_url
          price_usd
        }
      }
    ''';
    
    final result = await client.query(
      QueryOptions(
        document: gql(query),
        variables: {'featured': featured},
      ),
    );
    
    if (result.hasException) throw result.exception!;
    return (result.data!['books'] as List)
        .map((b) => Book.fromJson(b))
        .toList();
  }
}
```

### Option 2: Web Frontend (React)

```bash
npm install @apollo/client graphql
```

```jsx
// src/apollo-client.js
import { ApolloClient, InMemoryCache, HttpLink } from '@apollo/client';

const client = new ApolloClient({
  link: new HttpLink({
    uri: 'http://52.255.222.174:8000/graphql'
  }),
  cache: new InMemoryCache()
});

export default client;
```

```jsx
// src/components/BooksList.jsx
import { useQuery, gql } from '@apollo/client';

const GET_BOOKS = gql`
  query GetBooks($featured: Boolean!) {
    books(featured: $featured) {
      id
      title
      author
      cover_image_url
      price_usd
    }
  }
`;

function BooksList({ featured = false }) {
  const { loading, error, data } = useQuery(GET_BOOKS, {
    variables: { featured }
  });

  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;

  return (
    <div>
      {data.books.map(book => (
        <div key={book.id}>
          <h3>{book.title}</h3>
          <p>by {book.author}</p>
          <p>${book.price_usd}</p>
        </div>
      ))}
    </div>
  );
}
```

## 🔧 Local Development

### Start with GraphQL:
```bash
# Start all services including GraphQL
docker-compose up --build

# GraphQL playground available at:
# http://localhost:8000/graphql
```

### Environment Variables:
```bash
# .env
GRAPHQL_ENABLED=true
GRAPHQL_PLAYGROUND=true  # Only in development
AZURE_BACKEND_URL=http://52.255.222.174:8000
```

## 🔒 Authentication Integration

The GraphQL layer automatically integrates with your existing JWT authentication:

```graphql
# Include Authorization header
{
  "Authorization": "Bearer your-jwt-token"
}

# Authenticated queries
query {
  user_library {
    id
    title
    progress
  }
  user_credits
}
```

## 📊 Monitoring & Performance

Your GraphQL endpoint includes:
- ✅ Query complexity analysis
- ✅ Rate limiting (inherited from API Gateway)
- ✅ Caching (Redis integration) 
- ✅ Metrics collection
- ✅ Error handling & logging

## 🎯 Next Steps

1. **Deploy Updated Backend**:
   ```bash
   ./deployment/build-and-push.sh
   helm upgrade api-gateway config/helm/infra/helm/api_gateway --namespace betterbooks
   ```

2. **Update Mobile App**:
   - Add GraphQL client dependencies
   - Replace REST calls with GraphQL queries
   - Test against `http://52.255.222.174:8000/graphql`

3. **Create Web Frontend** (optional):
   - React/Vue app with Apollo Client
   - Same GraphQL endpoint
   - Shared authentication with mobile

4. **Monitor Performance**:
   - Check GraphQL metrics at `/metrics`
   - Monitor query performance
   - Scale services as needed

Your GraphQL stack will now provide a unified, efficient API layer over your existing Azure microservices!