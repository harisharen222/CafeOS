import Foundation
import Combine
import FirebaseAuth

enum AuthError: LocalizedError {
    case wrongCredentials, userNotFound, invalidEmail, networkError, emailInUse, weakPassword, unknown(String)
    var errorDescription: String? {
        switch self {
        case .wrongCredentials: return "Incorrect email or password."
        case .userNotFound:     return "No account found with this email."
        case .invalidEmail:     return "Please enter a valid email address."
        case .networkError:     return "No internet connection."
        case .emailInUse:       return "An account with this email already exists."
        case .weakPassword:     return "Password must be at least 6 characters."
        case .unknown(let m):   return m
        }
    }
    static func from(_ error: Error) -> AuthError {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .wrongPassword, .invalidCredential: return .wrongCredentials
        case .userNotFound:                      return .userNotFound
        case .invalidEmail:                      return .invalidEmail
        case .networkError:                      return .networkError
        case .emailAlreadyInUse:                 return .emailInUse
        case .weakPassword:                      return .weakPassword
        default:                                 return .unknown(error.localizedDescription)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoadingAuth: Bool = true
    @Published var currentUserEmail: String? = nil

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthChanges()
    }

    private func listenToAuthChanges() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isLoggedIn = (user != nil)
                self?.currentUserEmail = user?.email
                self?.isLoadingAuth = false
            }
        }
    }

    func login(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
}
