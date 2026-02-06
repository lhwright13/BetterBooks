#!/usr/bin/env python3
"""
Transcript Generator for BetterBooks

Generates transcript.json files from audio files using OpenAI Whisper.
Outputs timestamped chunks compatible with the context engine.

Usage:
    python generate_transcripts.py --book "The Great Gatsby"
    python generate_transcripts.py --all
    python generate_transcripts.py --book "Moby Dick" --model large

Requirements:
    pip install openai-whisper

Note: Whisper models range from 'tiny' (fastest) to 'large' (most accurate).
For audiobooks, 'base' or 'small' usually provide good results.
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Optional

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

BOOK_FILES_DIR = PROJECT_ROOT / "book_files"

# Book metadata for generating transcripts
BOOK_METADATA = {
    "The Great Gatsby": {
        "author": "F. Scott Fitzgerald",
        "book_id": "the-great-gatsby"
    },
    "Moby Dick": {
        "author": "Herman Melville",
        "book_id": "moby-dick"
    },
    "Alice's Adventures in Wonderland": {
        "author": "Lewis Carroll",
        "book_id": "alices-adventures-in-wonderland"
    },
    "Odyssey": {
        "author": "Homer",
        "book_id": "odyssey"
    },
    "War and Peace": {
        "author": "Leo Tolstoy",
        "book_id": "war-and-peace"
    }
}


def transcribe_audio_file(audio_path: Path, model) -> dict:
    """Transcribe a single audio file and return segments with timestamps."""
    print(f"  Transcribing: {audio_path.name}")
    result = model.transcribe(str(audio_path), word_timestamps=False)
    return result


def create_chunks_from_segments(segments: list, chunk_duration: float = 30.0) -> list:
    """Convert Whisper segments into larger chunks for context."""
    if not segments:
        return []

    chunks = []
    current_chunk = {
        "index": 0,
        "start": segments[0]["start"],
        "end": segments[0]["end"],
        "text": segments[0]["text"].strip()
    }

    for segment in segments[1:]:
        # If adding this segment would exceed chunk duration, start a new chunk
        if segment["end"] - current_chunk["start"] > chunk_duration:
            chunks.append(current_chunk)
            current_chunk = {
                "index": len(chunks),
                "start": segment["start"],
                "end": segment["end"],
                "text": segment["text"].strip()
            }
        else:
            # Add to current chunk
            current_chunk["end"] = segment["end"]
            current_chunk["text"] += " " + segment["text"].strip()

    # Don't forget the last chunk
    chunks.append(current_chunk)
    return chunks


def get_chapter_number(filename: str) -> Optional[int]:
    """Extract chapter number from filename."""
    import re
    # Match patterns like "Chapter 1.mp3", "chapter_01.mp3", "01.mp3", "Book 01.mp3"
    patterns = [
        r"[Cc]hapter\s*(\d+)",
        r"[Bb]ook\s*(\d+)",
        r"^(\d+)\.",
        r"_(\d+)\."
    ]
    for pattern in patterns:
        match = re.search(pattern, filename)
        if match:
            return int(match.group(1))
    return None


def generate_transcript(book_name: str, model_name: str = "base", force: bool = False):
    """Generate transcript.json for a book."""
    book_dir = BOOK_FILES_DIR / book_name

    if not book_dir.exists():
        print(f"Error: Book directory not found: {book_dir}")
        return False

    transcript_path = book_dir / "transcript.json"
    if transcript_path.exists() and not force:
        print(f"Transcript already exists for {book_name}. Use --force to overwrite.")
        return False

    # Get book metadata
    metadata = BOOK_METADATA.get(book_name, {
        "author": "Unknown",
        "book_id": book_name.lower().replace(" ", "-")
    })

    # Find audio files
    audio_files = sorted(book_dir.glob("*.mp3"))
    if not audio_files:
        print(f"No MP3 files found in {book_dir}")
        return False

    print(f"\nGenerating transcript for: {book_name}")
    print(f"Found {len(audio_files)} audio files")
    print(f"Using Whisper model: {model_name}")

    # Load Whisper model
    try:
        import whisper
    except ImportError:
        print("\nError: Whisper not installed. Run:")
        print("  pip install openai-whisper")
        return False

    print(f"Loading Whisper model '{model_name}'...")
    model = whisper.load_model(model_name)

    # Process each chapter
    chapters = []
    for audio_file in audio_files:
        chapter_num = get_chapter_number(audio_file.name)
        if chapter_num is None:
            print(f"  Warning: Could not determine chapter number for {audio_file.name}")
            chapter_num = len(chapters) + 1

        # Transcribe
        result = transcribe_audio_file(audio_file, model)

        # Get duration from the last segment
        duration = result["segments"][-1]["end"] if result["segments"] else 0

        # Create chunks
        chunks = create_chunks_from_segments(result["segments"])

        chapter_data = {
            "chapter": chapter_num,
            "title": f"Chapter {chapter_num}",
            "duration_seconds": round(duration),
            "chunks": chunks
        }
        chapters.append(chapter_data)

        print(f"  Chapter {chapter_num}: {len(chunks)} chunks, {round(duration)}s")

    # Sort chapters by number
    chapters.sort(key=lambda x: x["chapter"])

    # Create transcript document
    transcript = {
        "book_id": metadata["book_id"],
        "title": book_name,
        "author": metadata["author"],
        "total_chapters": len(chapters),
        "chapters": chapters
    }

    # Write to file
    with open(transcript_path, "w", encoding="utf-8") as f:
        json.dump(transcript, f, indent=2, ensure_ascii=False)

    print(f"\nTranscript saved to: {transcript_path}")
    print(f"Total chapters: {len(chapters)}")
    return True


def main():
    parser = argparse.ArgumentParser(description="Generate transcripts for BetterBooks")
    parser.add_argument("--book", type=str, help="Book name (folder name in book_files/)")
    parser.add_argument("--all", action="store_true", help="Generate for all books")
    parser.add_argument("--model", type=str, default="base",
                        choices=["tiny", "base", "small", "medium", "large"],
                        help="Whisper model to use (default: base)")
    parser.add_argument("--force", action="store_true", help="Overwrite existing transcripts")
    parser.add_argument("--list", action="store_true", help="List available books")

    args = parser.parse_args()

    if args.list:
        print("Available books:")
        for book_dir in sorted(BOOK_FILES_DIR.iterdir()):
            if book_dir.is_dir():
                has_transcript = (book_dir / "transcript.json").exists()
                status = "[has transcript]" if has_transcript else "[no transcript]"
                mp3_count = len(list(book_dir.glob("*.mp3")))
                print(f"  {book_dir.name}: {mp3_count} chapters {status}")
        return

    if args.all:
        for book_dir in sorted(BOOK_FILES_DIR.iterdir()):
            if book_dir.is_dir() and list(book_dir.glob("*.mp3")):
                generate_transcript(book_dir.name, args.model, args.force)
    elif args.book:
        generate_transcript(args.book, args.model, args.force)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
