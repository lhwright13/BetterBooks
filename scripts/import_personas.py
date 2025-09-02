#!/usr/bin/env python3
"""
Persona Import Script for BetterBooks
Imports persona JSON files from book_files directories into the database
"""

import os
import json
import psycopg2
import psycopg2.extras
from pathlib import Path
from datetime import datetime

# Database connection
def get_db_connection():
    """Get database connection using environment variables"""
    db_url = os.getenv('DATABASE_URL', 'postgresql://betterbooks:testpassword123@localhost:5432/betterbooks')
    return psycopg2.connect(db_url)

def find_book_id(cursor, book_title):
    """Find book ID by title"""
    cursor.execute("SELECT id FROM books WHERE title = %s LIMIT 1", (book_title,))
    result = cursor.fetchone()
    return result['id'] if result else None

def import_persona_from_json(cursor, persona_path, book_id=None):
    """Import a single persona JSON file"""
    with open(persona_path, 'r', encoding='utf-8') as f:
        persona_data = json.load(f)
    
    # Extract persona name from filename
    persona_name = persona_path.stem
    display_name = persona_name.replace('_', ' ').title()
    
    # Prepare persona data for database
    base_prompt = persona_data.get('base_preprompt', '')
    voice_config = persona_data.get('tts_config', {})
    generation_config = persona_data.get('generation_config', {})
    
    # Add prompt options to generation config if they exist
    if 'prompt_options' in persona_data:
        generation_config.update(persona_data['prompt_options'])
    
    # Insert or update persona
    cursor.execute("""
        INSERT INTO personas (name, display_name, description, base_prompt, voice_config, generation_config, tts_config, is_global)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (name) DO UPDATE SET
            display_name = EXCLUDED.display_name,
            description = EXCLUDED.description,
            base_prompt = EXCLUDED.base_prompt,
            voice_config = EXCLUDED.voice_config,
            generation_config = EXCLUDED.generation_config,
            tts_config = EXCLUDED.tts_config,
            updated_at = NOW()
        RETURNING id
    """, (
        persona_name,
        display_name,
        f"AI persona: {display_name}",
        base_prompt,
        json.dumps(voice_config),
        json.dumps(generation_config),
        json.dumps(persona_data.get('tts_config', {})),
        False  # Book-specific personas are not global
    ))
    
    persona_id = cursor.fetchone()['id']
    
    # If we have a book_id, create the book-persona relationship
    if book_id:
        cursor.execute("""
            INSERT INTO book_personas (book_id, persona_id, sort_order)
            VALUES (%s, %s, %s)
            ON CONFLICT (book_id, persona_id) DO NOTHING
        """, (book_id, persona_id, 0))
    
    return persona_id, persona_name

def main():
    """Main import function"""
    book_files_dir = Path("/Users/lhwri/BetterBooks/book_files")
    
    # Book title mappings (folder name -> database title)
    book_mappings = {
        "The Great Gatsby": "The Great Gatsby",
        "Moby Dick": "Moby Dick",
        "Alice's Adventures in Wonderland": "Alice's Adventures in Wonderland", 
        "Odyssey": "The Odyssey",
        "War and Peace": "War and Peace"
    }
    
    imported_count = 0
    
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
            
            for book_folder, book_title in book_mappings.items():
                personas_dir = book_files_dir / book_folder / "personas"
                
                if not personas_dir.exists():
                    print(f"⚠️  No personas directory found for {book_folder}")
                    continue
                
                # Find book ID in database
                book_id = find_book_id(cursor, book_title)
                if not book_id:
                    print(f"❌ Book '{book_title}' not found in database")
                    continue
                
                print(f"📚 Processing {book_folder} (book_id: {book_id})")
                
                # Import each persona JSON file
                for persona_file in personas_dir.glob("*.json"):
                    try:
                        persona_id, persona_name = import_persona_from_json(
                            cursor, persona_file, book_id
                        )
                        print(f"  ✅ Imported {persona_name} (id: {persona_id})")
                        imported_count += 1
                        
                    except Exception as e:
                        print(f"  ❌ Failed to import {persona_file.name}: {e}")
            
            conn.commit()
    
    print(f"\n🎉 Import complete! Processed {imported_count} personas")

if __name__ == "__main__":
    main()