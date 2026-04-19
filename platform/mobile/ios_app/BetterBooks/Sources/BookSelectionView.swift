import SwiftUI

/// Screen 1: Choose a book - clean grid, echoWright branding, no auth
struct BookSelectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var books: [Book] = []
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: EW.Spacing.xl) {
                // ─── Logo ───
                VStack(spacing: EW.Spacing.sm) {
                    LogoMark()
                        .frame(width: 64, height: 64)

                    Text("echoWright")
                        .font(EW.Fonts.headingBold(30))
                        .foregroundColor(EW.Colors.dark)
                        .overlay(alignment: .trailing) {
                            // Teal accent on "Wright"
                        }

                    Text("AUDIOBOOKS")
                        .font(EW.Fonts.label(13))
                        .foregroundColor(EW.Colors.gray)
                        .tracking(2)
                }
                .padding(.top, EW.Spacing.xxl)

                // ─── Subtitle ───
                Text("Choose a book to explore")
                    .font(EW.Fonts.heading(20))
                    .foregroundColor(EW.Colors.darkSoft)

                // ─── Book Grid ───
                if isLoading {
                    ProgressView()
                        .tint(EW.Colors.teal)
                        .padding(.top, EW.Spacing.xxl)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(books) { book in
                            NavigationLink(value: NavigationRoute.personaSelection(book)) {
                                BookGridCard(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, EW.Spacing.lg)
            .padding(.bottom, EW.Spacing.xxl)
        }
        .background(EW.Colors.background)
        .navigationBarHidden(true)
        .task {
            await loadBooks()
        }
    }

    private func loadBooks() async {
        isLoading = true
        do {
            let fetched = try await appState.apiService.browseBooks()
            books = fetched.isEmpty ? FallbackData.books : fetched
        } catch {
            books = FallbackData.books
        }
        isLoading = false
    }
}

// MARK: - Book Card

struct BookGridCard: View {
    let book: Book
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover
            ZStack {
                LinearGradient(
                    colors: [EW.Colors.teal, EW.Colors.tealDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let url = coverURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Text(book.emoji)
                                .font(.system(size: 48))
                        }
                    }
                } else {
                    Text(book.emoji)
                        .font(.system(size: 48))
                }
            }
            .aspectRatio(3/4, contentMode: .fill)
            .clipped()

            // Meta
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(EW.Fonts.heading(15))
                    .foregroundColor(EW.Colors.dark)
                    .lineLimit(2)

                Text(book.author)
                    .font(EW.Fonts.caption())
                    .foregroundColor(EW.Colors.gray)
                    .lineLimit(1)
            }
            .padding(EW.Spacing.md)
        }
        .ewCard()
    }

    private var coverURL: URL? {
        if let urlStr = book.coverUrl, let url = URL(string: urlStr) {
            return url
        }
        #if DEBUG
        let base = "http://localhost:8000"
        #else
        let base = "https://api.betterbooks.app"
        #endif
        let encoded = book.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? book.title
        return URL(string: "\(base)/books/cover/\(encoded)/cover.jpg")
    }
}

// MARK: - Logo

struct LogoMark: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Left page (orange)
            var leftPage = Path()
            leftPage.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
            leftPage.addCurve(
                to: CGPoint(x: w * 0.22, y: h * 0.28),
                control1: CGPoint(x: w * 0.38, y: h * 0.15),
                control2: CGPoint(x: w * 0.26, y: h * 0.2)
            )
            leftPage.addLine(to: CGPoint(x: w * 0.22, y: h * 0.78))
            leftPage.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.65),
                control1: CGPoint(x: w * 0.26, y: h * 0.72),
                control2: CGPoint(x: w * 0.38, y: h * 0.65)
            )
            leftPage.closeSubpath()
            context.fill(leftPage, with: .color(EW.Colors.orange))

            // Right page (red-orange)
            var rightPage = Path()
            rightPage.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
            rightPage.addCurve(
                to: CGPoint(x: w * 0.78, y: h * 0.28),
                control1: CGPoint(x: w * 0.62, y: h * 0.15),
                control2: CGPoint(x: w * 0.74, y: h * 0.2)
            )
            rightPage.addLine(to: CGPoint(x: w * 0.78, y: h * 0.78))
            rightPage.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.65),
                control1: CGPoint(x: w * 0.74, y: h * 0.72),
                control2: CGPoint(x: w * 0.62, y: h * 0.65)
            )
            rightPage.closeSubpath()
            context.fill(rightPage, with: .color(EW.Colors.redOrange))
        }
    }
}

#Preview {
    NavigationStack {
        BookSelectionView()
    }
    .environmentObject(AppState())
}
