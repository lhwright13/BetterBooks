#!/usr/bin/env python3
"""
Seed the BetterBooks PostgreSQL database with demo-ready data.

This script is idempotent - safe to run multiple times. It uses
INSERT ... ON CONFLICT DO NOTHING patterns throughout.

Usage:
    source venv/bin/activate
    python scripts/seed_demo.py

Requires:
    - PostgreSQL running with the BetterBooks schema already applied
    - DATABASE_URL env var (default: postgresql://betterbooks:betterbooks@localhost:5432/betterbooks)
    - psycopg2 installed in the active venv
"""

import os
import sys
import uuid
from datetime import datetime, timezone

import psycopg2
import psycopg2.extras

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://betterbooks:betterbooks@localhost:5432/betterbooks",
)

DEMO_USER_ID = "00000000-0000-4000-a000-000000000001"
DEMO_USER_EMAIL = "demo@betterbooks.app"
DEMO_USER_USERNAME = "demo"
DEMO_USER_DISPLAY_NAME = "Demo User"
DEMO_USER_PASSWORD = "demo1234"

# Deterministic UUIDs for books so the script is idempotent
BOOK_IDS = {
    "The Great Gatsby":                "10000000-0000-4000-b000-000000000001",
    "Moby Dick":                       "10000000-0000-4000-b000-000000000002",
    "Alice's Adventures in Wonderland": "10000000-0000-4000-b000-000000000003",
    "War and Peace":                   "10000000-0000-4000-b000-000000000004",
    "The Odyssey":                     "10000000-0000-4000-b000-000000000005",
}

# Category UUIDs
CATEGORY_IDS = {
    "Classics":    "20000000-0000-4000-c000-000000000001",
    "Fiction":     "20000000-0000-4000-c000-000000000002",
    "Adventure":   "20000000-0000-4000-c000-000000000003",
    "Philosophy":  "20000000-0000-4000-c000-000000000004",
}

# ---------------------------------------------------------------------------
# Book metadata
# ---------------------------------------------------------------------------

