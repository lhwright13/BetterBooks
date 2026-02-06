import Foundation

/// API Service for communicating with BetterBooks backend
actor APIService {
    // Configuration - change for production
    #if DEBUG
    private let baseURL = "http://localhost:8000"
    #else
    private let baseURL = "https://api.betterbooks.app"
    #endif

    private var authToken: String?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    // MARK: - Authentication

    func login(email: String, password: String) async throws -> AuthResponse {
        let body = ["email": email, "password": password]
        return try await post("/auth/signin", body: body)
    }

    func signup(email: String, password: String, name: String?) async throws -> AuthResponse {
        var body = ["email": email, "password": password]
        if let name = name {
            body["display_name"] = name
        }
        return try await post("/auth/signup", body: body)
    }

    // MARK: - Library & Books

    func getLibrary() async throws -> [Book] {
        let response: LibraryResponse = try await get("/bookstore/user/library")
        return response.books
    }

    func browseBooks() async throws -> [Book] {
        let response: BrowseResponse = try await get("/bookstore/browse")
        return response.books
    }

    func getBookDetails(bookId: String) async throws -> Book {
        return try await get("/bookstore/books/\(bookId)")
    }

    func getChapters(bookTitle: String) async throws -> [Chapter] {
        return try await get("/books/\(bookTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bookTitle)/chapters")
    }

    func purchaseBook(bookId: String) async throws {
        let _: [String: String] = try await post("/bookstore/purchase", body: ["book_id": bookId])
    }

    func getCredits() async throws -> Int {
        let response: CreditsResponse = try await get("/bookstore/user/credits")
        return response.credits
    }

    // MARK: - Personas

    func getPersonas(bookId: String) async throws -> [Persona] {
        let response: PersonasResponse = try await get("/bookstore/books/\(bookId)/personas")
        return response.personas
    }

    // MARK: - Progress

    func saveProgress(bookId: String, chapter: Int, position: TimeInterval) async throws {
        let body: [String: Any] = [
            "book_id": bookId,
            "chapter_number": chapter,
            "position_seconds": position
        ]
        let _: [String: String] = try await post("/bookstore/user/progress", body: body)
    }

    // MARK: - Voice Chat

    func voiceChat(
        audioData: Data,
        bookId: String?,
        chapter: Int?,
        timestamp: TimeInterval?,
        personaId: String?
    ) async throws -> VoiceChatResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/voice/chat")!
        var queryItems: [URLQueryItem] = []

        if let bookId = bookId {
            queryItems.append(URLQueryItem(name: "book_id", value: bookId))
        }
        if let chapter = chapter {
            queryItems.append(URLQueryItem(name: "chapter", value: String(chapter)))
        }
        if let timestamp = timestamp {
            queryItems.append(URLQueryItem(name: "timestamp_seconds", value: String(timestamp)))
        }
        if let personaId = personaId {
            queryItems.append(URLQueryItem(name: "persona_id", value: personaId))
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(VoiceChatResponse.self, from: data)
    }

    // MARK: - Audio Streaming URL

    func audioStreamURL(bookTitle: String, chapter: Int) -> URL? {
        let encodedTitle = bookTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bookTitle
        return URL(string: "\(baseURL)/audio/stream/\(encodedTitle)/Chapter%20\(chapter).mp3")
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
