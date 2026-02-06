import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView(selectedTab: $selectedTab)
            } else {
                AuthView()
            }
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .tag(0)

                BrowseView()
                    .tabItem {
                        Label("Browse", systemImage: "magnifyingglass")
                    }
                    .tag(1)

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.circle")
                    }
                    .tag(2)
            }
            .tint(Color.accentColor)

            // Mini player overlay when book is playing
            if appState.currentBook != nil {
                MiniPlayerView()
                    .padding(.bottom, 49) // Tab bar height
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
