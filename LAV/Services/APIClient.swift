import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case unauthorized
    case accountLocked(remainingSeconds: Int)
    case emailNotVerified
    case tosNotAccepted
    case insufficientBalance
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .accountLocked(let seconds):
            let minutes = seconds / 60
            return "Account locked. Try again in \(minutes > 0 ? "\(minutes) min" : "\(seconds)s")."
        case .emailNotVerified:
            return "Please verify your email first."
        case .tosNotAccepted:
            return "Please accept the Terms of Service."
        case .insufficientBalance:
            return "Not enough funds for this entry."
        case .networkError:
            return "Unable to connect. Check your internet."
        case .httpError(_, let message):
            return message ?? "Something went wrong. Please try again."
        default:
            return "Something went wrong. Please try again."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Config.requestTimeout
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = .shared
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    // MARK: - Generic Request

    func request<T: Decodable>(
        baseURL: String,
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        // Better Auth CSRF protection requires Origin header
        // iOS URLSession doesn't send it automatically like browsers do
        request.setValue("https://lav.bot", forHTTPHeaderField: "Origin")
        request.setValue("https://lav.bot/", forHTTPHeaderField: "Referer")

        if let timeout {
            request.timeoutInterval = timeout
        }

        // Attach session token as cookie if available
        if let token = KeychainManager.shared.sessionToken {
            let existing = request.value(forHTTPHeaderField: "Cookie") ?? ""
            let separator = existing.isEmpty ? "" : "; "
            request.setValue("\(existing)\(separator)session_token=\(token)", forHTTPHeaderField: "Cookie")
        }

        if let body {
            let bodyData = try JSONEncoder().encode(body)
            request.httpBody = bodyData
            if method == "POST" {
                print("[LAV API] \(method) \(path) body: \(String(data: bodyData, encoding: .utf8) ?? "nil")")
            }
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("[LAV API] Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Log every response for debugging
        let bodyString = String(data: data, encoding: .utf8) ?? "nil"
        print("[LAV API] \(method) \(path) -> \(httpResponse.statusCode): \(bodyString)")

        // Extract and store session token from Set-Cookie headers
        extractSessionToken(from: httpResponse)

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("[LAV API] Decode error: \(error)")
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.unauthorized
        default:
            let errorBody = try? decoder.decode(ErrorResponse.self, from: data)
            throw APIError.httpError(
                statusCode: httpResponse.statusCode,
                message: errorBody?.error ?? errorBody?.message ?? bodyString
            )
        }
    }

    // MARK: - Fire and Forget (for logout, etc.)

    func fireAndForget(baseURL: String, path: String, method: String = "DELETE") {
        guard let url = URL(string: baseURL + path) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 2
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://lav.bot", forHTTPHeaderField: "Origin")
        request.setValue("https://lav.bot/", forHTTPHeaderField: "Referer")

        if let token = KeychainManager.shared.sessionToken {
            request.setValue("session_token=\(token)", forHTTPHeaderField: "Cookie")
        }

        let req = request
        Task { try? await session.data(for: req) }
    }

    // MARK: - Cookie Extraction

    private func extractSessionToken(from response: HTTPURLResponse) {
        guard let headerFields = response.allHeaderFields as? [String: String],
              let url = response.url else { return }

        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        for cookie in cookies {
            if cookie.name == "session_token" {
                KeychainManager.shared.sessionToken = cookie.value
            }
        }
    }
}

private struct ErrorResponse: Decodable {
    let error: String?
    let message: String?
    let code: String?
}
