import SwiftUI

/// The hero voice chat button - inspired by Sesame's voice-first UX
struct VoiceChatButton: View {
    let book: Book
    let chapter: Int
    let timestamp: TimeInterval

    @EnvironmentObject var appState: AppState
    @StateObject private var voiceService = VoiceService()
    @State private var selectedPersona: Persona?
    @State private var personas: [Persona] = []
    @State private var lastResponse: String?
    @State private var showPersonaPicker = false

    var body: some View {
        VStack(spacing: 16) {
            // Persona selector
            Button {
                showPersonaPicker = true
            } label: {
                HStack {
                    Text(selectedPersona?.displayEmoji ?? "🤖")
                    Text(selectedPersona?.name ?? "Choose Companion")
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())
            }
            .foregroundColor(.primary)

            // Main voice button
            VoiceRecordButton(
                state: voiceService.state,
                recordingTime: voiceService.recordingTime,
                onTap: handleVoiceButton
            )

            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Last response preview
            if let response = lastResponse {
                Text(response)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showPersonaPicker) {
            PersonaPickerView(
                personas: personas,
                selected: $selectedPersona
            )
        }
        .task {
            await loadPersonas()
        }
        .alert("Error", isPresented: .constant(voiceService.error != nil)) {
            Button("OK") { voiceService.reset() }
        } message: {
            Text(voiceService.error ?? "")
        }
    }

    private var statusText: String {
        switch voiceService.state {
        case .idle:
            return "Tap to ask \(selectedPersona?.name ?? "AI") about the book"
        case .recording:
            return "Listening... Tap to send"
        case .processing:
            return "Thinking..."
        case .playingResponse:
            return "\(selectedPersona?.name ?? "AI") is speaking..."
        }
    }

    private func handleVoiceButton() {
        switch voiceService.state {
        case .idle:
            Task {
                try? await voiceService.startRecording()
            }
        case .recording:
            Task {
                await sendVoiceChat()
            }
        case .processing, .playingResponse:
            // Can't interact during these states
            break
        }
    }

    private func sendVoiceChat() async {
        guard let audioData = voiceService.stopRecording() else { return }

        do {
            await appState.apiService.setAuthToken(appState.authToken)
            let response = try await appState.apiService.voiceChat(
                audioData: audioData,
                bookId: book.id,
                chapter: chapter,
                timestamp: timestamp,
                personaId: selectedPersona?.id
            )

            lastResponse = response.responseText

            // Play audio response
            if let audioBase64 = response.responseAudioBase64 {
                try await voiceService.playAudioResponse(audioBase64)
            }
        } catch {
            voiceService.error = error.localizedDescription
        }

        voiceService.reset()
    }

    private func loadPersonas() async {
        do {
            await appState.apiService.setAuthToken(appState.authToken)
            personas = try await appState.apiService.getPersonas(bookId: book.id)
            if selectedPersona == nil {
                selectedPersona = personas.first
            }
        } catch {
            print("Failed to load personas: \(error)")
        }
    }
}

/// Animated voice recording button
struct VoiceRecordButton: View {
    let state: VoiceService.RecordingState
    let recordingTime: TimeInterval
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle with animation
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 80, height: 80)
                    .scaleEffect(state == .recording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: state == .recording)

                // Icon or timer
                Group {
                    switch state {
                    case .idle:
                        Image(systemName: "mic.fill")
                            .font(.system(size: 30))
                    case .recording:
                        Text(formatTime(recordingTime))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                    case .processing:
                        ProgressView()
                            .scaleEffect(1.5)
                    case .playingResponse:
                        Image(systemName: "waveform")
                            .font(.system(size: 30))
                            .symbolEffect(.variableColor.iterative)
                    }
                }
                .foregroundColor(.white)
            }
        }
        .disabled(state == .processing || state == .playingResponse)
    }

    private var backgroundColor: Color {
        switch state {
        case .idle:
            return .accentColor
        case .recording:
            return .red
        case .processing:
            return .orange
        case .playingResponse:
            return .green
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d.%d", seconds, tenths)
    }
}

/// Full voice chat conversation view
struct VoiceChatView: View {
    let book: Book
    let chapter: Int
    let timestamp: TimeInterval

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var voiceService = VoiceService()

    @State private var messages: [ChatMessage] = []
    @State private var selectedPersona: Persona?
    @State private var personas: [Persona] = []
    @State private var textInput = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                MessageBubble(message: message, personaName: selectedPersona?.name)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastId = messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Input area
                VStack(spacing: 12) {
                    // Persona selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(personas) { persona in
                                PersonaChip(
                                    persona: persona,
                                    isSelected: selectedPersona?.id == persona.id,
                                    onTap: { selectedPersona = persona }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Voice and text input
                    HStack(spacing: 12) {
                        // Text field
                        TextField("Type a message...", text: $textInput)
                            .textFieldStyle(.roundedBorder)

                        // Send text
                        if !textInput.isEmpty {
                            Button {
                                sendTextMessage()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title)
                            }
                        }

                        // Voice button
                        VoiceRecordButton(
                            state: voiceService.state,
                            recordingTime: voiceService.recordingTime,
                            onTap: handleVoiceButton
                        )
                        .scaleEffect(0.8)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Chat with \(selectedPersona?.name ?? "AI")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadPersonas()
        }
    }

    private func handleVoiceButton() {
        switch voiceService.state {
        case .idle:
            Task { try? await voiceService.startRecording() }
        case .recording:
            Task { await sendVoiceMessage() }
        default:
            break
        }
    }

    private func sendTextMessage() {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: text))
        textInput = ""

        // TODO: Send to API and get response
        Task {
            // Simulated response for now
            try? await Task.sleep(for: .seconds(1))
            messages.append(ChatMessage(role: .assistant, content: "I heard your question about \"\(text)\". Let me think about that in the context of Chapter \(chapter)..."))
        }
    }

    private func sendVoiceMessage() async {
        guard let audioData = voiceService.stopRecording() else { return }

        do {
            await appState.apiService.setAuthToken(appState.authToken)
            let response = try await appState.apiService.voiceChat(
                audioData: audioData,
                bookId: book.id,
                chapter: chapter,
                timestamp: timestamp,
                personaId: selectedPersona?.id
            )

            messages.append(ChatMessage(role: .user, content: response.transcription))
            messages.append(ChatMessage(role: .assistant, content: response.responseText))

            if let audio = response.responseAudioBase64 {
                try await voiceService.playAudioResponse(audio)
            }
        } catch {
            voiceService.error = error.localizedDescription
        }

        voiceService.reset()
    }

    private func loadPersonas() async {
        do {
            await appState.apiService.setAuthToken(appState.authToken)
            personas = try await appState.apiService.getPersonas(bookId: book.id)
            selectedPersona = personas.first
        } catch {
            print("Failed to load personas: \(error)")
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let personaName: String?

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : (personaName ?? "AI"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.accentColor : Color.secondary.opacity(0.2))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if message.role == .assistant { Spacer() }
        }
    }
}

struct PersonaChip: View {
    let persona: Persona
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(persona.displayEmoji)
                Text(persona.name)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct PersonaPickerView: View {
    let personas: [Persona]
    @Binding var selected: Persona?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(personas) { persona in
                Button {
                    selected = persona
                    dismiss()
                } label: {
                    HStack {
                        Text(persona.displayEmoji)
                            .font(.title)
                        VStack(alignment: .leading) {
                            Text(persona.name)
                                .font(.headline)
                            Text(persona.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selected?.id == persona.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Choose Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
