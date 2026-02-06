import XCTest
@testable import BetterBooks

final class ModelsTests: XCTestCase {

    // MARK: - User Model Tests

    func testUserDecoding() throws {
        let json = """
        {
            "id": "user123",
            "email": "test@example.com",
            "displayName": "Test User",
            "credits": 10
        }
        """
        let data = json.data(using: .utf8)!
        let user = try JSONDecoder().decode(User.self, from: data)

        XCTAssertEqual(user.id, "user123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.credits, 10)
    }

    func testUserNameFallback() throws {
        let json = """
        {
            "id": "user123",
            "email": "john.doe@example.com",
            "displayName": null,
            "credits": 5
        }
        """
        let data = json.data(using: .utf8)!
        let user = try JSONDecoder().decode(User.self, from: data)

        // Should extract name from email when displayName is nil
        XCTAssertEqual(user.name, "john.doe")
    }

    // MARK: - Book Model Tests

    func testBookDecoding() throws {
        let json = """
        {
            "id": "book001",
            "title": "The Great Gatsby",
            "author": "F. Scott Fitzgerald",
            "narrator": "LibriVox Reader",
            "description": "A classic novel",
            "coverUrl": "https://example.com/cover.jpg",
            "price": 5,
            "totalDuration": 18000,
            "chapterCount": 9,
            "categories": ["Classic", "Fiction"]
        }
        """
        let data = json.data(using: .utf8)!
        let book = try JSONDecoder().decode(Book.self, from: data)

        XCTAssertEqual(book.id, "book001")
        XCTAssertEqual(book.title, "The Great Gatsby")
        XCTAssertEqual(book.author, "F. Scott Fitzgerald")
        XCTAssertEqual(book.price, 5)
        XCTAssertEqual(book.chapterCount, 9)
    }

    func testBookDecodingWithOptionalFields() throws {
        let json = """
        {
            "id": "book002",
            "title": "Test Book",
            "author": "Test Author",
            "price": 0
        }
        """
        let data = json.data(using: .utf8)!
        let book = try JSONDecoder().decode(Book.self, from: data)

        XCTAssertEqual(book.id, "book002")
        XCTAssertNil(book.narrator)
        XCTAssertNil(book.description)
        XCTAssertNil(book.coverUrl)
    }

    // MARK: - Persona Model Tests

    func testPersonaDecoding() throws {
        let json = """
        {
            "id": "nick-carraway",
            "name": "Nick Carraway",
            "description": "The narrator of The Great Gatsby",
            "avatarUrl": null,
            "voiceId": "en-US-Neural2-J",
            "isGlobal": false
        }
        """
        let data = json.data(using: .utf8)!
        let persona = try JSONDecoder().decode(Persona.self, from: data)

        XCTAssertEqual(persona.id, "nick-carraway")
        XCTAssertEqual(persona.name, "Nick Carraway")
        XCTAssertFalse(persona.isGlobal)
    }

    func testPersonaDisplayEmoji() throws {
        let testCases: [(String, String)] = [
            ("gatsby-persona", "🎩"),
            ("nick-carraway", "📝"),
            ("daisy-buchanan", "🌸"),
            ("english-teacher", "📚"),
            ("language-tutor", "🎓"),
            ("unknown-persona", "🤖")
        ]

        for (id, expectedEmoji) in testCases {
            let persona = Persona(
                id: id,
                name: "Test",
                description: "Test",
                avatarUrl: nil,
                voiceId: nil,
                isGlobal: false
            )
            XCTAssertEqual(persona.displayEmoji, expectedEmoji, "Failed for persona id: \(id)")
        }
    }

    // MARK: - ChatMessage Tests

    func testChatMessageCreation() {
        let userMessage = ChatMessage(role: .user, content: "Hello")
        let assistantMessage = ChatMessage(role: .assistant, content: "Hi there!")

        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(userMessage.content, "Hello")
        XCTAssertNil(userMessage.audioData)

        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.content, "Hi there!")
    }

    func testChatMessageWithAudio() {
        let audioData = Data([0x00, 0x01, 0x02])
        let message = ChatMessage(role: .assistant, content: "Audio response", audioData: audioData)

        XCTAssertNotNil(message.audioData)
        XCTAssertEqual(message.audioData?.count, 3)
    }

    // MARK: - VoiceChatResponse Tests

    func testVoiceChatResponseDecoding() throws {
        let json = """
        {
            "transcription": "Hello world",
            "confidence": 0.95,
            "response_text": "Hi there!",
            "response_audio_base64": "SGVsbG8=",
            "audio_format": "wav"
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(VoiceChatResponse.self, from: data)

        XCTAssertEqual(response.transcription, "Hello world")
        XCTAssertEqual(response.confidence, 0.95, accuracy: 0.01)
        XCTAssertEqual(response.responseText, "Hi there!")
        XCTAssertEqual(response.responseAudioBase64, "SGVsbG8=")
        XCTAssertEqual(response.audioFormat, "wav")
    }

    func testVoiceChatResponseWithoutAudio() throws {
        let json = """
        {
            "transcription": "Hello",
            "confidence": 0.9,
            "response_text": "Response"
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(VoiceChatResponse.self, from: data)

        XCTAssertNil(response.responseAudioBase64)
        XCTAssertNil(response.audioFormat)
    }

    // MARK: - API Response Tests

    func testBrowseResponseDecoding() throws {
        let json = """
        {
            "books": [
                {
                    "id": "book1",
                    "title": "Book One",
                    "author": "Author One",
                    "price": 5
                },
                {
                    "id": "book2",
                    "title": "Book Two",
                    "author": "Author Two",
                    "price": 10
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(BrowseResponse.self, from: data)

        XCTAssertEqual(response.books.count, 2)
        XCTAssertEqual(response.books[0].title, "Book One")
        XCTAssertEqual(response.books[1].title, "Book Two")
    }

    func testCreditsResponseDecoding() throws {
        let json = """
        {
            "credits": 25
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(CreditsResponse.self, from: data)

        XCTAssertEqual(response.credits, 25)
    }
}
