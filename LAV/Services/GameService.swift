import Foundation

final class GameService {
    static let shared = GameService()
    private let client = APIClient.shared
    private init() {}

    // MARK: - Pay for Game Entry
    // POST LAVSNIPE_URL/api/game/pay { game_id, amount_sol }

    func payEntry(gameId: String, amount: Double) async throws -> PaymentResponse {
        let body = PayEntryRequest(gameId: gameId, amountSol: amount)

        let response: PaymentResponse = try await client.request(
            baseURL: Config.lavsnipeURL,
            path: "/api/game/pay",
            method: "POST",
            body: body
        )

        if let code = response.code {
            switch code {
            case "email_not_verified": throw APIError.emailNotVerified
            case "tos_not_accepted": throw APIError.tosNotAccepted
            case "insufficient_balance": throw APIError.insufficientBalance
            default: break
            }
        }

        if let error = response.error {
            throw APIError.httpError(statusCode: 400, message: error)
        }

        return response
    }

    // MARK: - Join Match
    // POST LAVSNIPE_URL/api/challenges/join

    func joinMatch(request: JoinMatchRequest) async throws -> MatchData {
        let response: JoinMatchResponse = try await client.request(
            baseURL: Config.lavsnipeURL,
            path: "/api/challenges/join",
            method: "POST",
            body: request
        )
        return response.match
    }

    // MARK: - Submit Score
    // POST LAVSNIPE_URL/api/challenges/{matchId}/submit

    func submitScore(
        matchId: String,
        score: Int,
        durationMs: Int,
        inputRecording: [InputRecord],
        scoreBreakdown: [String: Int]? = nil,
        obstacleData: AnyCodable? = nil
    ) async throws -> SubmitScoreResponse {
        let body = SubmitScoreRequest(
            score: score,
            gameDurationMs: durationMs,
            inputRecording: inputRecording,
            scoreBreakdown: scoreBreakdown,
            obstacleData: obstacleData
        )
        return try await client.request(
            baseURL: Config.lavsnipeURL,
            path: "/api/challenges/\(matchId)/submit",
            method: "POST",
            body: body
        )
    }

    // MARK: - Get Waiting Counts
    // GET LAVSNIPE_URL/api/challenges/waiting-counts?game_type={type}

    func getWaitingCounts(gameType: String) async throws -> [String: Int] {
        let response: WaitingCountsResponse = try await client.request(
            baseURL: Config.lavsnipeURL,
            path: "/api/challenges/waiting-counts?game_type=\(gameType)"
        )
        return response.counts ?? [:]
    }

    // MARK: - Get Wallet Balance (Solana RPC)

    private static let solanaRPC = URL(string: "https://api.mainnet-beta.solana.com")!
    private static let lamportsPerSOL: Double = 1_000_000_000

    func getWalletBalance(walletAddress: String?, userId: String?) async throws -> Double {
        guard let walletAddress, !walletAddress.isEmpty else { return 0 }

        var request = URLRequest(url: Self.solanaRPC)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            SolanaRPCRequest(method: "getBalance", params: [walletAddress])
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SolanaBalanceResponse.self, from: data)
        return Double(response.result.value) / Self.lamportsPerSOL
    }

    // MARK: - Get Earnings Stats
    // GET API_URL/api/earnings/stats

    func getEarningsStats() async throws -> EarningsStats {
        try await client.request(
            baseURL: Config.apiURL,
            path: "/api/earnings/stats"
        )
    }
}

// MARK: - Solana RPC Models

private struct SolanaRPCRequest: Encodable {
    let jsonrpc = "2.0"
    let id = 1
    let method: String
    let params: [String]
}

private struct SolanaBalanceResponse: Decodable {
    let result: SolanaBalanceResult
}

private struct SolanaBalanceResult: Decodable {
    let value: UInt64
}

private struct PayEntryRequest: Encodable {
    let gameId: String
    let amountSol: Double

    enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case amountSol = "amount_sol"
    }
}
