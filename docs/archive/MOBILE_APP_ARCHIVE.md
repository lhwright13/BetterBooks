# Mobile App Archive (Flutter/iOS)

**Archived**: November 2024
**Reason**: Simplified to web-only MVP

## App Overview

Flutter audiobook app with AI chat capabilities. Built for iOS with plans for Android.

## User Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Splash    │────▶│  Onboarding │────▶│    Auth     │
│   Screen    │     │  (Welcome)  │     │  (Login)    │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    ▼                          ▼                          ▼
             ┌─────────────┐           ┌─────────────┐           ┌─────────────┐
             │   Discover  │           │   Library   │           │   Profile   │
             │  (Browse)   │           │  (My Books) │           │  (Settings) │
             └──────┬──────┘           └──────┬──────┘           └─────────────┘
                    │                         │
                    ▼                         ▼
             ┌─────────────┐           ┌─────────────┐
             │    Book     │           │   Player    │
             │   Details   │           │   Screen    │
             └──────┬──────┘           └─────────────┘
                    │
          ┌────────┴────────┐
          ▼                 ▼
   ┌─────────────┐   ┌─────────────┐
   │  Purchase   │   │  AI Chat    │
   │    Flow     │   │  (Voice/    │
   └─────────────┘   │   Text)     │
                     └─────────────┘
```

## Screen Inventory

### Auth & Onboarding
- `splash_screen.dart` - App launch/loading
- `welcome_screen.dart` - First-time user welcome
- `preferences_screen.dart` - Reading preferences setup
- `subscription_screen.dart` - Plan selection
- `enhanced_auth_screen.dart` - Login/signup with JWT

### Main Navigation (Bottom Tabs)
- `home_screen.dart` - Main tab container
- `discover_screen.dart` - Browse/search books
- `library_screen.dart` - User's purchased books
- `profile_screen.dart` - Account settings

### Book Experience
- `book_details_screen.dart` - Book info, purchase
- `enhanced_book_details_screen.dart` - Rich book details with chapters
- `full_player_screen.dart` - Audiobook playback
- `mini_player.dart` - Persistent bottom player

### AI Chat
- `text_chat_screen.dart` - Text-based AI conversation
- `voice_chat_screen.dart` - Voice-based AI conversation (speech-to-text)

### Profile Subpages
- `downloads_screen.dart` - Offline content management
- `wishlist_screen.dart` - Saved books
- `listening_history_screen.dart` - Playback history
- `ai_settings_screen.dart` - Persona/voice settings
- `app_settings_screen.dart` - App preferences
- `help_support_screen.dart` - Help/FAQ

## Key Services

| Service | Purpose |
|---------|---------|
| `api_client.dart` | HTTP client for backend |
| `auth_service.dart` | JWT token management |
| `download_service.dart` | Offline audio caching |
| `voice_service.dart` | Speech-to-text (disabled) |
| `player_state_service.dart` | Audio playback state |
| `analytics_service.dart` | Usage tracking |

## Data Models
- `book_models.dart` - Book, Chapter, Category
- `auth_models.dart` - User, Token
- `chat_models.dart` - Message, Persona

## API Endpoints Used
```
POST /auth/signin          - Login
POST /auth/signup          - Register
GET  /bookstore/browse     - List books
GET  /bookstore/user/library - User's books
GET  /bookstore/user/credits - Credit balance
POST /bookstore/purchase   - Buy book
GET  /bookstore/books/{id}/personas - AI personas
POST /complete             - AI chat (LLM Gateway)
```

## Tech Stack
- Flutter 3.x
- Provider (state management)
- http package (networking)
- just_audio (playback)
- speech_to_text (disabled - iOS issues)

## Known Issues at Archive Time
- iOS Swift header compatibility issues
- Speech-to-text disabled
- Audio features required macOS 11.0+
- General frontend compilation issues

## Screenshots
See `platform/mobile/mobile_app/*.png` for UI screenshots.
