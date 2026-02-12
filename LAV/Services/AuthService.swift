import Foundation

final class AuthService {
    static let shared = AuthService()
    private let client = APIClient.shared
    private init() {}

    // MARK: - Password Login
    // POST LAVSNIPE_URL/api/auth/login { identifier, password }

    func login(identifier: String, password: String) async throws -> User {
        let body = LoginRequest(identifier: identifier, password: password)

        let response: LoginResponse = try await client.request(
            baseURL: Config.lavsnipeURL,
            path: "/api/auth/login",
            method: "POST",
            body: body
        )

        if let code = response.code, code == "account_locked" {
            throw APIError.accountLocked(remainingSeconds: response.remainingSeconds ?? 60)
        }

        guard response.success, let user = response.user else {
            throw APIError.httpError(
                statusCode: 400,
                message: response.message ?? "Login failed"
            )
        }

        return user
    }

    // MARK: - Check Auth Session
    // GET API_URL/api/auth/me

    func checkAuth() async throws -> User {
        let response: AuthCheckResponse = try await client.request(
            baseURL: Config.apiURL,
            path: "/api/auth/me",
            timeout: Config.authCheckTimeout
        )

        guard response.success, let user = response.user else {
            throw APIError.unauthorized
        }

        return user
    }

    // MARK: - Signup
    // POST LAVSNIPE_URL/api/auth/signup { email, username, password, tos_accepted }

    func signup(email: String, username: String, password: String) async throws -> SignupResponse {
        let body = SignupRequest(email: email, username: username, password: password, tosAccepted: true)

        let response: SignupResponse = try await client.request(
            baseURL: Config.lavsnipeURL,
            path: "/api/auth/signup",
            method: "POST",
            body: body
        )

        if let error = response.error, !error.isEmpty {
            throw APIError.httpError(statusCode: 400, message: error)
        }

        return response
    }

    // MARK: - Check Email Availability

    func checkEmailAvailability(email: String) async throws -> Bool {
        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        let response: AvailabilityResponse = try await client.request(
            baseURL: Config.lavsnipeURL,
            path: "/api/auth/check/email?email=\(encoded)"
        )
        return response.available
    }

    // MARK: - Check Username Availability

    func checkUsernameAvailability(username: String) async throws -> Bool {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let response: AvailabilityResponse = try await client.request(
            baseURL: Config.lavsnipeURL,
            path: "/api/auth/check/username?username=\(encoded)"
        )
        return response.available
    }

    // MARK: - Resend Verification Email

    func resendVerificationEmail() async throws {
        let _: ResendVerificationResponse = try await client.request(
            baseURL: Config.lavsnipeURL,
            path: "/api/auth/resend-verification",
            method: "POST"
        )
    }

    // MARK: - Logout
    // DELETE API_URL/api/auth/logout

    func logout() {
        KeychainManager.shared.clearAll()
        client.fireAndForget(baseURL: Config.apiURL, path: "/api/auth/logout")

        // Clear cookies
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
}
