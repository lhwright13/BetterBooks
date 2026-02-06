import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo and title
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text("BetterBooks")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("AI-powered audiobook companions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Form
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Name (optional)", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }

                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)

                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await authenticate() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSignUp ? "Create Account" : "Sign In")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 32)

                // Toggle sign in / sign up
                Button {
                    withAnimation {
                        isSignUp.toggle()
                        error = nil
                    }
                } label: {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.footnote)
                }

                Spacer()
            }
        }
    }

    private func authenticate() async {
        isLoading = true
        error = nil

        do {
            if isSignUp {
                try await appState.login(email: email, password: password)
                // For signup, we'd call signup endpoint but login works for now
            } else {
                try await appState.login(email: email, password: password)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    AuthView()
        .environmentObject(AppState())
}
