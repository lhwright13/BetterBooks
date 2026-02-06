import SwiftUI

@main
struct BetterBooksApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// Global app state shared across views
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var authToken: String?

    // Player state
    @Published var currentBook: Book?
    @Published var currentChapter: Int = 0
    @Published var isPlaying = false
    @Published var playbackPosition: TimeInterval = 0

    // Services
    let apiService = APIService()
    let audioService = AudioService()
    let voiceService = VoiceService()

    init() {
        // Load saved auth token
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            self.authToken = token
            self.isAuthenticated = true
            Task { await loadUser() }
        }
    }

    func login(email: String, password: String) async throws {
        let response = try await apiService.login(email: email, password: password)
        self.authToken = response.token
        self.currentUser = response.user
        self.isAuthenticated = true
        UserDefaults.standard.set(response.token, forKey: "authToken")
    }

    func logout() {
        authToken = nil
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "authToken")
    }

    private func loadUser() async {
        // Load user profile from saved token
        // Implementation depends on your API
    }
}
