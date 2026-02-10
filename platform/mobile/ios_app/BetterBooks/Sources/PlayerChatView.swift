import SwiftUI

/// Screen 3: Audiobook player with integrated voice/text chat
struct PlayerChatView: View {
    let book: Book
    let persona: Persona

    @EnvironmentObject var appState: AppState
    @StateObject private var audioService = AudioService()
    @StateObject private var voiceService = VoiceService()

    @State private var currentChapter = 1
    @State private var messages: [ChatMessage] = []
    @State private var textInput = ""
    @State private var showChapterPicker = false
    @State private var showWelcome = true

    var body: some View {
        VStack(spacing: 0) {
            // ─── Audio Player Bar ───
            audioPlayerBar

            // ─── Chat Messages ───
            chatArea

            // ─── Input Area ───
            inputArea
        }
        .background(EW.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    BookCoverSmall(book: book)
                        .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(book.title)
                            .font(EW.Fonts.bodyMedium(13))
                            .lineLimit(1)
                        Text(book.author)
                            .font(EW.Fonts.caption(11))
                            .foregroundColor(EW.Colors.gray)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                personaBadge
            }
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet(
                totalChapters: book.knownChapterCount,
                currentChapter: $currentChapter,
                onSelect: { ch in playChapter(ch) }
            )
            .presentationDetents([.medium])
        }
        .task {
            playChapter(1)
        }
        .onDisappear {
            audioService.stop()
        }
    }

    // MARK: - Audio Player Bar

    private var audioPlayerBar: some View {
        VStack(spacing: 8) {
            // Controls
            HStack(spacing: 24) {
                Button { audioService.skip(seconds: -10) } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title3)
                        .foregroundColor(EW.Colors.dark)
                }

                Button { audioService.togglePlayPause() } label: {
                    Image(systemName: audioService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(EW.Colors.teal)
                }

                Button { audioService.skip(seconds: 30) } label: {
                    Image(systemName: "goforward.30")
                        .font(.title3)
                        .foregroundColor(EW.Colors.dark)
                }
            }

            // Progress
            HStack(spacing: 8) {
                Text(audioService.formatTime(audioService.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(EW.Colors.gray)
                    .frame(width: 36, alignment: .trailing)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(EW.Colors.grayLight.opacity(0.3))
                            .frame(height: 4)

                        Capsule()
                            .fill(EW.Colors.teal)
                            .frame(width: geo.size.width * audioService.progress, height: 4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let pct = location.x / geo.size.width
                        audioService.seek(to: pct * audioService.duration)
                    }
                }
                .frame(height: 4)

                Text(audioService.formatTime(audioService.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(EW.Colors.gray)
                    .frame(width: 36, alignment: .leading)
            }

            // Chapter selector
            Button { showChapterPicker = true } label: {
                HStack(spacing: 4) {
                    Text("Chapter \(currentChapter)")
                        .font(EW.Fonts.caption())
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(EW.Colors.gray)
            }
        }
        .padding(.horizontal, EW.Spacing.lg)
        .padding(.vertical, EW.Spacing.md)
        .background(EW.Colors.surface)
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: EW.Spacing.md) {
                    if showWelcome {
                        welcomeCard
                    }

                    ForEach(messages) { msg in
                        MessageRow(message: msg, personaName: persona.name)
                            .id(msg.id)
                    }
                }
                .padding(EW.Spacing.lg)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var welcomeCard: some View {
        VStack(spacing: EW.Spacing.md) {
            Text(persona.displayEmoji)
                .font(.system(size: 44))

            Text("Chatting as \(persona.name)")
                .font(EW.Fonts.heading(17))
                .foregroundColor(EW.Colors.darkSoft)

            Text("Press play to start listening. Ask me anything about \(book.title) — I'll keep it spoiler-free based on where you are.")
                .font(EW.Fonts.caption(14))
                .foregroundColor(EW.Colors.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(EW.Spacing.xl)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 6) {
            // Voice status
            if voiceService.state != .idle {
                Text(voiceStatusText)
                    .font(EW.Fonts.caption(11))
                    .foregroundColor(EW.Colors.gray)
                    .transition(.opacity)
            }

            HStack(spacing: 10) {
                // Text field
                TextField("Ask about the book...", text: $textInput)
                    .font(EW.Fonts.body())
                    .padding(12)
                    .background(EW.Colors.background)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(EW.Colors.grayLight.opacity(0.4), lineWidth: 1.5))
                    .submitLabel(.send)
                    .onSubmit { sendText() }

                // Send button
                if !textInput.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button { sendText() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(EW.Colors.teal)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Mic button
                micButton
            }
            .animation(.easeInOut(duration: 0.2), value: textInput.isEmpty)
        }
        .padding(.horizontal, EW.Spacing.lg)
        .padding(.vertical, EW.Spacing.md)
        .background(EW.Colors.surface)
    }

    private var micButton: some View {
        Button { handleMicTap() } label: {
            ZStack {
                Circle()
                    .fill(micColor)
                    .frame(width: 52, height: 52)
                    .scaleEffect(voiceService.state == .recording ? 1.1 : 1.0)
                    .animation(
                        voiceService.state == .recording
                            ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                            : .default,
                        value: voiceService.state == .recording
                    )

                Group {
                    switch voiceService.state {
                    case .idle:
                        Image(systemName: "mic.fill")
                            .font(.system(size: 22))
                    case .recording:
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18))
                    case .processing:
                        ProgressView()
                            .tint(.white)
                    case .playingResponse:
                        Image(systemName: "waveform")
                            .font(.system(size: 20))
                            .symbolEffect(.variableColor.iterative)
                    }
                }
                .foregroundColor(.white)
            }
        }
        .disabled(voiceService.state == .processing || voiceService.state == .playingResponse)
    }

    private var micColor: Color {
        switch voiceService.state {
        case .idle: return EW.Colors.orange
        case .recording: return EW.Colors.redOrange
        case .processing: return EW.Colors.gray
        case .playingResponse: return EW.Colors.teal
        }
    }

    private var voiceStatusText: String {
        switch voiceService.state {
        case .idle: return ""
        case .recording: return "Listening..."
        case .processing: return "Processing..."
        case .playingResponse: return "\(persona.name) is speaking..."
        }
    }

    // MARK: - Persona Badge

    private var personaBadge: some View {
        HStack(spacing: 4) {
            Text(persona.displayEmoji)
                .font(.system(size: 16))
            Text(persona.name)
                .font(EW.Fonts.caption(11))
                .foregroundColor(EW.Colors.tealDark)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(EW.Colors.tealLight)
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func playChapter(_ chapter: Int) {
        currentChapter = chapter
        if let url = appState.apiService.audioStreamURL(bookTitle: book.title, chapter: chapter) {
            audioService.play(url: url)
        }
    }

    private func sendText() {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        textInput = ""
        showWelcome = false

        messages.append(ChatMessage(role: .user, content: text))

        Task {
            await sendChatMessage(text)
        }
    }

    private func sendChatMessage(_ text: String) async {
        do {
            if let token = appState.authToken {
                await appState.apiService.setAuthToken(token)
            }

            // Use the text chat endpoint
            let body: [String: Any] = [
                "book_id": book.title,
                "chapter": currentChapter,
                "timestamp_seconds": audioService.currentTime,
                "persona_id": persona.id,
                "message": text,
                "conversation_history": messages.suffix(10).map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] },
                "stream": false
            ]

            let response = try await appState.apiService.textChat(body: body)
            messages.append(ChatMessage(role: .assistant, content: response))
        } catch {
            messages.append(ChatMessage(role: .assistant, content: "I'm having trouble connecting. Make sure the server is running."))
        }
    }

    private func handleMicTap() {
        switch voiceService.state {
        case .idle:
            Task { try? await voiceService.startRecording() }
        case .recording:
            Task { await sendVoiceMessage() }
        default:
            break
        }
    }

    private func sendVoiceMessage() async {
        guard let audioData = voiceService.stopRecording() else { return }
        showWelcome = false

        do {
            if let token = appState.authToken {
                await appState.apiService.setAuthToken(token)
            }

            let response = try await appState.apiService.voiceChat(
                audioData: audioData,
                bookId: book.id,
                chapter: currentChapter,
                timestamp: audioService.currentTime,
                personaId: persona.id
            )

            messages.append(ChatMessage(role: .user, content: response.transcription))
            messages.append(ChatMessage(role: .assistant, content: response.responseText))

            if let audio = response.responseAudioBase64 {
                try await voiceService.playAudioResponse(audio)
            }
        } catch {
            messages.append(ChatMessage(role: .assistant, content: "Couldn't process your voice message. Try typing instead."))
        }

        voiceService.reset()
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: ChatMessage
    let personaName: String

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Text(message.content)
                .font(EW.Fonts.body(14))
                .padding(12)
                .background(message.role == .user ? EW.Colors.teal : EW.Colors.surface)
                .foregroundColor(message.role == .user ? .white : EW.Colors.dark)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
                .shadow(color: message.role == .assistant ? .black.opacity(0.04) : .clear, radius: 3, x: 0, y: 1)

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Chapter Picker Sheet

struct ChapterPickerSheet: View {
    let totalChapters: Int
    @Binding var currentChapter: Int
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(1...totalChapters, id: \.self) { number in
                Button {
                    onSelect(number)
                    dismiss()
                } label: {
                    HStack {
                        Text("Chapter \(number)")
                            .font(EW.Fonts.body())
                            .foregroundColor(EW.Colors.dark)
                        Spacer()
                        if number == currentChapter {
                            Image(systemName: "checkmark")
                                .foregroundColor(EW.Colors.teal)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EW.Colors.teal)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlayerChatView(
            book: FallbackData.books[0],
            persona: FallbackData.personas[0]
        )
    }
    .environmentObject(AppState())
}
