import SwiftUI

struct GameInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String        // SF Symbol name
    let accentColor: Color
    let gameType: GameType
    let entryTiers: [EntryTier]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GameInfo, rhs: GameInfo) -> Bool {
        lhs.id == rhs.id
    }
}

enum GameType: String, Codable {
    case solsnake
    case rocketsol
    case drivehard
    case warp
    case dropfusion
    case bountyboard
}

struct EntryTier: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let amount: Double
    let playerCount: String

    var formattedAmount: String {
        if amount < 0.01 {
            return "FREE"
        }
        return "\(amount) SOL"
    }
}

// MARK: - Game Definitions (matching Next.js frontend)
extension GameInfo {
    static let allGames: [GameInfo] = [
        GameInfo(
            id: "solsnake",
            name: "SolSnake",
            description: "Multiplayer snake arena. Eat, grow, and dominate.",
            icon: "circle.grid.3x3.fill",
            accentColor: .lavSnakeGreen,
            gameType: .solsnake,
            entryTiers: [
                EntryTier(label: "Arena", amount: 0.02, playerCount: "24 Players"),
                EntryTier(label: "Super Mass", amount: 0.1, playerCount: "8 Players"),
                EntryTier(label: "Super Mass", amount: 0.3, playerCount: "8 Players"),
                EntryTier(label: "Super Mass", amount: 0.5, playerCount: "8 Players"),
                EntryTier(label: "Super Mass", amount: 1.0, playerCount: "8 Players")
            ]
        ),
        GameInfo(
            id: "rocketsol",
            name: "Rocket Sol",
            description: "Launch your rocket higher than your opponent.",
            icon: "flame.fill",
            accentColor: .lavRocketOrange,
            gameType: .rocketsol,
            entryTiers: EntryTier.standard1v1Tiers
        ),
        GameInfo(
            id: "drivehard",
            name: "Drive Hard",
            description: "Race through obstacles in this 1v1 driving challenge.",
            icon: "car.fill",
            accentColor: .lavDriveBlue,
            gameType: .drivehard,
            entryTiers: EntryTier.standard1v1Tiers
        ),
        GameInfo(
            id: "warp",
            name: "Warp",
            description: "Navigate through warp tunnels faster than your rival.",
            icon: "waveform.path",
            accentColor: .lavWarpPurple,
            gameType: .warp,
            entryTiers: EntryTier.standard1v1Tiers
        ),
        GameInfo(
            id: "dropfusion",
            name: "Drop Fusion",
            description: "Merge and drop pieces to outscore your opponent.",
            icon: "drop.fill",
            accentColor: .lavDropCyan,
            gameType: .dropfusion,
            entryTiers: EntryTier.standard1v1Tiers
        ),
        GameInfo(
            id: "bountyboard",
            name: "Bounty Board",
            description: "Compete in bounty challenges for SOL rewards.",
            icon: "target",
            accentColor: .lavBountyYellow,
            gameType: .bountyboard,
            entryTiers: EntryTier.standard1v1Tiers
        )
    ]
}

extension EntryTier {
    static let standard1v1Tiers: [EntryTier] = [
        EntryTier(label: "Practice", amount: 0.01, playerCount: "1v1"),
        EntryTier(label: "Casual", amount: 0.05, playerCount: "1v1"),
        EntryTier(label: "Standard", amount: 0.1, playerCount: "1v1"),
        EntryTier(label: "Pro", amount: 0.25, playerCount: "1v1"),
        EntryTier(label: "High Roller", amount: 0.5, playerCount: "1v1")
    ]
}

// MARK: - Challenge/Match Models
struct PaymentResponse: Decodable {
    let success: Bool
    let txSignature: String?
    let timestamp: Int?
    let verificationToken: String?
    let error: String?
    let code: String?

    enum CodingKeys: String, CodingKey {
        case success
        case txSignature = "tx_signature"
        case timestamp
        case verificationToken = "verification_token"
        case error
        case code
    }
}

struct JoinMatchRequest: Encodable {
    let gameId: String
    let gameType: String
    let entryAmount: Double
    let escrowTxSignature: String
    let paymentTimestamp: Int
    let verificationToken: String

    enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case gameType = "game_type"
        case entryAmount = "entry_amount"
        case escrowTxSignature = "escrow_tx_signature"
        case paymentTimestamp = "payment_timestamp"
        case verificationToken = "verification_token"
    }
}

struct JoinMatchResponse: Decodable {
    let match: MatchData
}

struct MatchData: Decodable {
    let id: String
    let seed: String?
    let isCreator: Bool?
    let scoreToBeat: Int?
    let opponentWallet: String?
    let entryAmount: Double?
    let obstacleDataRaw: AnyCodable?

    var obstacleDataJSON: String? {
        guard let raw = obstacleDataRaw else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: raw.value),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    enum CodingKeys: String, CodingKey {
        case id
        case seed
        case isCreator = "is_creator"
        case scoreToBeat = "score_to_beat"
        case opponentWallet = "opponent_wallet"
        case entryAmount = "entry_amount"
        case obstacleDataRaw = "obstacle_data"
    }
}

struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map { $0.value }
        } else if let str = try? container.decode(String.self) {
            value = str
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let dbl = try? container.decode(Double.self) {
            value = dbl
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = NSNull()
        }
    }
}

struct SubmitScoreRequest: Encodable {
    let score: Int
    let gameDurationMs: Int
    let inputRecording: [InputRecord]
    let scoreBreakdown: [String: Int]?
    let obstacleData: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case score
        case gameDurationMs = "game_duration_ms"
        case inputRecording = "input_recording"
        case scoreBreakdown = "score_breakdown"
        case obstacleData = "obstacle_data"
    }
}

struct InputRecord: Encodable {
    let frame: Int
    let lane: Int?
}

extension AnyCodable: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let dict = value as? [String: Any] {
            let data = try JSONSerialization.data(withJSONObject: dict)
            let json = try JSONDecoder().decode(JSONValue.self, from: data)
            try container.encode(json)
        } else if let arr = value as? [Any] {
            let data = try JSONSerialization.data(withJSONObject: arr)
            let json = try JSONDecoder().decode(JSONValue.self, from: data)
            try container.encode(json)
        } else if let str = value as? String {
            try container.encode(str)
        } else if let num = value as? Double {
            try container.encode(num)
        } else if let num = value as? Int {
            try container.encode(num)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}

private enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Double.self) { self = .number(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode([JSONValue].self) { self = .array(v) }
        else if let v = try? container.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

struct SubmitScoreResponse: Decodable {
    let success: Bool?
    let result: String?
    let payout: Double?
    let error: String?
    let match: SubmitMatchInfo?
}

struct SubmitMatchInfo: Decodable {
    let status: String?
    let youWon: Bool?
    let payoutAmount: Double?

    enum CodingKeys: String, CodingKey {
        case status
        case youWon = "you_won"
        case payoutAmount = "payout_amount"
    }
}

struct WaitingCountsResponse: Decodable {
    let counts: [String: Int]?
}

struct EarningsStats: Decodable {
    let totalEarnings: Double?
    let totalGames: Int?
    let winRate: Double?
    let tier: String?
    let wins: Int?
    let losses: Int?
    let bestStreak: Int?
    let currentStreak: Int?
    let biggestWin: Double?
    let todayEarnings: Double?
    let weekEarnings: Double?
    let percentile: Double?
    let rank: Int?
}
