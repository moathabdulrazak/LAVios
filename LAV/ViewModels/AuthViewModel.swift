import SwiftUI
import Observation

@Observable
final class AuthViewModel {
    var identifier = ""
    var password = ""
    var isAuthenticated = false
    var isLoading = false
    var isCheckingSession = true
    var errorMessage: String?
    var currentUser: User?
    var lockoutSeconds: Int = 0

    private let authService = AuthService.shared
    private var lockoutTimer: Timer?

    var isFormValid: Bool {
        !identifier.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    var isLockedOut: Bool {
        lockoutSeconds > 0
    }

    var lockoutDisplay: String {
        let min = lockoutSeconds / 60
        let sec = lockoutSeconds % 60
        return String(format: "%d:%02d", min, sec)
    }

    // MARK: - Check Existing Session

    @MainActor
    func checkSession() async {
        isCheckingSession = true
        defer { isCheckingSession = false }

        do {
            let user = try await authService.checkAuth()
            currentUser = user
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            currentUser = nil
        }
    }

    // MARK: - Password Login

    @MainActor
    func login() async {
        print("[LAV Auth] login() called")
        print("[LAV Auth] identifier: '\(identifier)' password length: \(password.count)")
        print("[LAV Auth] isFormValid: \(isFormValid)")

        guard isFormValid else {
            errorMessage = "Please enter your username and password."
            print("[LAV Auth] Form not valid, returning early")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.login(
                identifier: identifier.trimmingCharacters(in: .whitespaces),
                password: password
            )
            print("[LAV Auth] Login success! User: \(user.id)")
            currentUser = user
            isAuthenticated = true
            password = ""
        } catch let error as APIError {
            print("[LAV Auth] APIError: \(error)")
            switch error {
            case .accountLocked(let seconds):
                startLockoutTimer(seconds: seconds)
                errorMessage = error.errorDescription
            default:
                errorMessage = error.errorDescription
            }
        } catch {
            print("[LAV Auth] Unexpected error: \(error)")
            errorMessage = "An unexpected error occurred."
        }

        isLoading = false
    }

    // MARK: - Logout

    @MainActor
    func logout() {
        authService.logout()
        isAuthenticated = false
        currentUser = nil
        identifier = ""
        password = ""
        errorMessage = nil
    }

    // MARK: - Lockout Timer

    @MainActor
    private func startLockoutTimer(seconds: Int) {
        lockoutSeconds = seconds
        lockoutTimer?.invalidate()
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.lockoutSeconds > 0 {
                    self.lockoutSeconds -= 1
                } else {
                    self.lockoutTimer?.invalidate()
                    self.errorMessage = nil
                }
            }
        }
    }
}
