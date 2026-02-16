import sys
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

import pytest

PROJECT_ROOT = Path(__file__).parent.parent.parent
API_GATEWAY_PATH = PROJECT_ROOT / "platform" / "backend" / "services" / "api_gateway"
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(API_GATEWAY_PATH))


class MockCursor:

    def __init__(self, fetchone_result=None, fetchall_result=None):
        self.fetchone_result = fetchone_result
        self.fetchall_result = fetchall_result or []
        self.execute_calls = []
        self.rowcount = 1

    def execute(self, query, params=None):
        self.execute_calls.append((query, params))

    def fetchone(self):
        return self.fetchone_result

    def fetchall(self):
        return self.fetchall_result

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass


class MockConnection:

    def __init__(self, cursor):
        self._cursor = cursor

    def cursor(self, cursor_factory=None):
        return self._cursor

    def commit(self):
        pass

    def rollback(self):
        pass

    def close(self):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass


def create_mock_db(fetchone_result=None, fetchall_result=None):
    cursor = MockCursor(fetchone_result, fetchall_result)
    conn = MockConnection(cursor)
    return conn, cursor


class TestGetUserById:

    def test_get_user_by_id_found(self, sample_user_data):
        mock_conn, mock_cursor = create_mock_db(fetchone_result=sample_user_data)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_user_by_id

                result = get_user_by_id("user_12345")

                assert result is not None
                assert result["id"] == "user_12345"
                assert result["email"] == "testuser@example.com"

    def test_get_user_by_id_not_found(self):
        mock_conn, mock_cursor = create_mock_db(fetchone_result=None)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_user_by_id

                result = get_user_by_id("nonexistent_user")

                assert result is None

    def test_get_user_by_id_db_error(self):
        with patch("db_utils.get_db_connection") as mock_get_conn:
            mock_get_conn.side_effect = Exception("Database connection failed")

            with patch("db_utils.storage"):
                from db_utils import get_user_by_id

                result = get_user_by_id("user_12345")

                assert result is None


class TestGetUserCredits:

    def test_get_user_credits_existing(self, sample_user_credits):
        mock_conn, mock_cursor = create_mock_db(fetchone_result=sample_user_credits)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_user_credits

                result = get_user_credits("user_12345")

                assert result is not None
                assert result["total_credits"] == 10
                assert result["used_credits"] == 3
                assert result["available_credits"] == 7

    def test_get_user_credits_new_user(self):
        new_credits = {"total_credits": 5, "used_credits": 0, "available_credits": 5}

        mock_cursor = MockCursor()
        mock_cursor.fetchone_result = None

        call_count = [0]

        def fetchone_side_effect():
            call_count[0] += 1
            if call_count[0] == 1:
                return None
            return new_credits

        mock_cursor.fetchone = fetchone_side_effect

        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_user_credits

                result = get_user_credits("new_user")

                assert result is not None
                assert "total_credits" in result

    def test_get_user_credits_db_error_returns_fallback(self):
        with patch("db_utils.get_db_connection") as mock_get_conn:
            import psycopg2
            mock_get_conn.side_effect = psycopg2.Error("Connection failed")

            with patch("db_utils.storage"):
                from db_utils import get_user_credits

                result = get_user_credits("user_12345")

                assert result is not None
                assert result["total_credits"] == 5
                assert result["available_credits"] == 5


class TestGetUserLibrary:

    def test_get_user_library_with_books(self, sample_user_library):
        books = sample_user_library["books"]
        mock_conn, mock_cursor = create_mock_db(fetchall_result=books)

        mock_cursor.fetchone_result = {"count": len(books)}

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_user_library

                result = get_user_library("user_12345")

                assert "books" in result
                assert "total_books" in result

    def test_get_user_library_empty(self):
        mock_conn, mock_cursor = create_mock_db(fetchall_result=[], fetchone_result={"count": 0})

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_user_library

                result = get_user_library("user_no_books")

                assert result["books"] == []
                assert result["total_books"] == 0

    def test_get_user_library_db_error(self):
        with patch("db_utils.get_db_connection") as mock_get_conn:
            mock_get_conn.side_effect = Exception("Database error")

            with patch("db_utils.storage"):
                from db_utils import get_user_library

                result = get_user_library("user_12345")

                assert result["books"] == []
                assert result["total_books"] == 0


