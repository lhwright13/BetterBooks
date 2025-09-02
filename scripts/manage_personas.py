#!/usr/bin/env python3
"""
Persona Management CLI Tool for BetterBooks
Provides command-line interface for managing AI personas and book-persona relationships
"""

import os
import sys
import json
import argparse
from pathlib import Path

# Add project paths to Python path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))
sys.path.append(str(project_root / "platform" / "backend" / "services" / "api_gateway"))

from db_utils import (
    get_book_personas,
    get_persona_details,
    get_all_personas,
    create_persona,
    update_persona,
    delete_persona,
    add_persona_to_book,
    remove_persona_from_book,
    get_db_connection
)

def list_personas(args):
    """List all personas or personas for a specific book"""
    if args.book_id:
        result = get_book_personas(args.book_id)
        if result:
            print(f"📚 Personas for '{result['book_title']}':")
            for persona in result['personas']:
                default = " (DEFAULT)" if persona['is_default'] else ""
                print(f"  🎭 {persona['persona_display_name']}{default}")
                print(f"     ID: {persona['persona_id']}")
                print(f"     Description: {persona['persona_description']}")
                print(f"     Sort Order: {persona['sort_order']}")
                print()
        else:
            print(f"❌ No personas found for book ID: {args.book_id}")
    else:
        personas = get_all_personas()
        print(f"🎭 All Personas ({len(personas)} total):")
        for persona in personas:
            global_marker = " (GLOBAL)" if persona['is_global'] else ""
            print(f"  🎭 {persona['display_name']}{global_marker}")
            print(f"     ID: {persona['id']}")
            print(f"     Name: {persona['name']}")
            print(f"     Description: {persona['description']}")
            print()

def show_persona(args):
    """Show detailed information about a specific persona"""
    persona = get_persona_details(args.persona_id)
    if persona:
        print(f"🎭 Persona Details: {persona['display_name']}")
        print("=" * 50)
        print(f"ID: {persona['id']}")
        print(f"Name: {persona['name']}")
        print(f"Display Name: {persona['display_name']}")
        print(f"Description: {persona['description']}")
        print(f"Is Global: {persona['is_global']}")
        print(f"Created: {persona['created_at']}")
        print(f"Updated: {persona['updated_at']}")
        print()
        
        if persona['base_prompt']:
            print("📝 Base Prompt:")
            print(persona['base_prompt'][:200] + "..." if len(persona['base_prompt']) > 200 else persona['base_prompt'])
            print()
        
        if persona['voice_config']:
            print("🔊 Voice Config:")
            print(json.dumps(persona['voice_config'], indent=2))
            print()
        
        if persona['generation_config']:
            print("⚙️ Generation Config:")
            print(json.dumps(persona['generation_config'], indent=2))
            print()
            
        if persona['tts_config']:
            print("🗣️ TTS Config:")
            print(json.dumps(persona['tts_config'], indent=2))
    else:
        print(f"❌ Persona not found: {args.persona_id}")

def import_persona(args):
    """Import persona from JSON file"""
    json_file = Path(args.json_file)
    if not json_file.exists():
        print(f"❌ File not found: {json_file}")
        return
    
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            persona_data = json.load(f)
        
        # Extract persona name from filename if not provided
        persona_name = args.name or json_file.stem.replace('_', ' ').title()
        
        # Prepare persona data
        new_persona = {
            'name': persona_name,
            'display_name': persona_name,
            'description': f"AI persona: {persona_name}",
            'base_prompt': persona_data.get('base_preprompt', ''),
            'voice_config': persona_data.get('tts_config', {}),
            'generation_config': persona_data.get('generation_config', {}),
            'tts_config': persona_data.get('tts_config', {}),
            'is_global': args.global_persona
        }
        
        # Add prompt options to generation config if they exist
        if 'prompt_options' in persona_data:
            new_persona['generation_config'].update(persona_data['prompt_options'])
        
        persona_id = create_persona(new_persona)
        if persona_id:
            print(f"✅ Successfully imported persona: {persona_name}")
            print(f"   ID: {persona_id}")
            
            # Add to book if specified
            if args.book_id:
                success = add_persona_to_book(args.book_id, persona_id, args.default)
                if success:
                    default_text = " as default" if args.default else ""
                    print(f"   Added to book{default_text}")
                else:
                    print(f"   ⚠️ Failed to add to book")
        else:
            print(f"❌ Failed to import persona: {persona_name}")
            
    except Exception as e:
        print(f"❌ Error importing persona: {e}")

