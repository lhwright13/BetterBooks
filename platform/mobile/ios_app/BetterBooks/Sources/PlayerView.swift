import SwiftUI

struct PlayerView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var audioService = AudioService()

    @State private var chapters: [Chapter] = []
    @State private var currentChapter = 1
    @State private var showChapterPicker = false
    @State private var showVoiceChat = false
    @State private var isLoadingChapters = true

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        // Book cover
                        AsyncImage(url: URL(string: book.coverUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay {
                                    Image(systemName: "book.closed")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                }
                        }
                        .frame(width: geometry.size.width * 0.6)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 10)

                        // Title and author
                        VStack(spacing: 8) {
                            Text(book.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            Text(book.author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Chapter selector
                        Button {
                            showChapterPicker = true
                        } label: {
                            HStack {
                                Text("Chapter \(currentChapter)")
                                    .font(.headline)
                                Image(systemName: "chevron.down")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        .disabled(isLoadingChapters)

                        // Progress slider
                        VStack(spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: { audioService.currentTime },
                                    set: { audioService.seek(to: $0) }
                                ),
                                in: 0...max(audioService.duration, 1)
                            )
                            .tint(.accentColor)

                            HStack {
                                Text(audioService.formatTime(audioService.currentTime))
                                Spacer()
                                Text(audioService.formatTime(audioService.duration))
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        // Playback controls
                        HStack(spacing: 40) {
                            Button {
                                audioService.skip(seconds: -15)
                            } label: {
                                Image(systemName: "gobackward.15")
                                    .font(.title)
                            }

                            Button {
                                audioService.togglePlayPause()
                            } label: {
                                Image(systemName: audioService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 70))
                            }

                            Button {
                                audioService.skip(seconds: 30)
                            } label: {
                                Image(systemName: "goforward.30")
                                    .font(.title)
                            }
                        }
                        .foregroundColor(.accentColor)

                        Spacer(minLength: 40)

                        // Voice Chat Button - Hero Feature
                        VoiceChatButton(book: book, chapter: currentChapter, timestamp: audioService.currentTime)
                            .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showVoiceChat = true
                    } label: {
                        Image(systemName: "message.fill")
                    }
                }
            }
            .sheet(isPresented: $showChapterPicker) {
                ChapterPickerView(
                    chapters: chapters,
                    currentChapter: $currentChapter,
                    onSelect: { chapter in
                        playChapter(chapter)
                    }
                )
            }
            .sheet(isPresented: $showVoiceChat) {
                VoiceChatView(book: book, chapter: currentChapter, timestamp: audioService.currentTime)
            }
        }
        .task {
            await loadChapters()
            playChapter(currentChapter)
        }
        .onDisappear {
            // Save progress when leaving
            Task {
                try? await appState.apiService.saveProgress(
                    bookId: book.id,
                    chapter: currentChapter,
                    position: audioService.currentTime
                )
            }
        }
    }

    private func loadChapters() async {
        isLoadingChapters = true
        do {
            chapters = try await appState.apiService.getChapters(bookTitle: book.title)
            // Restore saved chapter if available
            if let savedChapter = book.currentChapter {
                currentChapter = savedChapter
            }
        } catch {
            print("Failed to load chapters: \(error)")
        }
        isLoadingChapters = false
    }

    private func playChapter(_ chapter: Int) {
        currentChapter = chapter
        if let url = appState.apiService.audioStreamURL(bookTitle: book.title, chapter: chapter) {
            audioService.play(url: url)
        }
    }
}

struct ChapterPickerView: View {
    let chapters: [Chapter]
    @Binding var currentChapter: Int
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(1...max(chapters.count, 1), id: \.self) { number in
                Button {
                    onSelect(number)
                    dismiss()
                } label: {
                    HStack {
                        Text("Chapter \(number)")
                            .foregroundColor(.primary)
                        Spacer()
                        if number == currentChapter {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    PlayerView(book: Book(
        id: "1",
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald",
        narrator: "LibriVox",
        description: "A classic American novel",
        coverUrl: nil,
        price: 0,
        totalDuration: 3600,
        chapterCount: 9,
        categories: ["Classic"]
    ))
    .environmentObject(AppState())
}
