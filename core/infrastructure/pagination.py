"""
Comprehensive pagination system for EchoWright APIs.

Provides standardized pagination across all services with support for:
- Cursor-based pagination for large datasets
- Offset-based pagination for simple use cases  
- Sorting and filtering integration
- Performance optimization
- Metadata and navigation links

Features:
- Multiple pagination strategies
- Configurable page size limits
- Automatic link generation
- Total count optimization
- Filter and search integration
"""

from typing import TypeVar, Generic, List, Optional, Dict, Any, Union, Callable
from dataclasses import dataclass, asdict
from enum import Enum
import math
import urllib.parse
from pydantic import BaseModel, Field, validator
from fastapi import Query, Request, HTTPException
import logging

logger = logging.getLogger(__name__)

T = TypeVar('T')


class PaginationType(Enum):
    """Pagination strategy types."""
    OFFSET = "offset"
    CURSOR = "cursor" 
    KEYSET = "keyset"


@dataclass
class PaginationMeta:
    """Pagination metadata."""
    current_page: int
    page_size: int
    total_items: Optional[int] = None
    total_pages: Optional[int] = None
    has_next: bool = False
    has_previous: bool = False
    next_cursor: Optional[str] = None
    previous_cursor: Optional[str] = None


@dataclass
class PaginationLinks:
    """Pagination navigation links."""
    self: str
    first: Optional[str] = None
    last: Optional[str] = None
    next: Optional[str] = None
    previous: Optional[str] = None


class PaginatedResponse(BaseModel, Generic[T]):
    """Standardized paginated response format."""
    
    data: List[T]
    meta: PaginationMeta
    links: Optional[PaginationLinks] = None
    
    class Config:
        arbitrary_types_allowed = True


class PaginationParams(BaseModel):
    """Standard pagination parameters."""
    
    page: int = Field(1, ge=1, description="Page number (1-based)")
    page_size: int = Field(20, ge=1, le=100, description="Items per page")
    cursor: Optional[str] = Field(None, description="Cursor for cursor-based pagination")
    sort_by: Optional[str] = Field(None, description="Field to sort by")
    sort_order: str = Field("asc", regex="^(asc|desc)$", description="Sort order")
    
    @validator('page_size')
    def validate_page_size(cls, v, values):
        """Validate page size limits."""
        max_size = 100
        if v > max_size:
            raise ValueError(f"Page size cannot exceed {max_size}")
        return v


class CursorPaginationParams(BaseModel):
    """Cursor-based pagination parameters."""
    
    cursor: Optional[str] = Field(None, description="Pagination cursor")
    limit: int = Field(20, ge=1, le=100, description="Number of items to return")
    sort_by: Optional[str] = Field(None, description="Field to sort by")
    sort_order: str = Field("asc", regex="^(asc|desc)$", description="Sort order")