def add_to_book(args):
    """Add a persona to a book"""
    success = add_persona_to_book(args.book_id, args.persona_id, args.default, args.sort_order)
    if success:
        default_text = " as default" if args.default else ""
        print(f"✅ Added persona to book{default_text}")
        print(f"   Book ID: {args.book_id}")
        print(f"   Persona ID: {args.persona_id}")
        print(f"   Sort Order: {args.sort_order}")
    else:
        print(f"❌ Failed to add persona to book")

def remove_from_book(args):
    """Remove a persona from a book"""
    success = remove_persona_from_book(args.book_id, args.persona_id)
    if success:
        print(f"✅ Removed persona from book")
        print(f"   Book ID: {args.book_id}")
        print(f"   Persona ID: {args.persona_id}")
    else:
        print(f"❌ Failed to remove persona from book")

def list_books(args):
    """List all books in the database"""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT id, title, author FROM books ORDER BY title")
                books = cursor.fetchall()
                
                print(f"📚 Available Books ({len(books)} total):")
                for book in books:
                    print(f"  📖 {book[1]}")
                    if book[2]:
                        print(f"     Author: {book[2]}")
                    print(f"     ID: {book[0]}")
                    print()
    except Exception as e:
        print(f"❌ Error listing books: {e}")

def main():
    """Main CLI interface"""
    parser = argparse.ArgumentParser(description='BetterBooks Persona Management CLI')
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # List personas
    list_parser = subparsers.add_parser('list', help='List personas')
    list_parser.add_argument('--book-id', help='List personas for specific book')
    list_parser.set_defaults(func=list_personas)
    
    # Show persona details
    show_parser = subparsers.add_parser('show', help='Show persona details')
    show_parser.add_argument('persona_id', help='Persona ID to show')
    show_parser.set_defaults(func=show_persona)
    
    # Import persona from JSON
    import_parser = subparsers.add_parser('import', help='Import persona from JSON file')
    import_parser.add_argument('json_file', help='Path to persona JSON file')
    import_parser.add_argument('--name', help='Persona name (defaults to filename)')
    import_parser.add_argument('--book-id', help='Book ID to add persona to')
    import_parser.add_argument('--default', action='store_true', help='Make this the default persona for the book')
    import_parser.add_argument('--global', dest='global_persona', action='store_true', help='Make this a global persona')
    import_parser.set_defaults(func=import_persona)
    
    # Add persona to book
    add_parser = subparsers.add_parser('add-to-book', help='Add persona to book')
    add_parser.add_argument('book_id', help='Book ID')
    add_parser.add_argument('persona_id', help='Persona ID')
    add_parser.add_argument('--default', action='store_true', help='Make this the default persona')
    add_parser.add_argument('--sort-order', type=int, default=0, help='Sort order (default: 0)')
    add_parser.set_defaults(func=add_to_book)
    
    # Remove persona from book
    remove_parser = subparsers.add_parser('remove-from-book', help='Remove persona from book')
    remove_parser.add_argument('book_id', help='Book ID')
    remove_parser.add_argument('persona_id', help='Persona ID')
    remove_parser.set_defaults(func=remove_from_book)
    
    # List books
    books_parser = subparsers.add_parser('books', help='List all books')
    books_parser.set_defaults(func=list_books)
    
    # Parse arguments
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # Set up environment
    os.environ.setdefault('DATABASE_URL', 'postgresql://betterbooks:testpassword123@localhost:5432/betterbooks')
    
    try:
        args.func(args)
    except Exception as e:
        print(f"💥 Error: {e}")
        import traceback
        if os.getenv('DEBUG'):
            traceback.print_exc()

if __name__ == "__main__":
    main()