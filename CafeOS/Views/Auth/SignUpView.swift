import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    @FocusState private var focusedField: Field?
    enum Field { case email, password, confirm }

    private var isFormValid: Bool {
        email.contains("@") && email.contains(".") &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.brown)
                        Text("Create Account").font(.title2.bold())
                        Text("Join CafeOS to manage your café")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    if let err = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(err).font(.subheadline)
                            Spacer()
                            Button { errorMessage = nil } label: { Image(systemName: "xmark") }
                        }
                        .padding().foregroundColor(.white)
                        .background(Color.red.cornerRadius(10))
                        .padding(.horizontal)
                    }

                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Email address", text: $email)
                                .keyboardType(.emailAddress).autocapitalization(.none)
                                .textContentType(.emailAddress)
                                .focused($focusedField, equals: .email)
                                .padding().background(Color(.secondarySystemBackground)).cornerRadius(10)
                            if !email.isEmpty && (!email.contains("@") || !email.contains(".")) && focusedField != .email {
                                Text("Enter a valid email address.").font(.caption).foregroundStyle(.red).padding(.leading, 4)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            SecureField("Password (min 6 chars)", text: $password)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .password)
                                .padding().background(Color(.secondarySystemBackground)).cornerRadius(10)
                            if !password.isEmpty && password.count < 6 && focusedField != .password {
                                Text("Password must be at least 6 characters.").font(.caption).foregroundStyle(.red).padding(.leading, 4)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .confirm)
                                .padding().background(Color(.secondarySystemBackground)).cornerRadius(10)
                            if !confirmPassword.isEmpty && password != confirmPassword && focusedField != .confirm {
                                Text("Passwords do not match.").font(.caption).foregroundStyle(.red).padding(.leading, 4)
                            }
                        }

                        Button {
                            signUp()
                        } label: {
                            Group {
                                if isLoading { ProgressView().tint(.white) }
                                else { Text("Create Account").fontWeight(.semibold) }
                            }
                            .frame(maxWidth: .infinity).frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent).tint(.brown)
                        .disabled(!isFormValid || isLoading)
                    }
                    .padding(.horizontal)

                    Button("Already have an account? Sign In") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func signUp() {
        isLoading = true; errorMessage = nil
        Task {
            do {
                try await appState.signUp(email: email, password: password)
                // Auth listener auto-routes to MainTabView
            } catch let error as NSError {
                errorMessage = authErrorMessage(from: error)
            }
            isLoading = false
        }
    }

    private func authErrorMessage(from error: Error) -> String {
        AuthError.from(error).errorDescription ?? "Sign up failed. Please try again."
    }
}