BOOKS = [
    {
        "id": BOOK_IDS["The Great Gatsby"],
        "title": "The Great Gatsby",
        "author": "F. Scott Fitzgerald",
        "narrator": "Professional Narrator",
        "description": (
            "The Great Gatsby is a 1925 novel by American writer F. Scott Fitzgerald. "
            "Set in the Jazz Age on Long Island, the novel depicts narrator Nick "
            "Carraway's interactions with mysterious millionaire Jay Gatsby and "
            "Gatsby's obsession to reunite with his former lover, Daisy Buchanan."
        ),
        "cover_image_url": "/books/cover/The Great Gatsby/GatsbyCover.jpg",
        "price_usd": 0.00,
        "credit_price": 0,
        "is_featured": True,
        "is_bestseller": True,
        "is_new_release": False,
        "duration_minutes": 540,
        "file_path": "The Great Gatsby",
        "total_chapters": 9,
        "sample_audio_url": "/books/The Great Gatsby/Chapter 1.mp3",
    },
    {
        "id": BOOK_IDS["Moby Dick"],
        "title": "Moby Dick",
        "author": "Herman Melville",
        "narrator": "LibriVox Readers",
        "description": (
            "Moby-Dick; or, The Whale is an 1851 novel by American writer Herman "
            "Melville. The book is the sailor Ishmael's narrative of the obsessive "
            "quest of Ahab, captain of the whaling ship Pequod, for revenge against "
            "Moby Dick, the giant white sperm whale that bit off Ahab's leg."
        ),
        "cover_image_url": "/books/cover/Moby Dick/Moby_Dick_1002.jpg",
        "price_usd": 0.00,
        "credit_price": 0,
        "is_featured": True,
        "is_bestseller": False,
        "is_new_release": False,
        "duration_minutes": 2580,
        "file_path": "Moby Dick",
        "total_chapters": 43,
        "sample_audio_url": "/books/Moby Dick/mobydick_000_melville_64kb.mp3",
    },
    {
        "id": BOOK_IDS["Alice's Adventures in Wonderland"],
        "title": "Alice's Adventures in Wonderland",
        "author": "Lewis Carroll",
        "narrator": "LibriVox Reader",
        "description": (
            "Alice's Adventures in Wonderland is an 1865 novel by Lewis Carroll. "
            "It tells of a young girl named Alice who falls through a rabbit hole "
            "into a subterranean fantasy world populated by peculiar, "
            "anthropomorphic creatures."
        ),
        "cover_image_url": "/books/cover/Alice's Adventures in Wonderland/aliceinWonder.jpg",
        "price_usd": 0.00,
        "credit_price": 0,
        "is_featured": False,
        "is_bestseller": False,
        "is_new_release": True,
        "duration_minutes": 360,
        "file_path": "Alice's Adventures in Wonderland",
        "total_chapters": 12,
        "sample_audio_url": "/books/Alice's Adventures in Wonderland/alices_adventures_01_carroll_64kb.mp3",
    },
    {
        "id": BOOK_IDS["War and Peace"],
        "title": "War and Peace",
        "author": "Leo Tolstoy",
        "narrator": "LibriVox Readers",
        "description": (
            "War and Peace is a novel by the Russian author Leo Tolstoy, published "
            "in 1869. It is regarded as one of Tolstoy's finest literary "
            "achievements and remains a classic of world literature. The novel "
            "chronicles the French invasion of Russia and its impact on Tsarist society."
        ),
        "cover_image_url": "/books/cover/War and Peace/warandpeacecover.jpg",
        "price_usd": 0.00,
        "credit_price": 0,
        "is_featured": False,
        "is_bestseller": True,
        "is_new_release": False,
        "duration_minutes": 4080,
        "file_path": "War and Peace",
        "total_chapters": 68,
        "sample_audio_url": "/books/War and Peace/war_peace_v1_maude_translation_01_tolstoy_64kb.mp3",
    },
    {
        "id": BOOK_IDS["The Odyssey"],
        "title": "The Odyssey",
        "author": "Homer",
        "narrator": "Samuel Butler (Translation)",
        "description": (
            "The Odyssey is one of two major ancient Greek epic poems attributed "
            "to Homer. The poem mainly centers on the Greek hero Odysseus and his "
            "journey home after the fall of Troy. It takes Odysseus ten years to "
            "reach Ithaca after the ten-year Trojan War."
        ),
        "cover_image_url": "/books/cover/Odyssey/odessey.jpeg",
        "price_usd": 0.00,
        "credit_price": 0,
        "is_featured": True,
        "is_bestseller": False,
        "is_new_release": False,
        "duration_minutes": 1440,
        "file_path": "Odyssey",
        "total_chapters": 24,
        "sample_audio_url": "/books/Odyssey/odyssey_01_homer_butler_64kb.mp3",
    },
]

# ---------------------------------------------------------------------------
# Chapter data - derived from actual files in book_files/
# ---------------------------------------------------------------------------

