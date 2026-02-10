import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            BookSelectionView()
                .navigationDestination(for: NavigationRoute.self) { route in
                    switch route {
                    case .personaSelection(let book):
                        PersonaSelectionView(book: book)
                    case .player(let book, let persona):
                        PlayerChatView(book: book, persona: persona)
                    }
                }
        }
        .tint(EW.Colors.teal)
    }
}

/// Navigation routes for the demo flow
enum NavigationRoute: Hashable {
    case personaSelection(Book)
    case player(Book, Persona)
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