class TestCreateUser:

    def test_create_user_success(self):
        mock_cursor = MockCursor(fetchone_result={"id": "new_user_123"})
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import create_user

                result = create_user("newuser@example.com", "New User")

                assert result == "new_user_123"
                assert any("INSERT INTO users" in call[0] for call in mock_cursor.execute_calls)

    def test_create_user_db_error(self):
        with patch("db_utils.get_db_connection") as mock_get_conn:
            mock_get_conn.side_effect = Exception("Database error")

            with patch("db_utils.storage"):
                from db_utils import create_user

                result = create_user("newuser@example.com", "New User")

                assert result is None


class TestCreatePurchase:

    def test_create_purchase_success(self):
        mock_cursor = MockCursor()

        results = [
            None,
            {"available_credits": 5},
            {"price_usd": 9.99}
        ]
        call_count = [0]

        def fetchone_side_effect():
            if call_count[0] < len(results):
                result = results[call_count[0]]
                call_count[0] += 1
                return result
            return None

        mock_cursor.fetchone = fetchone_side_effect
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import create_purchase

                result = create_purchase("user_123", "book_456", credits_used=1)

                assert result is True

    def test_create_purchase_already_owned(self):
        mock_cursor = MockCursor(fetchone_result={"id": "existing_purchase"})
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import create_purchase

                result = create_purchase("user_123", "book_456")

                assert result is False

    def test_create_purchase_insufficient_credits(self):
        mock_cursor = MockCursor()

        results = [
            None,
            {"available_credits": 0}
        ]
        call_count = [0]

        def fetchone_side_effect():
            if call_count[0] < len(results):
                result = results[call_count[0]]
                call_count[0] += 1
                return result
            return None

        mock_cursor.fetchone = fetchone_side_effect
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import create_purchase

                result = create_purchase("user_123", "book_456", credits_used=1)

                assert result is False


class TestCheckUserOwnsBook:

    def test_check_user_owns_book_true(self):
        mock_cursor = MockCursor(fetchone_result=(1,))
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import check_user_owns_book

                result = check_user_owns_book("user_123", "book_456")

                assert result is True

    def test_check_user_owns_book_false(self):
        mock_cursor = MockCursor(fetchone_result=None)
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import check_user_owns_book

                result = check_user_owns_book("user_123", "book_456")

                assert result is False


class TestGetBrowseBooks:

    def test_get_browse_books(self, sample_books_list):
        mock_cursor = MockCursor(
            fetchall_result=sample_books_list,
            fetchone_result={"count": len(sample_books_list)}
        )
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_browse_books

                result = get_browse_books()

                assert "books" in result
                assert "total_books" in result

    def test_get_browse_books_featured_only(self, sample_books_list):
        featured = [b for b in sample_books_list if b.get("is_featured")]
        mock_cursor = MockCursor(
            fetchall_result=featured,
            fetchone_result={"count": len(featured)}
        )
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_browse_books

                result = get_browse_books(featured_only=True)

                assert "books" in result

    def test_get_browse_books_db_error(self):
        with patch("db_utils.get_db_connection") as mock_get_conn:
            mock_get_conn.side_effect = Exception("Database error")

            with patch("db_utils.storage"):
                from db_utils import get_browse_books

                result = get_browse_books()

                assert result["books"] == []
                assert result["total_books"] == 0


class TestGetBookDetails:

    def test_get_book_details_found(self, sample_book_data):
        chapters = [
            {"id": "ch1", "title": "Chapter 1", "chapter_number": 1, "duration": 300, "file_path": "gatsby/ch1.mp3"}
        ]

        mock_cursor = MockCursor()
        call_count = [0]

        def fetchone_side_effect():
            if call_count[0] == 0:
                call_count[0] += 1
                return sample_book_data
            return None

        def fetchall_side_effect():
            return chapters

        mock_cursor.fetchone = fetchone_side_effect
        mock_cursor.fetchall = fetchall_side_effect
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage") as mock_storage:
                mock_storage.generate_audio_url.return_value = "https://storage.example.com/audio.mp3"

                from db_utils import get_book_details

                result = get_book_details("book_gatsby_001")

                assert result is not None
                assert result["title"] == "The Great Gatsby"

    def test_get_book_details_not_found(self):
        mock_cursor = MockCursor(fetchone_result=None)
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_book_details

                result = get_book_details("nonexistent_book")

                assert result is None


