import Foundation

struct User: Codable, Identifiable {
    let id: String
    let walletAddress: String?
    let username: String?
    let email: String?
    let emailVerified: Bool?
    let telegramId: String?
    let firstName: String?
    let photoUrl: String?
    let isActive: Bool?
    let tosAccepted: Bool?
    let walletVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case walletAddress = "wallet_address"
        case username
        case email
        case emailVerified = "email_verified"
        case telegramId = "telegram_id"
        case firstName = "first_name"
        case photoUrl = "photo_url"
        case isActive = "is_active"
        case tosAccepted = "tos_accepted"
        case walletVerified = "wallet_verified"
    }
}

struct LoginRequest: Encodable {
    let identifier: String
    let password: String
}

struct LoginResponse: Decodable {
    let success: Bool
    let user: User?
    let message: String?
    let code: String?
    let remainingSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case success
        case user
        case message
        case code
        case remainingSeconds = "remaining_seconds"
    }
}

struct AuthCheckResponse: Decodable {
    let success: Bool
    let user: User?
}

// MARK: - Signup Models

struct SignupRequest: Encodable {
    let email: String
    let username: String
    let password: String
    let tosAccepted: Bool

    enum CodingKeys: String, CodingKey {
        case email, username, password
        case tosAccepted = "tos_accepted"
    }
}

struct SignupResponse: Decodable {
    let success: Bool?
    let user: User?
    let walletPrivateKey: String?
    let walletAddress: String?
    let error: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success, user, error, message
        case walletPrivateKey = "wallet_private_key"
        case walletAddress = "wallet_address"
    }
}

struct AvailabilityResponse: Decodable {
    let available: Bool
    let error: String?
}

struct ResendVerificationResponse: Decodable {
    let success: Bool?
    let error: String?
    let code: String?
}