# BetterBooks Audiobook Files

This directory contains audiobook MP3 files that are processed by the BetterBooks AI audiobook companion system.

## About BetterBooks

BetterBooks is an AI-powered audiobook platform that provides intelligent context and interactive features for your listening experience. The system offers:

- **AI Chapter Detection** - Automatically identifies chapter boundaries in audiobooks
- **Intelligent Summaries** - Generates chapter summaries in multiple styles (brief, detailed, themes, key points, Q&A)
- **Interactive Q&A** - Ask questions about characters, plot, themes, or any aspect of your audiobook
- **Multiple AI Personas** - Choose from different AI personalities for varied interaction styles
- **Smart Context** - Maintains awareness of your current position and listening history

## Supported Formats

### Single File Books
Place a single MP3 file directly in this directory:
```
book_files/
├── great_gatsby.mp3
├── 1984.mp3
└── pride_and_prejudice.mp3
```

### Multi-Chapter Books
Create a folder containing MP3 chapter files:
```
book_files/
├── harry_potter_book1/
│   ├── chapter_01.mp3
│   ├── chapter_02.mp3
│   └── chapter_03.mp3
└── lord_of_the_rings/
    ├── fellowship_01.mp3
    ├── fellowship_02.mp3
    └── fellowship_03.mp3
```

## Features

### Chapter Intelligence
- **Auto-Detection**: Advanced algorithms detect natural chapter breaks
- **Smart Summaries**: Generate summaries tailored to your reading style
- **Question Generation**: Create discussion questions for deeper engagement
- **Theme Analysis**: Identify key themes and character developments

### AI Integration
- **Context Awareness**: The system tracks your progress and understands story context
- **Persona Selection**: Choose from various AI personalities for different interaction styles
- **Natural Conversation**: Ask questions in natural language about any aspect of the story

## Processing
- The system automatically detects single files vs. chapter folders
- Chapter files are processed in alphabetical order
- Metadata and progress tracking maintain story context
- Audio is analyzed using speech recognition and AI for enhanced understanding
- Embeddings are created for semantic search and context retrieval

## File Naming Best Practices
- Use descriptive names for single files (e.g., `the_great_gatsby.mp3`)
- For chapters, use numbered prefixes (01, 02, etc.) for proper ordering
- Avoid special characters in filenames
- Supported format: MP3 only (44.1kHz recommended)

## Getting Started
1. Add your audiobook files to this directory
2. Access the web interface at http://localhost:8080
3. Select your book from the dropdown menu
4. Choose a chapter and start listening
5. Use the AI Communication Hub to ask questions or request summaries

## Technical Notes
- Files are automatically indexed when the system starts
- Chapter detection uses machine learning models for accuracy
- All processing happens locally - your audiobooks never leave your system
- Progress and bookmarks are automatically saved