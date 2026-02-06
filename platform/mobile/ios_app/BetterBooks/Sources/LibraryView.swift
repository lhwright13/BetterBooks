import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var books: [Book] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading library...")
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadLibrary() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if books.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Your library is empty")
                            .font(.headline)
                        Text("Browse and purchase books to start your collection")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 20) {
                            ForEach(books) { book in
                                BookCard(book: book)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Library")
            .refreshable {
                await loadLibrary()
            }
        }
        .task {
            await loadLibrary()
        }
    }

    private func loadLibrary() async {
        isLoading = true
        error = nil

        do {
            await appState.apiService.setAuthToken(appState.authToken)
            books = try await appState.apiService.getLibrary()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

struct BookCard: View {
    let book: Book
    @EnvironmentObject var appState: AppState
    @State private var showPlayer = false

    var body: some View {
        Button {
            appState.currentBook = book
            showPlayer = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Cover image
                AsyncImage(url: URL(string: book.coverUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "book.closed")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Title and author
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Text(book.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Progress bar
                if let progress = book.completionPercentage {
                    ProgressView(value: progress / 100)
                        .tint(.accentColor)
                    Text("\(Int(progress))% complete")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(book: book)
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(AppState())
}
