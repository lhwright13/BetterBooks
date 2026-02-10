import SwiftUI

/// Screen 2: Pick a persona to chat with about the selected book
struct PersonaSelectionView: View {
    let book: Book
    @EnvironmentObject var appState: AppState
    @State private var personas: [Persona] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: EW.Spacing.lg) {
                // ─── Book Header ───
                VStack(spacing: EW.Spacing.md) {
                    BookCoverSmall(book: book)
                        .frame(width: 90, height: 120)

                    Text(book.title)
                        .font(EW.Fonts.heading(18))
                        .foregroundColor(EW.Colors.dark)
                        .multilineTextAlignment(.center)

                    Text(book.author)
                        .font(EW.Fonts.caption())
                        .foregroundColor(EW.Colors.gray)
                }
                .padding(.top, EW.Spacing.md)

                // ─── Section Title ───
                Text("Who would you like to talk with?")
                    .font(EW.Fonts.heading(20))
                    .foregroundColor(EW.Colors.darkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, EW.Spacing.sm)

                // ─── Persona Cards ───
                if isLoading {
                    ProgressView()
                        .tint(EW.Colors.teal)
                        .padding(.top, EW.Spacing.xl)
                } else {
                    VStack(spacing: EW.Spacing.md) {
                        ForEach(personas) { persona in
                            NavigationLink(value: NavigationRoute.player(book, persona)) {
                                PersonaCard(persona: persona)
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
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPersonas()
        }
    }

    private func loadPersonas() async {
        isLoading = true
        do {
            // getPersonasByTitle handles URL encoding internally
            personas = try await appState.apiService.getPersonasByTitle(bookTitle: book.title)
            if personas.isEmpty { personas = FallbackData.personas }
        } catch {
            personas = FallbackData.personas
        }
        isLoading = false
    }
}

// MARK: - Persona Card

struct PersonaCard: View {
    let persona: Persona

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Emoji avatar
            Text(persona.displayEmoji)
                .font(.system(size: 28))
                .frame(width: 52, height: 52)
                .background(
                    persona.personaType == .guide
                        ? EW.Colors.orangeLight
                        : EW.Colors.tealLight
                )
                .clipShape(Circle())

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(persona.personaType == .guide ? "GUIDE" : "CHARACTER")
                    .font(EW.Fonts.label(11))
                    .foregroundColor(
                        persona.personaType == .guide
                            ? EW.Colors.orange
                            : EW.Colors.tealDark
                    )
                    .tracking(1)

                Text(persona.name)
                    .font(EW.Fonts.bodyMedium(16))
                    .foregroundColor(EW.Colors.dark)

                Text(persona.description)
                    .font(EW.Fonts.caption())
                    .foregroundColor(EW.Colors.gray)
                    .lineLimit(3)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(EW.Colors.grayLight)
                .padding(.top, 18)
        }
        .padding(EW.Spacing.md + 4)
        .ewCard()
    }
}

// MARK: - Small Book Cover

struct BookCoverSmall: View {
    let book: Book

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: EW.Radius.sm)
                .fill(
                    LinearGradient(
                        colors: [EW.Colors.teal, EW.Colors.tealDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let url = coverURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Text(book.emoji).font(.system(size: 32))
                    }
                }
            } else {
                Text(book.emoji).font(.system(size: 32))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: EW.Radius.sm))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
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

#Preview {
    NavigationStack {
        PersonaSelectionView(book: FallbackData.books[0])
    }
    .environmentObject(AppState())
}
