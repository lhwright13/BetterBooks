import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var credits: Int = 0
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading) {
                            Text(appState.currentUser?.name ?? "User")
                                .font(.headline)
                            Text(appState.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Credits") {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.accentColor)
                        Text("Available Credits")
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("\(credits)")
                                .fontWeight(.bold)
                        }
                    }

                    Button {
                        // TODO: Open purchase credits flow
                    } label: {
                        Label("Buy More Credits", systemImage: "plus.circle")
                    }
                }

                Section("Settings") {
                    NavigationLink {
                        PlaybackSettingsView()
                    } label: {
                        Label("Playback", systemImage: "slider.horizontal.3")
                    }

                    NavigationLink {
                        VoiceSettingsView()
                    } label: {
                        Label("Voice Chat", systemImage: "mic.fill")
                    }

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                }

                Section("Support") {
                    Link(destination: URL(string: "https://betterbooks.app/help")!) {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }

                    Link(destination: URL(string: "https://betterbooks.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    Link(destination: URL(string: "https://betterbooks.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
            .refreshable {
                await loadCredits()
            }
        }
        .task {
            await loadCredits()
        }
    }

    private func loadCredits() async {
        isLoading = true
        do {
            await appState.apiService.setAuthToken(appState.authToken)
            credits = try await appState.apiService.getCredits()
        } catch {
            print("Failed to load credits: \(error)")
        }
        isLoading = false
    }
}

struct PlaybackSettingsView: View {
    @AppStorage("playbackSpeed") private var playbackSpeed = 1.0
    @AppStorage("skipForwardDuration") private var skipForwardDuration = 30
    @AppStorage("skipBackwardDuration") private var skipBackwardDuration = 15

    var body: some View {
        Form {
            Section("Speed") {
                Picker("Playback Speed", selection: $playbackSpeed) {
                    Text("0.5x").tag(0.5)
                    Text("0.75x").tag(0.75)
                    Text("1x").tag(1.0)
                    Text("1.25x").tag(1.25)
                    Text("1.5x").tag(1.5)
                    Text("2x").tag(2.0)
                }
                .pickerStyle(.segmented)
            }

            Section("Skip Duration") {
                Stepper("Skip forward: \(skipForwardDuration)s", value: $skipForwardDuration, in: 10...60, step: 5)
                Stepper("Skip backward: \(skipBackwardDuration)s", value: $skipBackwardDuration, in: 5...30, step: 5)
            }
        }
        .navigationTitle("Playback Settings")
    }
}

struct VoiceSettingsView: View {
    @AppStorage("voiceChatEnabled") private var voiceChatEnabled = true
    @AppStorage("autoPlayResponses") private var autoPlayResponses = true
    @AppStorage("preferredVoice") private var preferredVoice = "default"

    var body: some View {
        Form {
            Section {
                Toggle("Enable Voice Chat", isOn: $voiceChatEnabled)
                Toggle("Auto-play AI Responses", isOn: $autoPlayResponses)
            }

            Section("Voice") {
                Picker("Preferred AI Voice", selection: $preferredVoice) {
                    Text("Default").tag("default")
                    Text("Warm").tag("warm")
                    Text("Professional").tag("professional")
                }
            }
        }
        .navigationTitle("Voice Settings")
    }
}

struct NotificationSettingsView: View {
    @AppStorage("dailyReminder") private var dailyReminder = false
    @AppStorage("newBookNotifications") private var newBookNotifications = true

    var body: some View {
        Form {
            Section {
                Toggle("Daily Listening Reminder", isOn: $dailyReminder)
                Toggle("New Book Releases", isOn: $newBookNotifications)
            }
        }
        .navigationTitle("Notifications")
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