class Paginator(Generic[T]):
    """
    Universal paginator supporting multiple pagination strategies.
    
    Supports offset-based and cursor-based pagination with automatic
    optimization and link generation.
    """
    
    def __init__(
        self,
        pagination_type: PaginationType = PaginationType.OFFSET,
        default_page_size: int = 20,
        max_page_size: int = 100,
        count_strategy: str = "auto"  # "auto", "exact", "estimate", "none"
    ):
        """
        Initialize paginator.
        
        Args:
            pagination_type: Type of pagination to use
            default_page_size: Default number of items per page
            max_page_size: Maximum allowed page size
            count_strategy: Strategy for counting total items
        """
        self.pagination_type = pagination_type
        self.default_page_size = default_page_size
        self.max_page_size = max_page_size
        self.count_strategy = count_strategy
    
    def paginate_query(
        self,
        query: Any,  # Database query object (e.g., SQLAlchemy Query)
        params: Union[PaginationParams, CursorPaginationParams],
        request: Optional[Request] = None,
        total_count: Optional[int] = None,
        cursor_field: str = "id"
    ) -> PaginatedResponse[T]:
        """
        Paginate a database query.
        
        Args:
            query: Database query to paginate
            params: Pagination parameters
            request: FastAPI request for link generation
            total_count: Pre-calculated total count (optional)
            cursor_field: Field to use for cursor-based pagination
            
        Returns:
            Paginated response with data, metadata, and links
        """
        if self.pagination_type == PaginationType.CURSOR:
            return self._paginate_cursor(query, params, request, cursor_field)
        else:
            return self._paginate_offset(query, params, request, total_count)
    
    def paginate_list(
        self,
        items: List[T],
        params: PaginationParams,
        request: Optional[Request] = None
    ) -> PaginatedResponse[T]:
        """
        Paginate an in-memory list.
        
        Args:
            items: List of items to paginate
            params: Pagination parameters
            request: FastAPI request for link generation
            
        Returns:
            Paginated response
        """
        total_items = len(items)
        offset = (params.page - 1) * params.page_size
        
        # Get page data
        page_data = items[offset:offset + params.page_size]
        
        # Calculate metadata
        total_pages = math.ceil(total_items / params.page_size) if total_items > 0 else 0
        has_next = offset + params.page_size < total_items
        has_previous = params.page > 1
        
        meta = PaginationMeta(
            current_page=params.page,
            page_size=params.page_size,
            total_items=total_items,
            total_pages=total_pages,
            has_next=has_next,
            has_previous=has_previous
        )
        
        # Generate links if request provided
        links = None
        if request:
            links = self._generate_links(request, params, meta)
        
        return PaginatedResponse(
            data=page_data,
            meta=meta,
            links=links
        )
    
    def _paginate_offset(
        self,
        query: Any,
        params: PaginationParams,
        request: Optional[Request],
        total_count: Optional[int]
    ) -> PaginatedResponse[T]:
        """Implement offset-based pagination."""
        # Calculate offset
        offset = (params.page - 1) * params.page_size
        
        # Apply sorting if specified
        if params.sort_by:
            if hasattr(query, 'order_by'):
                order_clause = getattr(query, params.sort_by, None)
                if order_clause:
                    if params.sort_order == "desc":
                        query = query.order_by(order_clause.desc())
                    else:
                        query = query.order_by(order_clause.asc())
        
        # Get total count if needed
        if total_count is None and self.count_strategy != "none":
            if hasattr(query, 'count'):
                try:
                    total_count = query.count()
                except Exception as e:
                    logger.warning(f"Failed to count query results: {e}")
                    total_count = None
        
        # Apply pagination to query
        if hasattr(query, 'offset') and hasattr(query, 'limit'):
            paginated_query = query.offset(offset).limit(params.page_size)
        else:
            # Fallback for list-like objects
            paginated_query = query[offset:offset + params.page_size]
        
        # Execute query to get results
        try:
            if hasattr(paginated_query, 'all'):
                results = paginated_query.all()
            elif hasattr(paginated_query, '__iter__'):
                results = list(paginated_query)
            else:
                results = []
        except Exception as e:
            logger.error(f"Failed to execute paginated query: {e}")
            raise HTTPException(status_code=500, detail="Failed to retrieve paginated results")
        
        # Calculate metadata
        total_pages = None
        if total_count is not None:
            total_pages = math.ceil(total_count / params.page_size) if total_count > 0 else 0
        
        has_next = len(results) == params.page_size
        has_previous = params.page > 1
        
        # If we got less than page_size results, we know there's no next page
        if len(results) < params.page_size:
            has_next = False
        
        meta = PaginationMeta(
            current_page=params.page,
            page_size=params.page_size,
            total_items=total_count,
            total_pages=total_pages,
            has_next=has_next,
            has_previous=has_previous
        )
        
        # Generate links
        links = None
        if request:
            links = self._generate_links(request, params, meta)
        
        return PaginatedResponse(
            data=results,
            meta=meta,
            links=links
        )
    
    def _paginate_cursor(
        self,
        query: Any,
        params: CursorPaginationParams,
        request: Optional[Request],
        cursor_field: str
    ) -> PaginatedResponse[T]:
        """Implement cursor-based pagination."""
        # Apply cursor filter if provided
        if params.cursor:
            try:
                cursor_value = self._decode_cursor(params.cursor)
                if hasattr(query, 'filter'):
                    # Assume greater than for forward pagination
                    cursor_column = getattr(query, cursor_field, None)
                    if cursor_column:
                        if params.sort_order == "desc":
                            query = query.filter(cursor_column < cursor_value)
                        else:
                            query = query.filter(cursor_column > cursor_value)
            except Exception as e:
                logger.warning(f"Failed to apply cursor filter: {e}")
        
        # Apply sorting
        if hasattr(query, 'order_by') and cursor_field:
            cursor_column = getattr(query, cursor_field, None)
            if cursor_column:
                if params.sort_order == "desc":
                    query = query.order_by(cursor_column.desc())
                else:
                    query = query.order_by(cursor_column.asc())
        
        # Get one extra item to check if there's a next page
        limit = params.limit + 1
        if hasattr(query, 'limit'):
            paginated_query = query.limit(limit)
        else:
            paginated_query = query[:limit]
        
        # Execute query
        try:
            if hasattr(paginated_query, 'all'):
                results = paginated_query.all()
            else:
                results = list(paginated_query)
        except Exception as e:
            logger.error(f"Failed to execute cursor-paginated query: {e}")
            raise HTTPException(status_code=500, detail="Failed to retrieve results")
        
        # Check if there's a next page
        has_next = len(results) > params.limit
        if has_next:
            results = results[:-1]  # Remove the extra item
        
        # Generate cursors
        next_cursor = None
        previous_cursor = None
        
        if has_next and results:
            last_item = results[-1]
            next_cursor = self._encode_cursor(getattr(last_item, cursor_field, None))
        
        if params.cursor:
            # For simplicity, we'll use the current cursor as previous
            # In a real implementation, you'd need to track cursor history
            previous_cursor = params.cursor
        
        meta = PaginationMeta(
            current_page=1,  # Cursor pagination doesn't have traditional pages
            page_size=params.limit,
            has_next=has_next,
            has_previous=bool(params.cursor),
            next_cursor=next_cursor,
            previous_cursor=previous_cursor
        )
        
        return PaginatedResponse(
            data=results,
            meta=meta,
            links=None  # Cursor pagination uses cursors instead of links
        )
    
    def _generate_links(
        self,
        request: Request,
        params: PaginationParams,
        meta: PaginationMeta
    ) -> PaginationLinks:
        """Generate pagination navigation links."""
        base_url = str(request.url).split('?')[0]
        query_params = dict(request.query_params)
        
        # Current page link
        current_params = query_params.copy()
        current_params['page'] = str(params.page)
        current_params['page_size'] = str(params.page_size)
        self_link = f"{base_url}?{urllib.parse.urlencode(current_params)}"
        
        # First page link
        first_params = query_params.copy()
        first_params['page'] = '1'
        first_params['page_size'] = str(params.page_size)
        first_link = f"{base_url}?{urllib.parse.urlencode(first_params)}"
        
        # Next page link
        next_link = None
        if meta.has_next:
            next_params = query_params.copy()
            next_params['page'] = str(params.page + 1)
            next_params['page_size'] = str(params.page_size)
            next_link = f"{base_url}?{urllib.parse.urlencode(next_params)}"
        
        # Previous page link
        previous_link = None
        if meta.has_previous:
            prev_params = query_params.copy()
            prev_params['page'] = str(max(1, params.page - 1))
            prev_params['page_size'] = str(params.page_size)
            previous_link = f"{base_url}?{urllib.parse.urlencode(prev_params)}"
        
        # Last page link
        last_link = None
        if meta.total_pages and meta.total_pages > 1:
            last_params = query_params.copy()
            last_params['page'] = str(meta.total_pages)
            last_params['page_size'] = str(params.page_size)
            last_link = f"{base_url}?{urllib.parse.urlencode(last_params)}"
        
        return PaginationLinks(
            self=self_link,
            first=first_link,
            last=last_link,
            next=next_link,
            previous=previous_link
        )
    
    def _encode_cursor(self, value: Any) -> str:
        """Encode cursor value for URL."""
        import base64
        import json
        
        try:
            cursor_data = json.dumps(value, default=str)
            encoded = base64.urlsafe_b64encode(cursor_data.encode()).decode()
            return encoded
        except Exception as e:
            logger.error(f"Failed to encode cursor: {e}")
            return ""
    
    def _decode_cursor(self, cursor: str) -> Any:
        """Decode cursor value from URL."""
        import base64
        import json
        
        try:
            decoded_bytes = base64.urlsafe_b64decode(cursor.encode())
            cursor_data = json.loads(decoded_bytes.decode())
            return cursor_data
        except Exception as e:
            logger.error(f"Failed to decode cursor: {e}")
            raise HTTPException(status_code=400, detail="Invalid cursor format")


