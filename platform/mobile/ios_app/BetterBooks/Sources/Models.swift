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

struct Book: Codable, Identifiable, Hashable {
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

    // Hashable
    static func == (lhs: Book, rhs: Book) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // ─── UI Helpers ───
    var emoji: String {
        let t = title.lowercased()
        if t.contains("gatsby") { return "🥂" }
        if t.contains("moby") { return "🐋" }
        if t.contains("alice") { return "🐰" }
        if t.contains("war") { return "⚔️" }
        if t.contains("odyssey") { return "🏛️" }
        if t.contains("pride") { return "💌" }
        return "📚"
    }

    var knownChapterCount: Int {
        if let c = chapterCount, c > 0 { return c }
        let counts: [String: Int] = [
            "The Great Gatsby": 9,
            "Moby Dick": 47,
            "Alice's Adventures in Wonderland": 12,
            "War and Peace": 50,
            "Odyssey": 24,
            "Pride and Prejudice": 61
        ]
        return counts[title] ?? 10
    }
}

struct Chapter: Codable, Identifiable {
    let id: String
    let number: Int
    let title: String
    let duration: TimeInterval
    let audioUrl: String
}

// MARK: - Persona Models

struct Persona: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let avatarUrl: String?
    let voiceId: String?
    let isGlobal: Bool

    // Hashable
    static func == (lhs: Persona, rhs: Persona) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// The type of persona — inferred from ID/name
    var personaType: PersonaType {
        let n = name.lowercased()
        if n.contains("teacher") || n.contains("tutor") || n.contains("professor") || n.contains("guide") || n.contains("historian") || n.contains("narrator") {
            return .guide
        }
        return .character
    }

    enum PersonaType: String {
        case character
        case guide
    }

    var displayEmoji: String {
        let n = name.lowercased()
        if n.contains("gatsby") { return "🎩" }
        if n.contains("nick") { return "📝" }
        if n.contains("daisy") { return "🌸" }
        if n.contains("jordan") { return "🏌️" }
        if n.contains("ahab") { return "⚓" }
        if n.contains("ishmael") { return "🚢" }
        if n.contains("alice") { return "🐰" }
        if n.contains("cheshire") { return "😸" }
        if n.contains("teacher") || n.contains("professor") { return "📚" }
        if n.contains("tutor") { return "🎓" }
        if n.contains("narrator") { return "🎙️" }
        if n.contains("historian") { return "📜" }
        return "🎭"
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

// MARK: - Fallback Data

enum FallbackData {
    static let books: [Book] = [
        Book(id: "the-great-gatsby", title: "The Great Gatsby", author: "F. Scott Fitzgerald", narrator: "LibriVox", description: "A classic tale of wealth and longing in the Jazz Age.", coverUrl: nil, price: 0, totalDuration: 3600, chapterCount: 9, categories: ["Classic"]),
        Book(id: "moby-dick", title: "Moby Dick", author: "Herman Melville", narrator: "LibriVox", description: "Captain Ahab's obsessive quest for the great white whale.", coverUrl: nil, price: 0, totalDuration: 7200, chapterCount: 47, categories: ["Classic"]),
        Book(id: "alice-wonderland", title: "Alice's Adventures in Wonderland", author: "Lewis Carroll", narrator: "LibriVox", description: "Alice tumbles down a rabbit hole into a fantastical world.", coverUrl: nil, price: 0, totalDuration: 2700, chapterCount: 12, categories: ["Fantasy"]),
        Book(id: "war-and-peace", title: "War and Peace", author: "Leo Tolstoy", narrator: "LibriVox", description: "An epic chronicle of Russian society during the Napoleonic era.", coverUrl: nil, price: 0, totalDuration: 14400, chapterCount: 50, categories: ["Classic"]),
        Book(id: "odyssey", title: "Odyssey", author: "Homer", narrator: "LibriVox", description: "Odysseus's legendary journey home from the Trojan War.", coverUrl: nil, price: 0, totalDuration: 5400, chapterCount: 24, categories: ["Epic"]),
        Book(id: "pride-and-prejudice", title: "Pride and Prejudice", author: "Jane Austen", narrator: "LibriVox", description: "The spirited Elizabeth Bennet navigates love and social expectations.", coverUrl: nil, price: 0, totalDuration: 9000, chapterCount: 61, categories: ["Classic"])
    ]

    static let personas: [Persona] = [
        Persona(id: "english-teacher", name: "English Teacher", description: "An insightful guide who helps you understand themes, symbols, and literary techniques.", avatarUrl: nil, voiceId: nil, isGlobal: true),
        Persona(id: "narrator", name: "Narrator", description: "Experience the story through the voice of the narrator, bringing the text to life.", avatarUrl: nil, voiceId: nil, isGlobal: true)
    ]
}
