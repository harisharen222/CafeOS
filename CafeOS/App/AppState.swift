import Foundation
import Combine
import Firebase
import FirebaseAuth

@MainActor
class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUserID: String? = nil

    private var authListener: AuthStateDidChangeListenerHandle?

    init() { listenToAuthChanges() }

    func listenToAuthChanges() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isLoggedIn = user != nil
                self?.currentUserID = user?.uid
            }
        }
    }

    deinit {
        if let l = authListener {
            Auth.auth().removeStateDidChangeListener(l)
        }
    }
}