class TestProgressTracking:

    def test_save_user_reading_progress_success(self):
        mock_cursor = MockCursor()
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import save_user_reading_progress

                result = save_user_reading_progress("user_123", "book_456", 1200.5)

                assert result is True
                assert any("INSERT INTO user_reading_progress" in str(call) for call in mock_cursor.execute_calls)

    def test_get_user_reading_progress_found(self, sample_reading_progress):
        mock_cursor = MockCursor(fetchone_result=sample_reading_progress)
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_user_reading_progress

                result = get_user_reading_progress("user_12345", "book_gatsby_001")

                assert result is not None
                assert result["current_position_seconds"] == 1200

    def test_get_user_reading_progress_not_found(self):
        mock_cursor = MockCursor(fetchone_result=None)
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_user_reading_progress

                result = get_user_reading_progress("user_123", "book_456")

                assert result is None


class TestBookmarks:

    def test_save_user_bookmark_success(self):
        mock_cursor = MockCursor()
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import save_user_bookmark

                result = save_user_bookmark("user_123", "book_456", 300.0, "Important section")

                assert result is not None

    def test_get_user_bookmarks(self, sample_bookmark_data):
        bookmarks = [sample_bookmark_data]
        mock_cursor = MockCursor(fetchall_result=bookmarks)
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_user_bookmarks

                result = get_user_bookmarks("user_12345", "book_gatsby_001")

                assert isinstance(result, list)


class TestSearchBooks:

    def test_search_books_with_results(self, sample_books_list):
        mock_cursor = MockCursor(
            fetchall_result=sample_books_list[:1],
            fetchone_result={"total": 1}
        )
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import search_books

                result = search_books("Gatsby")

                assert "books" in result
                assert "total_books" in result

    def test_search_books_no_results(self):
        mock_cursor = MockCursor(
            fetchall_result=[],
            fetchone_result={"total": 0}
        )
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import search_books

                result = search_books("NonexistentBookTitle123")

                assert result["books"] == []
                assert result["total_books"] == 0


class TestGetCategories:

    def test_get_categories_from_db(self):
        categories = [
            {"id": "classics", "name": "Classics", "description": "Classic literature", "display_order": 1, "is_active": True},
            {"id": "fiction", "name": "Fiction", "description": "Fiction books", "display_order": 2, "is_active": True}
        ]
        mock_cursor = MockCursor(fetchall_result=categories)
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_categories

                result = get_categories()

                assert "categories" in result
                assert "total_count" in result

    def test_get_categories_db_error_returns_fallback(self):
        with patch("db_utils.get_db_connection") as mock_get_conn:
            mock_get_conn.side_effect = Exception("Database error")

            with patch("db_utils.storage"):
                from db_utils import get_categories

                result = get_categories()

                assert len(result["categories"]) >= 3
                category_ids = [c["id"] for c in result["categories"]]
                assert "classics" in category_ids


class TestDatabaseConnection:

    def test_test_database_connection_success(self):
        mock_cursor = MockCursor(fetchone_result=(1,))
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import test_database_connection

                result = test_database_connection()

                assert result is True

    def test_test_database_connection_failure(self):
        with patch("db_utils.get_db_connection") as mock_get_conn:
            mock_get_conn.side_effect = Exception("Connection failed")

            with patch("db_utils.storage"):
                from db_utils import test_database_connection

                result = test_database_connection()

                assert result is False


class TestWishlist:

    def test_add_to_wishlist_success(self):
        mock_cursor = MockCursor()

        results = [
            {"id": "book_123", "title": "Test Book"},
            None,
            {"id": "wishlist_1", "added_at": datetime.now()}
        ]
        call_count = [0]

        def fetchone_side_effect():
            if call_count[0] < len(results):
                result = results[call_count[0]]
                call_count[0] += 1
                return result
            return None

        mock_cursor.fetchone = fetchone_side_effect
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import add_to_user_wishlist

                result = add_to_user_wishlist("user_123", "book_123")

                assert result is not None
                assert "message" in result

    def test_get_user_wishlist(self):
        wishlist_items = [
            {"wishlist_id": "w1", "book_id": "b1", "title": "Book 1", "added_at": datetime.now()}
        ]
        mock_cursor = MockCursor(
            fetchall_result=wishlist_items,
            fetchone_result={"total": 1}
        )
        mock_conn = MockConnection(mock_cursor)

        with patch("db_utils.get_db_connection", return_value=mock_conn):
            with patch("db_utils.storage"):
                from db_utils import get_user_wishlist

                result = get_user_wishlist("user_123")

                assert "books" in result
                assert "total_books" in result
