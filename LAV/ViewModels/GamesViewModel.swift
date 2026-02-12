import SwiftUI
import Observation

@Observable
final class GamesViewModel {
    var games = GameInfo.allGames
    var selectedGame: GameInfo?
    var selectedTier: EntryTier?
    var earnings: EarningsStats?
    var walletBalance: Double = 0.0
    var isLoadingBalance = false
    var isLoadingEarnings = false

    // Match flow state
    var isJoining = false
    var isSubmitting = false
    var matchData: MatchData?
    var matchResult: MatchResult?
    var errorMessage: String?
    var lastGameScore: Int = 0
    var lastGameDurationMs: Int = 0
    var lastInputRecording: [InputRecord] = []
    var lastScoreBreakdown: [String: Int]? = nil

    // Waiting counts per game type
    var waitingCounts: [String: Int] = [:]

    private let gameService = GameService.shared

    // MARK: - Load Earnings

    @MainActor
    func loadEarnings() async {
        isLoadingEarnings = true
        do {
            earnings = try await gameService.getEarningsStats()
        } catch {
            print("[LAV] Failed to load earnings: \(error)")
        }
        isLoadingEarnings = false
    }

    // MARK: - Load Wallet Balance

    private var balanceRefreshTask: Task<Void, Never>?

    @MainActor
    func loadWalletBalance(walletAddress: String?, userId: String?) async {
        isLoadingBalance = true
        do {
            let balance = try await gameService.getWalletBalance(
                walletAddress: walletAddress,
                userId: userId
            )
            walletBalance = balance
        } catch {
            print("[LAV] Failed to load wallet balance: \(error)")
        }
        isLoadingBalance = false
    }

    /// Start polling wallet balance every 15 seconds
    @MainActor
    func startBalanceRefresh(walletAddress: String?, userId: String?) {
        stopBalanceRefresh()
        balanceRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.loadWalletBalance(walletAddress: walletAddress, userId: userId)
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stopBalanceRefresh() {
        balanceRefreshTask?.cancel()
        balanceRefreshTask = nil
    }

    // MARK: - Load Waiting Counts

    @MainActor
    func loadWaitingCounts(for gameType: String) async {
        do {
            waitingCounts = try await gameService.getWaitingCounts(gameType: gameType)
        } catch {
            // Non-critical
        }
    }

    // MARK: - Join Game Flow

    @MainActor
    func joinGame(game: GameInfo, tier: EntryTier) async {
        isJoining = true
        errorMessage = nil
        matchResult = nil

        print("[LAV Game] Starting join flow: \(game.id) tier=\(tier.label) amount=\(tier.amount)")

        do {
            print("[LAV Game] Paying entry...")
            let payment = try await gameService.payEntry(
                gameId: game.id,
                amount: tier.amount
            )
            print("[LAV Game] Payment response: success=\(payment.success) sig=\(payment.txSignature ?? "nil") ts=\(payment.timestamp.map(String.init) ?? "nil")")

            guard let signature = payment.txSignature,
                  let timestamp = payment.timestamp,
                  let token = payment.verificationToken else {
                print("[LAV Game] Payment missing fields: sig=\(payment.txSignature ?? "nil") ts=\(payment.timestamp.map(String.init) ?? "nil") token=\(payment.verificationToken ?? "nil")")
                throw APIError.httpError(statusCode: 400, message: "Payment processing failed.")
            }

            let joinRequest = JoinMatchRequest(
                gameId: game.id,
                gameType: game.gameType.rawValue,
                entryAmount: tier.amount,
                escrowTxSignature: signature,
                paymentTimestamp: timestamp,
                verificationToken: token
            )

            print("[LAV Game] Joining match...")
            matchData = try await gameService.joinMatch(request: joinRequest)
            print("[LAV Game] Match joined: id=\(matchData?.id ?? "nil") seed=\(matchData?.seed ?? "nil") isCreator=\(matchData?.isCreator.map { String($0) } ?? "nil") scoreToBeat=\(matchData?.scoreToBeat.map { String($0) } ?? "nil")")

        } catch let error as APIError {
            print("[LAV Game] API error: \(error.errorDescription ?? "unknown")")
            errorMessage = error.errorDescription
        } catch {
            print("[LAV Game] Error: \(error)")
            errorMessage = "Failed to join game."
        }

        isJoining = false
    }

    // MARK: - Submit Score

    @MainActor
    func submitScore() async {
        guard let matchId = matchData?.id else {
            print("[LAV Game] No match data, skipping score submission")
            return
        }

        isSubmitting = true
        print("[LAV Game] Submitting score: \(lastGameScore) duration: \(lastGameDurationMs)ms matchId: \(matchId) inputs: \(lastInputRecording.count)")

        do {
            let response = try await gameService.submitScore(
                matchId: matchId,
                score: lastGameScore,
                durationMs: lastGameDurationMs,
                inputRecording: lastInputRecording,
                scoreBreakdown: lastScoreBreakdown,
                obstacleData: matchData?.obstacleDataRaw
            )

            print("[LAV Game] Submit response: success=\(response.success ?? false) result=\(response.result ?? "nil") payout=\(response.payout.map { String($0) } ?? "nil") match.status=\(response.match?.status ?? "nil") match.youWon=\(response.match?.youWon.map { String($0) } ?? "nil")")

            // Handle both response formats:
            // Format 1: { success, result: "win"/"loss"/"waiting", payout }
            // Format 2: { match: { status: "completed", you_won: true, payout_amount } }
            if let match = response.match {
                if match.status == "completed" {
                    if match.youWon == true {
                        matchResult = .win(payout: match.payoutAmount ?? 0)
                    } else {
                        matchResult = .loss
                    }
                } else {
                    matchResult = .waiting
                }
            } else if response.success == true {
                switch response.result {
                case "win":
                    matchResult = .win(payout: response.payout ?? 0)
                case "loss":
                    matchResult = .loss
                default:
                    matchResult = .waiting
                }
            } else {
                print("[LAV Game] Submit failed: \(response.error ?? "unknown")")
                matchResult = .waiting
            }
        } catch {
            print("[LAV Game] Submit error: \(error)")
            errorMessage = "Failed to submit score."
        }

        isSubmitting = false
    }

    // MARK: - Reset Match State

    func resetMatch() {
        matchData = nil
        matchResult = nil
        selectedTier = nil
        errorMessage = nil
        lastGameScore = 0
        lastGameDurationMs = 0
        lastInputRecording = []
        lastScoreBreakdown = nil
    }
}

enum MatchResult: Equatable {
    case waiting
    case win(payout: Double)
    case loss
}
