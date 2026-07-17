import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit

// MARK: - Auth State
enum AuthState {
    case loading
    case signedOut
    case signedIn(User)
}

// MARK: - Auth Error
enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case wrongPassword
    case userNotFound
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:       return "Format email tidak valid."
        case .weakPassword:       return "Password minimal 6 karakter."
        case .emailAlreadyInUse:  return "Email sudah digunakan akun lain."
        case .wrongPassword:      return "Password salah. Coba lagi."
        case .userNotFound:       return "Akun tidak ditemukan."
        case .networkError:       return "Periksa koneksi internet Anda."
        case .unknown(let msg):   return msg
        }
    }
}

// MARK: - Auth Manager
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var authState: AuthState = .loading
    @Published var currentUser: User? = nil

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    private init() {
        startListening()
    }

    // MARK: - Listener
    private func startListening() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                self.authState = .signedIn(user)
                self.currentUser = user
                
                // Sync user profile to Firestore
                FirebaseManager.shared.syncUserProfile(user: user)
            } else {
                self.authState = .signedOut
                self.currentUser = nil
            }
        }
    }

    var isSignedIn: Bool {
        if case .signedIn = authState { return true }
        return false
    }

    var displayName: String {
        currentUser?.displayName ?? currentUser?.email ?? "User"
    }

    var userInitial: String {
        String((currentUser?.displayName ?? currentUser?.email ?? "U").prefix(1)).uppercased()
    }

    // MARK: - Email / Password
    func signUp(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            authState = .signedIn(result.user)
        } catch let error as NSError {
            throw mapError(error)
        }
    }

    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            authState = .signedIn(result.user)
        } catch let error as NSError {
            throw mapError(error)
        }
    }

    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Phone Auth
    func sendOTP(to phoneNumber: String) async throws -> String {
        let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil)
        return verificationID
    }

    func verifyOTP(verificationID: String, code: String) async throws {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        let result = try await Auth.auth().signIn(with: credential)
        authState = .signedIn(result.user)
    }

    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
        authState = .signedOut
        currentUser = nil
    }

    // MARK: - Error Mapping
    private func mapError(_ error: NSError) -> AuthError {
        let code = AuthErrorCode.Code(rawValue: error.code)
        switch code {
        case .invalidEmail:         return .invalidEmail
        case .weakPassword:         return .weakPassword
        case .emailAlreadyInUse:    return .emailAlreadyInUse
        case .wrongPassword:        return .wrongPassword
        case .userNotFound:         return .userNotFound
        case .networkError:         return .networkError
        default:                    return .unknown(error.localizedDescription)
        }
    }
}
