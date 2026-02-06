import Foundation

// MARK: - User Models

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String?
    var credits: Int

    var name: String {
        displayName ?? email.components(separatedBy: "@").first ?? "User"
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Book Models

struct Book: Codable, Identifiable {
    let id: String
    let title: String
    let author: String
    let narrator: String?
    let description: String?
    let coverUrl: String?
    let price: Int
    let totalDuration: TimeInterval?
    let chapterCount: Int?
    let categories: [String]?

    // Progress tracking
    var currentChapter: Int?
    var currentPosition: TimeInterval?
    var completionPercentage: Double?
}

struct Chapter: Codable, Identifiable {
    let id: String
    let number: Int
    let title: String
    let duration: TimeInterval
    let audioUrl: String
}

// MARK: - Persona Models

struct Persona: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let avatarUrl: String?
    let voiceId: String?
    let isGlobal: Bool

    // UI helper
    var displayEmoji: String {
        switch id.lowercased() {
        case let id where id.contains("gatsby"):
            return "🎩"
        case let id where id.contains("nick"):
            return "📝"
        case let id where id.contains("daisy"):
            return "🌸"
        case let id where id.contains("teacher"):
            return "📚"
        case let id where id.contains("tutor"):
            return "🎓"
        default:
            return "🤖"
        }
    }
}

// MARK: - Chat Models

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let audioData: Data?
    let timestamp: Date

    enum MessageRole {
        case user
        case assistant
    }

    init(role: MessageRole, content: String, audioData: Data? = nil) {
        self.role = role
        self.content = content
        self.audioData = audioData
        self.timestamp = Date()
    }
}

struct VoiceChatResponse: Codable {
    let transcription: String
    let confidence: Double
    let responseText: String
    let responseAudioBase64: String?
    let audioFormat: String?

    enum CodingKeys: String, CodingKey {
        case transcription
        case confidence
        case responseText = "response_text"
        case responseAudioBase64 = "response_audio_base64"
        case audioFormat = "audio_format"
    }
}

// MARK: - API Response Models

struct BrowseResponse: Codable {
    let books: [Book]
}

struct LibraryResponse: Codable {
    let books: [Book]
}

struct PersonasResponse: Codable {
    let personas: [Persona]
}

struct CreditsResponse: Codable {
    let credits: Int
}
