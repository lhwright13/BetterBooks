import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var appState: AppState
    @State private var showFullPlayer = false

    var body: some View {
        if let book = appState.currentBook {
            Button {
                showFullPlayer = true
            } label: {
                HStack(spacing: 12) {
                    // Book cover thumbnail
                    AsyncImage(url: URL(string: book.coverUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Title and chapter
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text("Chapter \(appState.currentChapter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Play/pause button
                    Button {
                        appState.audioService.togglePlayPause()
                    } label: {
                        Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showFullPlayer) {
                PlayerView(book: book)
            }
        }
    }
}

#Preview {
    VStack {
        Spacer()
        MiniPlayerView()
    }
    .environmentObject({
        let state = AppState()
        state.currentBook = Book(
            id: "1",
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            narrator: nil,
            description: nil,
            coverUrl: nil,
            price: 0,
            totalDuration: nil,
            chapterCount: nil,
            categories: nil
        )
        return state
    }())
}
