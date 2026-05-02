import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showSignUp = false

    @FocusState private var focusedField: Field?
    enum Field { case email, password }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 1
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 40)

                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.brown)
                    Text("CafeOS")
                        .font(.largeTitle.bold())
                    Text("Manage your café smarter")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Error banner
                if let err = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err).font(.subheadline)
                        Spacer()
                        Button { errorMessage = nil } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.red.cornerRadius(10))
                    .padding(.horizontal)
                }

                // Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Email address", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        if email.trimmingCharacters(in: .whitespaces).isEmpty && focusedField != .email && !email.isEmpty == false {
                            Text("Enter a valid email address.").font(.caption).foregroundStyle(.red).padding(.leading, 4)
                        }
                    }

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    Button {
                        login()
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In").fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brown)
                    .disabled(!isFormValid || isLoading)
                }
                .padding(.horizontal)

                // Sign up link
                Button {
                    showSignUp = true
                } label: {
                    Text("Don't have an account? ")
                        .foregroundStyle(.secondary) +
                    Text("Sign Up")
                        .foregroundStyle(.brown)
                        .fontWeight(.semibold)
                }
                .sheet(isPresented: $showSignUp) {
                    SignUpView()
                }

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    private func login() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await appState.login(email: email, password: password)
            } catch let error as NSError {
                errorMessage = authErrorMessage(from: error)
            }
            isLoading = false
        }
    }

    private func authErrorMessage(from error: Error) -> String {
        AuthError.from(error).errorDescription ?? "Login failed. Please try again."
    }
}
