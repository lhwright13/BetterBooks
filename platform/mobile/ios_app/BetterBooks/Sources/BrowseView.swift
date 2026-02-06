import SwiftUI

struct BrowseView: View {
    @EnvironmentObject var appState: AppState
    @State private var books: [Book] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var error: String?

    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return books
        }
        return books.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading books...")
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                        Button("Retry") {
                            Task { await loadBooks() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 20) {
                            ForEach(filteredBooks) { book in
                                BrowseBookCard(book: book)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Browse")
            .searchable(text: $searchText, prompt: "Search books...")
            .refreshable {
                await loadBooks()
            }
        }
        .task {
            await loadBooks()
        }
    }

    private func loadBooks() async {
        isLoading = true
        error = nil

        do {
            await appState.apiService.setAuthToken(appState.authToken)
            books = try await appState.apiService.browseBooks()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

struct BrowseBookCard: View {
    let book: Book
    @EnvironmentObject var appState: AppState
    @State private var showDetails = false
    @State private var isPurchasing = false

    var body: some View {
        Button {
            showDetails = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Text(book.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack {
                        Image(systemName: "creditcard")
                        Text("\(book.price) credits")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetails) {
            BookDetailsSheet(book: book)
        }
    }
}

struct BookDetailsSheet: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var purchased = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AsyncImage(url: URL(string: book.coverUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(0.7, contentMode: .fit)
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 8) {
                        Text(book.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("by \(book.author)")
                            .foregroundColor(.secondary)

                        if let narrator = book.narrator {
                            Text("Narrated by \(narrator)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let description = book.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 20)

                    if purchased {
                        Label("Purchased", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                    } else {
                        Button {
                            Task { await purchaseBook() }
                        } label: {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "creditcard")
                                    Text("Purchase for \(book.price) credits")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isPurchasing)
                        .padding(.horizontal)
                    }

                    if let error = purchaseError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func purchaseBook() async {
        isPurchasing = true
        purchaseError = nil

        do {
            await appState.apiService.setAuthToken(appState.authToken)
            try await appState.apiService.purchaseBook(bookId: book.id)
            purchased = true
        } catch {
            purchaseError = error.localizedDescription
        }

        isPurchasing = false
    }
}

#Preview {
    BrowseView()
        .environmentObject(AppState())
}
