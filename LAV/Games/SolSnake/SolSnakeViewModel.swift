import SwiftUI
import Observation

@Observable
final class SolSnakeViewModel {

    // MARK: - Game State

    var score: Int = 0
    var length: Int = 10
    var killCount: Int = 0
    var isBoosting = false
    var isAlive = true
    var gameStarted = false
    var showEndScreen = false
    var showDeathFlash = false
    var leaderboard: [LeaderboardEntry] = []
    var highScore: Int = 0
    var killerName: String = ""

    // MARK: - Online Mode

    var isOnlineMode = false
    var connectionState: SolSnakeNetworkManager.ConnectionState = .disconnected
    var killNotifications: [KillNotification] = []
    var latency: Int = 0

    // Debug info
    var debugPlayerCount: Int = 0
    var debugOrbCount: Int = 0
    var debugSchemaInfo: String = "none"

    var debugConnectionState: String {
        switch connectionState {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .lobby(let n): return "lobby(\(n))"
        case .countdown(let s): return "countdown(\(s))"
        case .playing: return "playing"
        case .gameEnded: return "ended"
        case .error(let msg): return "ERR: \(msg.prefix(30))"
        }
    }

    // Scene reference
    weak var scene: SolSnakeScene?

    // Network manager (online mode only)
    private var networkManager: SolSnakeNetworkManager?

    // MARK: - Setup

    func setup() {
        if isOnlineMode {
            setupOnline()
        } else {
            setupOffline()
        }
    }

    private func setupOffline() {
        scene?.isOnlineMode = false
        scene?.onScoreChange = { [weak self] s in
            self?.score = s
        }
        scene?.onLengthChange = { [weak self] l in
            self?.length = l
        }
        scene?.onKill = { [weak self] name in
            guard let self else { return }
            self.killCount += 1
        }
        scene?.onDeath = { [weak self] killer in
            self?.handleDeath(killerName: killer)
        }
        scene?.onLeaderboardChange = { [weak self] lb in
            self?.leaderboard = lb
        }
    }

    private func setupOnline() {
        scene?.isOnlineMode = true

        let manager = SolSnakeNetworkManager()
        networkManager = manager

        // Wire network callbacks
        manager.onStateUpdate = { [weak self] in
            self?.handleServerStateUpdate()
        }

        manager.onGameStart = { [weak self] in
            guard let self, let manager = self.networkManager else { return }
            self.gameStarted = true
            self.isAlive = true
            self.scene?.startOnlineGame(localId: manager.localSessionId)
        }

        manager.onPlayerDeath = { [weak self] killer in
            self?.handleDeath(killerName: killer)
        }

        manager.onPlayerKill = { [weak self] notification in
            self?.killCount += 1
            self?.killNotifications = self?.networkManager?.killNotifications ?? []
        }

        manager.onLeaderboardUpdate = { [weak self] lb in
            self?.leaderboard = lb
        }

        manager.onGameEnd = { [weak self] in
            self?.connectionState = .gameEnded
        }
    }

    // MARK: - Online Connection

    func connectToServer(playerName: String = "Player", skin: Int = 0, mode: String = "sandbox", entryAmount: Double = 0, txSignature: String? = nil, verificationToken: String? = nil, walletAddress: String = "", paymentTimestamp: Int? = nil) {
        guard isOnlineMode, let manager = networkManager else { return }

        connectionState = .connecting

        Task { @MainActor in
            do {
                try await manager.connect(
                    playerName: playerName,
                    skin: skin,
                    mode: mode,
                    entryAmount: entryAmount,
                    walletAddress: walletAddress,
                    txSignature: txSignature,
                    verificationToken: verificationToken,
                    paymentTimestamp: paymentTimestamp
                )
                connectionState = manager.connectionState
            } catch {
                print("[SolSnakeVM] Connection failed: \(error)")
                connectionState = .error(error.localizedDescription)
            }
        }
    }

    func disconnectFromServer() {
        networkManager?.disconnect()
        networkManager = nil
        connectionState = .disconnected
    }

    // MARK: - Game Control

    func startGame() {
        score = 0
        length = 10
        killCount = 0
        isBoosting = false
        isAlive = true
        showEndScreen = false
        showDeathFlash = false
        killerName = ""
        gameStarted = true

        if isOnlineMode {
            // Online: game starts when server says so (handled by onGameStart callback)
            // Just reset UI state here
        } else {
            scene?.startGame()
        }
    }

    func sendInput(dirX: Float, dirY: Float, isBoosting: Bool) {
        if isOnlineMode {
            // Online: send input to server
            guard let manager = networkManager else { return }
            self.isBoosting = isBoosting && length >= SNConst.minBoostLength

            // Convert joystick direction to world-space target
            // Use last known head position + direction * distance
            let headPos: CGPoint
            if let localPlayer = manager.players[manager.localSessionId],
               let head = localPlayer.segments.first {
                headPos = head
            } else {
                headPos = SNConst.arenaCenter
            }

            let targetX = headPos.x + CGFloat(dirX) * 200
            let targetY = headPos.y + CGFloat(dirY) * 200
            manager.queueInput(targetX: targetX, targetY: targetY, isBoosting: self.isBoosting)

            // Also update scene joystick for potential client-side visual hints
            scene?.joystickDirX = CGFloat(dirX)
            scene?.joystickDirY = CGFloat(dirY)
            scene?.isBoosting = self.isBoosting
        } else {
            // Offline: update scene directly
            scene?.joystickDirX = CGFloat(dirX)
            scene?.joystickDirY = CGFloat(dirY)
            self.isBoosting = isBoosting && length >= SNConst.minBoostLength
            scene?.isBoosting = self.isBoosting
        }
    }

    func restart() {
        showEndScreen = false
        if isOnlineMode {
            // Online: disconnect and reconnect for a new game
            disconnectFromServer()
            setup()
            connectToServer()
        } else {
            startGame()
        }
    }

    // MARK: - Server State Updates

    private func handleServerStateUpdate() {
        guard let manager = networkManager else { return }

        // Update connection state
        connectionState = manager.connectionState
        latency = manager.latency

        // Debug counters
        debugPlayerCount = manager.players.count
        debugOrbCount = manager.orbs.count
        debugSchemaInfo = "p:\(manager.players.count) o:\(manager.orbs.count) id:\(manager.localSessionId.prefix(8))"

        // Push server state to scene for rendering
        scene?.updateRemoteState(players: manager.players, orbs: manager.orbs)

        // Update local player stats from server state
        if let localPlayer = manager.players[manager.localSessionId] {
            score = localPlayer.score
            length = localPlayer.segments.count
            killNotifications = manager.killNotifications

            // Only detect death if player actually had segments (was alive in game)
            // Prevents false death when server state has isAlive=false before game starts
            if !localPlayer.isAlive && isAlive && localPlayer.segments.count > 0 {
                handleDeath(killerName: "Unknown")
            }
        }
    }

    // MARK: - Death

    private func handleDeath(killerName: String) {
        isAlive = false
        self.killerName = killerName
        if score > highScore { highScore = score }
        showDeathFlash = true
        scene?.showDeathFlash()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.showDeathFlash = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showEndScreen = true
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        networkManager?.disconnect()
        networkManager = nil
    }
}