# FastAPI dependency functions

def get_pagination_params(
    page: int = Query(1, ge=1, description="Page number (1-based)"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    sort_by: Optional[str] = Query(None, description="Field to sort by"),
    sort_order: str = Query("asc", regex="^(asc|desc)$", description="Sort order")
) -> PaginationParams:
    """FastAPI dependency for pagination parameters."""
    return PaginationParams(
        page=page,
        page_size=page_size,
        sort_by=sort_by,
        sort_order=sort_order
    )


def get_cursor_pagination_params(
    cursor: Optional[str] = Query(None, description="Pagination cursor"),
    limit: int = Query(20, ge=1, le=100, description="Number of items"),
    sort_by: Optional[str] = Query(None, description="Field to sort by"),
    sort_order: str = Query("asc", regex="^(asc|desc)$", description="Sort order")
) -> CursorPaginationParams:
    """FastAPI dependency for cursor pagination parameters."""
    return CursorPaginationParams(
        cursor=cursor,
        limit=limit,
        sort_by=sort_by,
        sort_order=sort_order
    )


# Utility functions

def create_paginator(
    pagination_type: PaginationType = PaginationType.OFFSET,
    default_page_size: int = 20,
    max_page_size: int = 100
) -> Paginator:
    """Create a paginator instance with default settings."""
    return Paginator(
        pagination_type=pagination_type,
        default_page_size=default_page_size,
        max_page_size=max_page_size
    )


def paginate_results(
    items: List[T],
    page: int = 1,
    page_size: int = 20,
    request: Optional[Request] = None
) -> PaginatedResponse[T]:
    """Quick function to paginate a list of items."""
    paginator = create_paginator()
    params = PaginationParams(page=page, page_size=page_size)
    return paginator.paginate_list(items, params, request)