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

/// Global app state - demo mode, no auth required
@MainActor
class AppState: ObservableObject {
    // Navigation
    @Published var selectedBook: Book?
    @Published var selectedPersona: Persona?

    // Player state
    @Published var currentChapter: Int = 1
    @Published var isPlaying = false
    @Published var playbackPosition: TimeInterval = 0

    // Services
    let apiService = APIService()
    let audioService = AudioService()
    let voiceService = VoiceService()

    // Demo auth token (obtained silently)
    @Published var authToken: String?

    init() {
        Task { await autoLogin() }
    }

    /// Silently create/login a demo account for API access
    private func autoLogin() async {
        let email = "demo@betterbooks.app"
        let password = "demopass123"

        do {
            // Try signin first
            let response = try await apiService.login(email: email, password: password)
            self.authToken = response.token
            await apiService.setAuthToken(response.token)
        } catch {
            // If signin fails, try signup
            do {
                let response = try await apiService.signup(email: email, password: password, name: "Demo User")
                self.authToken = response.token
                await apiService.setAuthToken(response.token)
            } catch {
                print("Demo auto-login failed: \(error.localizedDescription)")
            }
        }
    }
}