CHAPTERS = {
    "The Great Gatsby": [
        {"num": i, "title": f"Chapter {i}", "file": f"The Great Gatsby/Chapter {i}.mp3", "dur": 1800}
        for i in range(1, 10)
    ],
    "Moby Dick": [
        {"num": 1,  "title": "Introduction",                                             "file": "Moby Dick/mobydick_000_melville_64kb.mp3",     "dur": 1200},
        {"num": 2,  "title": "Chapters 1-2: Loomings, The Carpet-Bag",                   "file": "Moby Dick/mobydick_001_002_melville_64kb.mp3", "dur": 1200},
        {"num": 3,  "title": "Chapter 3: The Spouter-Inn",                                "file": "Moby Dick/mobydick_003_melville_64kb.mp3",     "dur": 1200},
        {"num": 4,  "title": "Chapters 4-7: The Counterpane to The Chapel",               "file": "Moby Dick/mobydick_004_007_melville_64kb.mp3", "dur": 1200},
        {"num": 5,  "title": "Chapters 8-9: The Pulpit, The Sermon",                      "file": "Moby Dick/mobydick_008_009_melville_64kb.mp3", "dur": 1200},
        {"num": 6,  "title": "Chapters 10-12: A Bosom Friend to Biographical",            "file": "Moby Dick/mobydick_010_012_melville_64kb.mp3", "dur": 1200},
        {"num": 7,  "title": "Chapters 13-15: Wheelbarrow to Chowder",                    "file": "Moby Dick/mobydick_013_015_melville_64kb.mp3", "dur": 1200},
        {"num": 8,  "title": "Chapter 16: The Ship",                                      "file": "Moby Dick/mobydick_016_melville_64kb.mp3",     "dur": 1200},
        {"num": 9,  "title": "Chapters 17-21: The Ramadan to Going Aboard",               "file": "Moby Dick/mobydick_017_021_melville_64kb.mp3", "dur": 1200},
        {"num": 10, "title": "Chapters 22-25: Merry Christmas to Postscript",             "file": "Moby Dick/mobydick_022_025_melville_64kb.mp3", "dur": 1200},
        {"num": 11, "title": "Chapters 26-27: Knights and Squires",                       "file": "Moby Dick/mobydick_026_027_melville_64kb.mp3", "dur": 1200},
        {"num": 12, "title": "Chapters 28-31: Ahab to Queen Mab",                         "file": "Moby Dick/mobydick_028_031_melville_64kb.mp3", "dur": 1200},
        {"num": 13, "title": "Chapter 32: Cetology",                                      "file": "Moby Dick/mobydick_032_melville_64kb.mp3",     "dur": 1200},
        {"num": 14, "title": "Chapters 33-35: The Specksnyder to The Quarter-Deck",       "file": "Moby Dick/mobydick_033_035_melville_64kb.mp3", "dur": 1200},
        {"num": 15, "title": "Chapters 36-40: The Quarter-Deck to Midnight, Forecastle",  "file": "Moby Dick/mobydick_036_040_melville_64kb.mp3", "dur": 1200},
        {"num": 16, "title": "Chapter 41: Moby Dick",                                     "file": "Moby Dick/mobydick_041_melville_64kb.mp3",     "dur": 1200},
        {"num": 17, "title": "Chapters 42-44: The Whiteness to The Chart",                "file": "Moby Dick/mobydick_042_044_melville_64kb.mp3", "dur": 1200},
        {"num": 18, "title": "Chapters 45-47: The Affidavit to The Mat-Maker",            "file": "Moby Dick/mobydick_045_047_melville_64kb.mp3", "dur": 1200},
        {"num": 19, "title": "Chapters 48-50: The First Lowering to Ahab's Boat",         "file": "Moby Dick/mobydick_048_050_melville_64kb.mp3", "dur": 1200},
        {"num": 20, "title": "Chapters 51-53: The Spirit-Spout to The Gam",               "file": "Moby Dick/mobydick_051_053_melville_64kb.mp3", "dur": 1200},
        {"num": 21, "title": "Chapter 54: The Town-Ho's Story",                           "file": "Moby Dick/mobydick_054_melville_64kb.mp3",     "dur": 1200},
        {"num": 22, "title": "Chapters 55-58",                                            "file": "Moby Dick/mobydick_055_058_melville_64kb.mp3", "dur": 1200},
        {"num": 23, "title": "Chapters 59-63",                                            "file": "Moby Dick/mobydick_059_063_melville_64kb.mp3", "dur": 1200},
        {"num": 24, "title": "Chapters 64-67",                                            "file": "Moby Dick/mobydick_064_067_melville_64kb.mp3", "dur": 1200},
        {"num": 25, "title": "Chapters 68-71",                                            "file": "Moby Dick/mobydick_068_071_melville_64kb.mp3", "dur": 1200},
        {"num": 26, "title": "Chapters 72-73",                                            "file": "Moby Dick/mobydick_072_073_melville_64kb.mp3", "dur": 1200},
        {"num": 27, "title": "Chapters 74-77",                                            "file": "Moby Dick/mobydick_074_077_melville_64kb.mp3", "dur": 1200},
        {"num": 28, "title": "Chapters 78-80",                                            "file": "Moby Dick/mobydick_078_080_melville_64kb.mp3", "dur": 1200},
        {"num": 29, "title": "Chapters 81-82",                                            "file": "Moby Dick/mobydick_081_082_melville_64kb.mp3", "dur": 1200},
        {"num": 30, "title": "Chapters 83-86",                                            "file": "Moby Dick/mobydick_083_086_melville_64kb.mp3", "dur": 1200},
        {"num": 31, "title": "Chapters 87-88",                                            "file": "Moby Dick/mobydick_087_088_melville_64kb.mp3", "dur": 1200},
        {"num": 32, "title": "Chapters 89-91",                                            "file": "Moby Dick/mobydick_089_091_melville_64kb.mp3", "dur": 1200},
        {"num": 33, "title": "Chapters 92-96",                                            "file": "Moby Dick/mobydick_092_096_melville_64kb.mp3", "dur": 1200},
        {"num": 34, "title": "Chapters 97-100",                                           "file": "Moby Dick/mobydick_097_100_melville_64kb.mp3", "dur": 1200},
        {"num": 35, "title": "Chapters 101-104",                                          "file": "Moby Dick/mobydick_101_104_melville_64kb.mp3", "dur": 1200},
        {"num": 36, "title": "Chapters 105-108",                                          "file": "Moby Dick/mobydick_105_108_melville_64kb.mp3", "dur": 1200},
        {"num": 37, "title": "Chapters 109-113",                                          "file": "Moby Dick/mobydick_109_113_melville_64kb.mp3", "dur": 1200},
        {"num": 38, "title": "Chapters 114-118",                                          "file": "Moby Dick/mobydick_114_118_melville_64kb.mp3", "dur": 1200},
        {"num": 39, "title": "Chapters 119-123",                                          "file": "Moby Dick/mobydick_119_123_melville_64kb.mp3", "dur": 1200},
        {"num": 40, "title": "Chapters 124-127",                                          "file": "Moby Dick/mobydick_124_127_melville_64kb.mp3", "dur": 1200},
        {"num": 41, "title": "Chapters 128-132",                                          "file": "Moby Dick/mobydick_128_132_melville_64kb.mp3", "dur": 1200},
        {"num": 42, "title": "Chapter 133: The Chase - First Day",                        "file": "Moby Dick/mobydick_133_melville_64kb.mp3",     "dur": 1200},
        {"num": 43, "title": "Chapter 134: The Chase - Second Day",                       "file": "Moby Dick/mobydick_134_melville_64kb.mp3",     "dur": 1200},
    ],
    "Alice's Adventures in Wonderland": [
        {"num": 1,  "title": "Chapter I: Down the Rabbit-Hole",              "file": "Alice's Adventures in Wonderland/alices_adventures_01_carroll_64kb.mp3", "dur": 1800},
        {"num": 2,  "title": "Chapter II: The Pool of Tears",               "file": "Alice's Adventures in Wonderland/alices_adventures_02_carroll_64kb.mp3", "dur": 1800},
        {"num": 3,  "title": "Chapter III: A Caucus-Race and a Long Tale",  "file": "Alice's Adventures in Wonderland/alices_adventures_03_carroll_64kb.mp3", "dur": 1800},
        {"num": 4,  "title": "Chapter IV: The Rabbit Sends in a Little Bill","file": "Alice's Adventures in Wonderland/alices_adventures_04_carroll_64kb.mp3", "dur": 1800},
        {"num": 5,  "title": "Chapter V: Advice from a Caterpillar",        "file": "Alice's Adventures in Wonderland/alices_adventures_05_carroll_64kb.mp3", "dur": 1800},
        {"num": 6,  "title": "Chapter VI: Pig and Pepper",                  "file": "Alice's Adventures in Wonderland/alices_adventures_06_carroll_64kb.mp3", "dur": 1800},
        {"num": 7,  "title": "Chapter VII: A Mad Tea-Party",                "file": "Alice's Adventures in Wonderland/alices_adventures_07_carroll_64kb.mp3", "dur": 1800},
        {"num": 8,  "title": "Chapter VIII: The Queen's Croquet-Ground",    "file": "Alice's Adventures in Wonderland/alices_adventures_08_carroll_64kb.mp3", "dur": 1800},
        {"num": 9,  "title": "Chapter IX: The Mock Turtle's Story",         "file": "Alice's Adventures in Wonderland/alices_adventures_09_carroll_64kb.mp3", "dur": 1800},
        {"num": 10, "title": "Chapter X: The Lobster Quadrille",            "file": "Alice's Adventures in Wonderland/alices_adventures_10_carroll_64kb.mp3", "dur": 1800},
        {"num": 11, "title": "Chapter XI: Who Stole the Tarts?",            "file": "Alice's Adventures in Wonderland/alices_adventures_11_carroll_64kb.mp3", "dur": 1800},
        {"num": 12, "title": "Chapter XII: Alice's Evidence",               "file": "Alice's Adventures in Wonderland/alices_adventures_12_carroll_64kb.mp3", "dur": 1800},
    ],
    "War and Peace": [
        {"num": i, "title": f"Volume 1, Chapter {i}", "file": f"War and Peace/war_peace_v1_maude_translation_{i:02d}_tolstoy_64kb.mp3", "dur": 3600}
        for i in range(1, 69)
    ],
    "The Odyssey": [
        {"num": i, "title": f"Book {i}", "file": f"Odyssey/odyssey_{i:02d}_homer_butler_64kb.mp3", "dur": 3600}
        for i in range(1, 25)
    ],
}

