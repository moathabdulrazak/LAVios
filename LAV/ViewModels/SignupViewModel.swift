import SwiftUI
import Observation

@Observable
final class SignupViewModel {
    // Step tracking
    var step: SignupStep = .email

    // Fields
    var email = ""
    var username = ""
    var password = ""
    var confirmPassword = ""
    var tosAccepted = false

    // State
    var isLoading = false
    var errorMessage: String?

    // Availability checks
    var emailAvailable: Bool?
    var usernameAvailable: Bool?
    var checkingEmail = false
    var checkingUsername = false

    // Wallet
    var walletPublicKey: String?
    var walletPrivateKey: String?
    var privateKeyCopied = false

    // Verification
    var emailVerified = false
    var resendCooldown = 0

    private let authService = AuthService.shared
    private var emailCheckTask: Task<Void, Never>?
    private var usernameCheckTask: Task<Void, Never>?
    private var cooldownTimer: Timer?
    private var verificationTimer: Timer?

    enum SignupStep: Int, CaseIterable {
        case email = 1
        case profile = 2
        case wallet = 3
        case verify = 4
        case done = 5
    }

    // MARK: - Validation

    var passwordValidation: (minLength: Bool, hasUpper: Bool, hasLower: Bool, hasNumber: Bool) {
        (
            password.count >= 8,
            password.range(of: "[A-Z]", options: .regularExpression) != nil,
            password.range(of: "[a-z]", options: .regularExpression) != nil,
            password.range(of: "[0-9]", options: .regularExpression) != nil
        )
    }

    var isPasswordValid: Bool {
        let v = passwordValidation
        return v.minLength && v.hasUpper && v.hasLower && v.hasNumber
    }

    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    var isEmailStepValid: Bool {
        email.contains("@") && email.contains(".") && emailAvailable == true
    }

    var isProfileStepValid: Bool {
        username.count >= 3 &&
        usernameAvailable == true &&
        isPasswordValid &&
        passwordsMatch &&
        tosAccepted
    }

    // MARK: - Email Check (debounced)

    func emailChanged() {
        emailAvailable = nil
        emailCheckTask?.cancel()
        guard email.contains("@"), email.contains(".") else { return }

        checkingEmail = true
        emailCheckTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            do {
                emailAvailable = try await authService.checkEmailAvailability(email: email)
            } catch {
                emailAvailable = nil
            }
            checkingEmail = false
        }
    }

    // MARK: - Username Check (debounced)

    func usernameChanged() {
        usernameAvailable = nil
        usernameCheckTask?.cancel()
        guard username.count >= 3 else { return }

        checkingUsername = true
        usernameCheckTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            do {
                usernameAvailable = try await authService.checkUsernameAvailability(username: username)
            } catch {
                usernameAvailable = nil
            }
            checkingUsername = false
        }
    }

    // MARK: - Step 1: Email Continue

    @MainActor
    func continueWithEmail() async {
        guard isEmailStepValid else {
            errorMessage = "Please enter a valid email"
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            let available = try await authService.checkEmailAvailability(email: email)
            if !available {
                errorMessage = "Email already registered. Please login instead."
                isLoading = false
                return
            }
            isLoading = false
            step = .profile
        } catch {
            errorMessage = "Connection error. Please try again."
            isLoading = false
        }
    }

    // MARK: - Step 2: Create Account

    @MainActor
    func createAccount() async {
        guard isProfileStepValid else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await authService.signup(
                email: email,
                username: username,
                password: password
            )

            walletPublicKey = response.user?.walletAddress ?? response.walletAddress
            walletPrivateKey = response.walletPrivateKey

            isLoading = false
            step = .wallet
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
        } catch {
            errorMessage = "Connection error. Please try again."
            isLoading = false
        }
    }

    // MARK: - Step 3: Copy Key

    func copyPrivateKey() {
        guard let key = walletPrivateKey else { return }
        UIPasteboard.general.string = key
        privateKeyCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            privateKeyCopied = false
        }
    }

    // MARK: - Step 3 → 4: Continue to Verify

    func continueToVerify() {
        step = .verify
        startVerificationPolling()
        // Auto-send verification email
        Task { @MainActor in
            try? await authService.resendVerificationEmail()
            resendCooldown = 60
            startCooldownTimer()
        }
    }

    // MARK: - Step 4: Resend Email

    @MainActor
    func resendEmail() async {
        guard resendCooldown == 0 else { return }
        errorMessage = nil

        do {
            try await authService.resendVerificationEmail()
            resendCooldown = 60
            startCooldownTimer()
        } catch {
            errorMessage = "Failed to resend. Try again."
        }
    }

    // MARK: - Polling

    func startVerificationPolling() {
        verificationTimer?.invalidate()
        verificationTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.emailVerified else {
                    self?.verificationTimer?.invalidate()
                    return
                }
                do {
                    let user = try await self.authService.checkAuth()
                    if user.emailVerified == true {
                        self.emailVerified = true
                        self.verificationTimer?.invalidate()
                        try? await Task.sleep(for: .seconds(1))
                        self.step = .done
                    }
                } catch { }
            }
        }
    }

    @MainActor
    private func startCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.resendCooldown > 0 {
                    self.resendCooldown -= 1
                } else {
                    self.cooldownTimer?.invalidate()
                }
            }
        }
    }

    func cleanup() {
        verificationTimer?.invalidate()
        cooldownTimer?.invalidate()
        emailCheckTask?.cancel()
        usernameCheckTask?.cancel()
    }
}
