from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List


@dataclass
class ContextResult:
    text: str
    token_estimate: int
    chapters_included: List[int]
    current_chapter: int
    current_timestamp: float
    truncated: bool
    retrieval_method: str


class IContextRetriever(ABC):

    @abstractmethod
    async def get_context(
        self,
        book_id: str,
        chapter: int,
        timestamp_seconds: float,
        max_tokens: int = 16000
    ) -> ContextResult:
        pass

    @abstractmethod
    async def get_chapter_count(self, book_id: str) -> int:
        pass

    @abstractmethod
    async def has_transcript(self, book_id: str) -> bool:
        pass
