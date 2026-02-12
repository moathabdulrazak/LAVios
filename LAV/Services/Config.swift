import Foundation

enum Config {
    // MARK: - API Base URLs
    static let apiURL = "https://api.lav.bot"
    static let lavsnipeURL = "https://api.lav.bot"
    static let gameServerURL = "wss://slither.lav.bot"

    // MARK: - Timeouts
    static let requestTimeout: TimeInterval = 30
    static let authCheckTimeout: TimeInterval = 3

    // MARK: - Keychain
    static let keychainService = "com.lav.ios"
    static let sessionTokenKey = "session_token"
}
