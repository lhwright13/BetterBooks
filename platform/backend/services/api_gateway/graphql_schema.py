#!/usr/bin/env python3
"""
GraphQL Schema for EchoWright Platform
Provides unified GraphQL interface over existing REST microservices
"""

import strawberry
from typing import List, Optional
from strawberry.fastapi import GraphQLRouter
import httpx
from datetime import datetime
import os

# Import existing models and utilities
from core.auth.jwt_middleware import get_current_user_verified
from core.shared.utils.config_manager import get_config

# Import security components
from graphql_security import (
    require_auth, 
    require_subscription, 
    security_extensions
)

app_config = get_config()

# GraphQL Types
@strawberry.type
class Book:
    id: str
    title: str
    author: str
    cover_image_url: str
    price_usd: float = 9.99
    credit_price: int = 1
    is_featured: bool = False
    is_bestseller: bool = False
    progress: float = 0.0

@strawberry.type
class User:
    id: str
    email: str
    first_name: str
    last_name: str
    subscription_tier: str = "free"
    credits_available: int = 0

@strawberry.type
class Chapter:
    id: str
    book_id: str
    chapter_number: int
    title: str
    start_time: float
    end_time: float
    duration: float

@strawberry.type
class AudioPlayback:
    book_id: str
    chapter_id: Optional[str]
    audio_url: str
    current_position: float = 0.0

# GraphQL Queries
@strawberry.type
class Query:
    
    @strawberry.field
    async def books(self, featured: bool = False, limit: int = 20) -> List[Book]:
        """Get list of available books"""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"http://localhost:8000/bookstore/browse",
                params={"featured": featured, "limit": limit}
            )
            data = response.json()
            return [Book(**book) for book in data.get("books", [])]
    
    @strawberry.field
    @require_auth  
    async def user_library(self, info: strawberry.Info) -> List[Book]:
        """Get user's purchased books (requires authentication)"""
        user_id = info.context["user_id"]
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "http://localhost:8000/bookstore/user/library",
                headers={"X-User-ID": user_id}
            )
            data = response.json()
            return [Book(**book) for book in data.get("books", [])]
    
    @strawberry.field
    @require_auth
    async def user_credits(self, info: strawberry.Info) -> int:
        """Get user's available credits (requires authentication)"""
        user_id = info.context["user_id"]
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "http://localhost:8000/bookstore/user/credits",
                headers={"X-User-ID": user_id}
            ) 
            data = response.json()
            return data.get("available_credits", 0)

    @strawberry.field
    async def book_chapters(self, book_id: str) -> List[Chapter]:
        """Get chapters for a specific book"""
        # This would integrate with your chapter detection service
        async with httpx.AsyncClient() as client:
            response = await client.get(f"http://localhost:8003/chapters/{book_id}")
            if response.status_code == 200:
                data = response.json()
                return [Chapter(**chapter) for chapter in data.get("chapters", [])]
        return []

# GraphQL Mutations
@strawberry.type
class Mutation:
    
    @strawberry.mutation
    @require_auth
    async def purchase_book(self, info: strawberry.Info, book_id: str, credits_to_use: int = 1) -> Book:
        """Purchase a book using credits (requires authentication)"""
        user_id = info.context["user_id"]
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"http://localhost:8000/bookstore/purchase",
                json={
                    "book_id": book_id, 
                    "credits_to_use": credits_to_use,
                    "user_id": user_id
                },
                headers={"X-User-ID": user_id}
            )
            data = response.json()
            return Book(**data.get("book", {}))
    
    @strawberry.mutation
    @require_auth
    async def update_playback_position(self, info: strawberry.Info, book_id: str, position: float) -> bool:
        """Update user's playback position (requires authentication)"""
        user_id = info.context["user_id"]
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"http://localhost:8000/playback/position",
                json={
                    "book_id": book_id, 
                    "position": position,
                    "user_id": user_id
                },
                headers={"X-User-ID": user_id}
            )
            return response.status_code == 200

# Create GraphQL schema with security extensions
schema = strawberry.Schema(
    query=Query, 
    mutation=Mutation,
    extensions=security_extensions
)

# Create FastAPI GraphQL router with production security settings
graphql_router = GraphQLRouter(
    schema,
    # Disable introspection in production
    introspection=os.getenv("ENVIRONMENT", "development") != "production",
    # Disable GraphQL playground in production  
    graphql_ide="graphiql" if os.getenv("ENVIRONMENT", "development") == "development" else None
)