CATEGORIES = [
    {"id": CATEGORY_IDS["Classics"],   "name": "Classics",   "description": "Timeless literary works that have shaped culture and thought", "display_order": 1},
    {"id": CATEGORY_IDS["Fiction"],    "name": "Fiction",     "description": "Imaginative literature that tells compelling stories",         "display_order": 2},
    {"id": CATEGORY_IDS["Adventure"],  "name": "Adventure",  "description": "Thrilling tales of exploration, danger, and discovery",        "display_order": 3},
    {"id": CATEGORY_IDS["Philosophy"], "name": "Philosophy", "description": "Works exploring fundamental questions about existence and knowledge", "display_order": 4},
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_connection():
    log_url = DATABASE_URL.split("@")[1] if "@" in DATABASE_URL else "local"
    print(f"  Connecting to database: {log_url}")
    return psycopg2.connect(DATABASE_URL, connect_timeout=10)


def table_exists(cur, table_name):
    cur.execute(
        "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = %s)",
        (table_name,),
    )
    return cur.fetchone()[0]


def column_exists(cur, table_name, column_name):
    cur.execute(
        "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = %s AND column_name = %s)",
        (table_name, column_name),
    )
    return cur.fetchone()[0]


# ---------------------------------------------------------------------------
# Seed functions
# ---------------------------------------------------------------------------

def seed_categories(cur):
    print("\n[1/5] Seeding categories...")

    if not table_exists(cur, "book_categories"):
        print("  SKIP - book_categories table does not exist")
        return

    for cat in CATEGORIES:
        cur.execute(
            """
            INSERT INTO book_categories (id, name, description, display_order, is_active)
            VALUES (%s, %s, %s, %s, true)
            ON CONFLICT (name) DO NOTHING
            """,
            (cat["id"], cat["name"], cat["description"], cat["display_order"]),
        )
        print(f"  + Category: {cat['name']}")

    print(f"  Done - {len(CATEGORIES)} categories processed")


def seed_books(cur):
    print("\n[2/5] Seeding books...")

    if not table_exists(cur, "books"):
        print("  SKIP - books table does not exist")
        return

    # Determine which columns are available on the books table
    has_narrator = column_exists(cur, "books", "narrator")
    has_duration_minutes = column_exists(cur, "books", "duration_minutes")
    has_file_path = column_exists(cur, "books", "file_path")
    has_total_chapters = column_exists(cur, "books", "total_chapters")
    has_sample_audio_url = column_exists(cur, "books", "sample_audio_url")

    for book in BOOKS:
        # Check if book already exists by title (more resilient than by id)
        cur.execute("SELECT id FROM books WHERE title = %s LIMIT 1", (book["title"],))
        existing = cur.fetchone()

        if existing:
            # Update the existing row to match demo settings (free pricing, flags)
            cur.execute(
                """
                UPDATE books
                SET price_usd = %s,
                    credit_price = %s,
                    is_featured = %s,
                    is_bestseller = %s,
                    is_new_release = %s
                WHERE title = %s
                """,
                (
                    book["price_usd"],
                    book["credit_price"],
                    book["is_featured"],
                    book["is_bestseller"],
                    book["is_new_release"],
                    book["title"],
                ),
            )
            print(f"  ~ Updated existing book: {book['title']}")
        else:
            # Build column/value lists dynamically based on available columns
            cols = [
                "id", "title", "author", "description", "cover_image_url",
                "price_usd", "credit_price", "is_featured", "is_bestseller",
                "is_new_release",
            ]
            vals = [
                book["id"], book["title"], book["author"], book["description"],
                book["cover_image_url"], book["price_usd"], book["credit_price"],
                book["is_featured"], book["is_bestseller"], book["is_new_release"],
            ]

            if has_narrator:
                cols.append("narrator")
                vals.append(book["narrator"])
            if has_duration_minutes:
                cols.append("duration_minutes")
                vals.append(book["duration_minutes"])
            if has_file_path:
                cols.append("file_path")
                vals.append(book["file_path"])
            if has_total_chapters:
                cols.append("total_chapters")
                vals.append(book["total_chapters"])
            if has_sample_audio_url:
                cols.append("sample_audio_url")
                vals.append(book["sample_audio_url"])

            placeholders = ", ".join(["%s"] * len(vals))
            col_names = ", ".join(cols)

            cur.execute(
                f"INSERT INTO books ({col_names}) VALUES ({placeholders})",
                vals,
            )
            print(f"  + Inserted book: {book['title']}")

    print(f"  Done - {len(BOOKS)} books processed")


def seed_chapters(cur):
    print("\n[3/5] Seeding chapters...")

    if not table_exists(cur, "book_chapters"):
        print("  SKIP - book_chapters table does not exist")
        return

    has_file_path = column_exists(cur, "book_chapters", "file_path")
    has_duration = column_exists(cur, "book_chapters", "duration_seconds")

    total_inserted = 0

    for book_title, chapters in CHAPTERS.items():
        # Look up the book id by title
        cur.execute("SELECT id FROM books WHERE title = %s LIMIT 1", (book_title,))
        row = cur.fetchone()
        if not row:
            print(f"  SKIP - Book not found in database: {book_title}")
            continue

        book_id = row[0]

        for ch in chapters:
            cols = ["book_id", "chapter_number", "title"]
            vals = [str(book_id), ch["num"], ch["title"]]

            if has_file_path:
                cols.append("file_path")
                vals.append(ch["file"])
            if has_duration:
                cols.append("duration_seconds")
                vals.append(ch["dur"])

            placeholders = ", ".join(["%s"] * len(vals))
            col_names = ", ".join(cols)

            # Use ON CONFLICT on the unique constraint (book_id, chapter_number)
            cur.execute(
                f"""
                INSERT INTO book_chapters ({col_names})
                VALUES ({placeholders})
                ON CONFLICT (book_id, chapter_number) DO NOTHING
                """,
                vals,
            )
            total_inserted += cur.rowcount

        print(f"  + {book_title}: {len(chapters)} chapters processed")

    print(f"  Done - {total_inserted} new chapters inserted")


def seed_demo_user(cur):
    print("\n[4/5] Seeding demo user...")

    if not table_exists(cur, "users"):
        print("  SKIP - users table does not exist")
        return

    # Check what columns are on the users table
    has_username = column_exists(cur, "users", "username")
    has_display_name = column_exists(cur, "users", "display_name")
    has_role = column_exists(cur, "users", "role")
    has_is_active = column_exists(cur, "users", "is_active")
    has_email_verified = column_exists(cur, "users", "email_verified")

    # Check if user already exists
    cur.execute("SELECT id FROM users WHERE email = %s LIMIT 1", (DEMO_USER_EMAIL,))
    existing = cur.fetchone()

    if existing:
        demo_id = str(existing[0])
        print(f"  ~ Demo user already exists (id: {demo_id})")
    else:
        cols = ["id", "email"]
        vals = [DEMO_USER_ID, DEMO_USER_EMAIL]

        if has_username:
            cols.append("username")
            vals.append(DEMO_USER_USERNAME)
        if has_display_name:
            cols.append("display_name")
            vals.append(DEMO_USER_DISPLAY_NAME)
        if has_role:
            cols.append("role")
            vals.append("user")
        if has_is_active:
            cols.append("is_active")
            vals.append(True)
        if has_email_verified:
            cols.append("email_verified")
            vals.append(True)

        placeholders = ", ".join(["%s"] * len(vals))
        col_names = ", ".join(cols)

        cur.execute(
            f"INSERT INTO users ({col_names}) VALUES ({placeholders})",
            vals,
        )
        demo_id = DEMO_USER_ID
        print(f"  + Created demo user: {DEMO_USER_EMAIL} (id: {demo_id})")

    # -- Password credentials --
    if table_exists(cur, "password_credentials"):
        import bcrypt

        hashed = bcrypt.hashpw(DEMO_USER_PASSWORD.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        cur.execute(
            """
            INSERT INTO password_credentials (user_id, password_hash, salt)
            VALUES (%s, %s, %s)
            ON CONFLICT (user_id) DO NOTHING
            """,
            (demo_id, hashed, "bcrypt"),
        )
        if cur.rowcount:
            print(f"  + Set password for demo user (password: {DEMO_USER_PASSWORD})")
        else:
            print("  ~ Password credentials already exist")

    # -- Identity --
    if table_exists(cur, "identities"):
        # Check which column name the table uses for provider id
        has_provider_id = column_exists(cur, "identities", "provider_id")
        has_provider_user_id = column_exists(cur, "identities", "provider_user_id")
        has_provider_email = column_exists(cur, "identities", "provider_email")
        has_email_at_auth = column_exists(cur, "identities", "email_at_auth")
        has_is_verified = column_exists(cur, "identities", "is_verified")
        has_verified = column_exists(cur, "identities", "verified")
        has_is_primary = column_exists(cur, "identities", "is_primary")

        id_cols = ["user_id", "provider"]
        id_vals = [demo_id, "email"]

        if has_provider_id:
            id_cols.append("provider_id")
            id_vals.append(DEMO_USER_EMAIL)
        elif has_provider_user_id:
            id_cols.append("provider_user_id")
            id_vals.append(DEMO_USER_EMAIL)

        if has_provider_email:
            id_cols.append("provider_email")
            id_vals.append(DEMO_USER_EMAIL)
        elif has_email_at_auth:
            id_cols.append("email_at_auth")
            id_vals.append(DEMO_USER_EMAIL)

        if has_is_verified:
            id_cols.append("is_verified")
            id_vals.append(True)
        elif has_verified:
            id_cols.append("verified")
            id_vals.append(True)

        if has_is_primary:
            id_cols.append("is_primary")
            id_vals.append(True)

        placeholders = ", ".join(["%s"] * len(id_vals))
        col_names = ", ".join(id_cols)

        # The unique constraint is on (provider, provider_id) or (provider, provider_user_id)
        pid_col = "provider_id" if has_provider_id else "provider_user_id"
        cur.execute(
            f"""
            INSERT INTO identities ({col_names})
            VALUES ({placeholders})
            ON CONFLICT (provider, {pid_col}) DO NOTHING
            """,
            id_vals,
        )
        if cur.rowcount:
            print("  + Created email identity for demo user")
        else:
            print("  ~ Email identity already exists")

    # -- Credits --
    if table_exists(cur, "user_credits"):
        cur.execute(
            """
            INSERT INTO user_credits (user_id, total_credits, used_credits)
            VALUES (%s, 10, 0)
            ON CONFLICT (user_id) DO NOTHING
            """,
            (demo_id,),
        )
        if cur.rowcount:
            print("  + Initialized 10 credits for demo user")
        else:
            print("  ~ Credits already initialized")

    # -- User preferences --
    if table_exists(cur, "user_preferences"):
        cur.execute(
            """
            INSERT INTO user_preferences (user_id)
            VALUES (%s)
            ON CONFLICT (user_id) DO NOTHING
            """,
            (demo_id,),
        )

    print("  Done")


def seed_demo_library(cur):
    print("\n[5/5] Seeding demo user library...")

    # Get demo user id
    cur.execute("SELECT id FROM users WHERE email = %s LIMIT 1", (DEMO_USER_EMAIL,))
    user_row = cur.fetchone()
    if not user_row:
        print("  SKIP - Demo user not found")
        return
    demo_id = str(user_row[0])

    books_to_purchase = ["The Great Gatsby", "Alice's Adventures in Wonderland"]

    for title in books_to_purchase:
        cur.execute("SELECT id FROM books WHERE title = %s LIMIT 1", (title,))
        book_row = cur.fetchone()
        if not book_row:
            print(f"  SKIP - Book not found: {title}")
            continue

        book_id = str(book_row[0])

        # Insert into user_purchases
        if table_exists(cur, "user_purchases"):
            cur.execute(
                """
                INSERT INTO user_purchases (user_id, book_id, purchase_type, price_paid, credits_used)
                VALUES (%s::uuid, %s::uuid, 'credit', 0.00, 0)
                ON CONFLICT (user_id, book_id) DO NOTHING
                """,
                (demo_id, book_id),
            )
            if cur.rowcount:
                print(f"  + Purchased: {title}")
            else:
                print(f"  ~ Already purchased: {title}")

        # Insert into user_library
        if table_exists(cur, "user_library"):
            cur.execute(
                """
                INSERT INTO user_library (user_id, book_id, access_type)
                VALUES (%s::uuid, %s, 'purchase')
                ON CONFLICT (user_id, book_id) DO NOTHING
                """,
                (demo_id, book_id),
            )

    print("  Done")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("=" * 60)
    print("BetterBooks Demo Data Seeder")
    print("=" * 60)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()

        seed_categories(cur)
        seed_books(cur)
        seed_chapters(cur)
        seed_demo_user(cur)
        seed_demo_library(cur)

        conn.commit()

        print("\n" + "=" * 60)
        print("Seed complete. All data committed successfully.")
        print("=" * 60)
        print()
        print("Demo credentials:")
        print(f"  Email:    {DEMO_USER_EMAIL}")
        print(f"  Password: {DEMO_USER_PASSWORD}")
        print()

    except psycopg2.OperationalError as e:
        print(f"\nERROR: Could not connect to database: {e}")
        print("Make sure PostgreSQL is running and DATABASE_URL is set correctly.")
        sys.exit(1)
    except Exception as e:
        print(f"\nERROR: {e}")
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    main()
