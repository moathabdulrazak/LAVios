import Foundation
import Observation

@Observable
final class SolSnakeNetworkManager {

    // MARK: - Connection State

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case lobby(playerCount: Int)
        case countdown(seconds: Int)
        case playing
        case gameEnded
        case error(String)
    }

    var connectionState: ConnectionState = .disconnected
    var latency: Int = 0
    var killNotifications: [KillNotification] = []

    // Game state from server
    private(set) var players: [String: PlayerState] = [:]
    private(set) var orbs: [String: OrbState] = [:]
    private(set) var localSessionId: String = ""
    private(set) var gameStarted: Bool = false

    // Callbacks
    var onStateUpdate: (() -> Void)?
    var onGameStart: (() -> Void)?
    var onPlayerDeath: ((String) -> Void)?
    var onPlayerKill: ((KillNotification) -> Void)?
    var onLeaderboardUpdate: (([LeaderboardEntry]) -> Void)?
    var onGameEnd: (() -> Void)?

    private var room: ColyseusRoom?
    private var client: ColyseusClient?
    private var inputTimer: Timer?
    private var pingTimer: Timer?
    private var lastPingTime: TimeInterval = 0
    private var pendingInput: (targetX: CGFloat, targetY: CGFloat, isBoosting: Bool)?
    private var lastLocalIsAlive: Bool = true
    private var waitingForPayment: Bool = false
    private var playerHasBeenAlive: Bool = false

    // MARK: - Connect

    func connect(playerName: String, skin: Int, mode: String = "sandbox", entryAmount: Double = 0, walletAddress: String = "", txSignature: String? = nil, verificationToken: String? = nil, paymentTimestamp: Int? = nil) async throws {
        connectionState = .connecting

        let client = ColyseusClient(serverURL: Config.gameServerURL)
        self.client = client

        var options: [String: Any] = [
            "playerName": playerName,
            "skin": skin,
            "mode": mode,
        ]
        if entryAmount > 0 {
            options["entryAmount"] = entryAmount
        }
        if !walletAddress.isEmpty {
            options["walletAddress"] = walletAddress
        }
        if let sig = txSignature {
            options["txSignature"] = sig
        }
        if let token = verificationToken {
            options["verificationToken"] = token
        }

        // Room type IS the mode: "sandbox", "arena", or "tournament"
        let roomType = mode
        print("[SolSnakeNet] Connecting to \(Config.gameServerURL) as \(playerName) (skin=\(skin), roomType=\(roomType))")

        let room = try await client.joinOrCreate(roomType: roomType, options: options)
        self.room = room
        self.localSessionId = room.sessionId

        print("[SolSnakeNet] Joined room \(room.roomId) as \(room.sessionId)")

        setupHandlers(room)
        startInputThrottle()
        startPingTimer()

        // Send ready/payment message based on mode (required by server to start game)
        if mode == "sandbox" {
            // Sandbox: send 'ready' — server will start game once enough players (incl bots)
            print("[SolSnakeNet] Sandbox mode — sending 'ready' with skipPayment")
            room.send(type: "ready", data: ["skipPayment": true])
            // Don't immediately start — wait for server's gameStart/game_starting signal
            connectionState = .lobby(playerCount: 1)
        } else if let sig = txSignature, entryAmount > 0 {
            // Paid mode (arena/tournament): send 'payment' with transaction details
            print("[SolSnakeNet] Paid mode — sending 'payment' (amount=\(entryAmount), sig=\(sig.prefix(20))...)")
            var paymentData: [String: Any] = [
                "paymentSignature": sig,
                "amount": entryAmount,
            ]
            if !walletAddress.isEmpty {
                paymentData["wallet"] = walletAddress
            }
            if let token = verificationToken {
                paymentData["verificationToken"] = token
            }
            if let ts = paymentTimestamp {
                paymentData["timestamp"] = ts
            }
            room.send(type: "payment", data: paymentData)
            waitingForPayment = true
            connectionState = .lobby(playerCount: 1)
        } else {
            connectionState = .lobby(playerCount: 1)
        }
    }

    // MARK: - Send Input

    func queueInput(targetX: CGFloat, targetY: CGFloat, isBoosting: Bool) {
        pendingInput = (targetX, targetY, isBoosting)
    }

    // MARK: - Disconnect

    func disconnect() {
        inputTimer?.invalidate()
        inputTimer = nil
        pingTimer?.invalidate()
        pingTimer = nil
        room?.leave()
        room = nil
        client = nil
        connectionState = .disconnected
        players.removeAll()
        orbs.removeAll()
        gameStarted = false
        lastLocalIsAlive = true
        waitingForPayment = false
        playerHasBeenAlive = false
    }

    // MARK: - Handlers

    private func setupHandlers(_ room: ColyseusRoom) {
        // State changes
        room.onStateChange { [weak self] state in
            self?.handleStateChange(state)
        }

        // Game lifecycle
        room.onMessage(type: "init") { [weak self] data in
            let count = data["playersInRoom"] as? Int ?? data["realPlayers"] as? Int ?? 1
            print("[SolSnakeNet] init: \(count) players")
            self?.connectionState = .lobby(playerCount: count)
        }

        room.onMessage(type: "paymentConfirmed") { [weak self] data in
            guard let self else { return }
            print("[SolSnakeNet] paymentConfirmed: \(data)")
            self.waitingForPayment = false
            // Only start game if server says gameStarted=true in the message
            let serverGameStarted = data["gameStarted"] as? Bool ?? false
            if serverGameStarted && !self.gameStarted {
                print("[SolSnakeNet] Payment confirmed with gameStarted=true — starting game")
                self.gameStarted = true
                self.connectionState = .playing
                self.onGameStart?()
            } else {
                // Payment acknowledged but game not started yet — update lobby
                let count = data["playersInRoom"] as? Int ?? data["paidPlayers"] as? Int ?? 1
                print("[SolSnakeNet] Payment confirmed, waiting for players (\(count))")
                self.connectionState = .lobby(playerCount: count)
            }
        }

        room.onMessage(type: "gameStart") { [weak self] _ in
            print("[SolSnakeNet] gameStart")
            self?.gameStarted = true
            self?.connectionState = .playing
            self?.onGameStart?()
        }

        room.onMessage(type: "game_starting") { [weak self] _ in
            print("[SolSnakeNet] game_starting")
            self?.gameStarted = true
            self?.connectionState = .playing
            self?.onGameStart?()
        }

        room.onMessage(type: "countdown") { [weak self] data in
            let seconds = data["seconds"] as? Int ?? 0
            print("[SolSnakeNet] countdown: \(seconds)s")
            self?.connectionState = .countdown(seconds: seconds)
        }

        room.onMessage(type: "countdown_cancel") { [weak self] _ in
            print("[SolSnakeNet] countdown cancelled")
            let count = self?.players.count ?? 1
            self?.connectionState = .lobby(playerCount: count)
        }

        room.onMessage(type: "playerJoined") { [weak self] data in
            let count = data["playersInRoom"] as? Int ?? data["realPlayers"] as? Int ?? data["playerCount"] as? Int ?? 1
            print("[SolSnakeNet] playerJoined: \(count) players")
            if case .lobby = self?.connectionState {
                self?.connectionState = .lobby(playerCount: count)
            }
        }

        room.onMessage(type: "playerLeft") { [weak self] data in
            let count = data["playersInRoom"] as? Int ?? data["realPlayers"] as? Int ?? data["playerCount"] as? Int ?? 1
            print("[SolSnakeNet] playerLeft: \(count) players")
            if case .lobby = self?.connectionState {
                self?.connectionState = .lobby(playerCount: count)
            }
        }

        room.onMessage(type: "playerDied") { [weak self] data in
            let playerId = data["playerId"] as? String ?? ""
            print("[SolSnakeNet] playerDied: \(playerId)")
            if playerId == self?.localSessionId {
                self?.onPlayerDeath?("Unknown")
            }
        }

        room.onMessage(type: "playerKilled") { [weak self] data in
            guard let self else { return }
            let notification = KillNotification(
                victimName: data["victimName"] as? String ?? "Unknown",
                reward: data["reward"] as? Double ?? 0,
                scoreGained: data["scoreGained"] as? Int ?? 0
            )
            self.killNotifications.append(notification)
            self.onPlayerKill?(notification)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if let self, !self.killNotifications.isEmpty {
                    self.killNotifications.removeFirst()
                }
            }
        }

        room.onMessage(type: "gameEnd") { [weak self] _ in
            print("[SolSnakeNet] gameEnd")
            self?.connectionState = .gameEnded
            self?.onGameEnd?()
        }

        room.onMessage(type: "pong") { [weak self] _ in
            guard let self else { return }
            self.latency = Int((Date().timeIntervalSince1970 - self.lastPingTime) * 1000)
        }

        room.onMessage(type: "error") { [weak self] data in
            let msg = data["message"] as? String ?? "Unknown error"
            print("[SolSnakeNet] error: \(msg)")
            self?.connectionState = .error(msg)
        }

        // Debug: log all messages
        room.onMessage(type: "*") { data in
            let type = data["__type"] as? String ?? "?"
            print("[SolSnakeNet] MSG [\(type)]: \(data)")
        }

        room.onLeave { [weak self] code in
            print("[SolSnakeNet] Left room, code=\(code)")
            self?.connectionState = .disconnected
        }

        room.onError { [weak self] msg in
            print("[SolSnakeNet] Room error: \(msg)")
            self?.connectionState = .error(msg)
        }
    }

    // MARK: - State Parsing

    private var stateLogCount = 0

    private func handleStateChange(_ state: [String: Any]) {
        stateLogCount += 1
        if stateLogCount <= 5 {
            let playersDict = state["players"] as? [String: Any]
            let orbsDict = state["orbs"] as? [String: Any]
            let alive = state["alivePlayersCount"]
            let paid = state["paidPlayersCount"]
            print("[SolSnakeNet] State #\(stateLogCount): players=\(playersDict?.count ?? 0) orbs=\(orbsDict?.count ?? 0) alive=\(alive ?? 0) paid=\(paid ?? 0) waitPay=\(waitingForPayment) gameStarted=\(gameStarted)")
        }

        // Check gameStarted from state (may come as Bool or Int 1)
        let gsValue = state["gameStarted"]
        let gsTrue: Bool
        if let b = gsValue as? Bool { gsTrue = b }
        else if let n = gsValue as? NSNumber { gsTrue = n.intValue != 0 }
        else if let i = gsValue as? Int { gsTrue = i != 0 }
        else { gsTrue = false }

        if gsTrue && !gameStarted && !waitingForPayment {
            print("[SolSnakeNet] gameStarted=true from state (raw=\(String(describing: gsValue)))")
            gameStarted = true
            connectionState = .playing
            onGameStart?()
        }

        // Parse players
        if let playersRaw = state["players"] {
            parsePlayers(playersRaw)
        }

        // Parse orbs
        if let orbsRaw = state["orbs"] {
            parseOrbs(orbsRaw)
        }

        // Detect local player death from state (only if player was alive at some point)
        if let localPlayer = players[localSessionId] {
            if localPlayer.isAlive {
                playerHasBeenAlive = true
                lastLocalIsAlive = true
            } else if playerHasBeenAlive && lastLocalIsAlive {
                lastLocalIsAlive = false
                onPlayerDeath?("Unknown")
            }
        }

        // Update leaderboard
        let leaderboard = players.values
            .filter { $0.isAlive }
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { LeaderboardEntry(id: $0.id, name: $0.name, score: $0.score) }
        onLeaderboardUpdate?(Array(leaderboard))

        onStateUpdate?()
    }

    private func parsePlayers(_ raw: Any) {
        // The schema decoder outputs Maps as [String: Any] dicts
        guard let playersMap = raw as? [String: Any] else {
            if stateLogCount <= 5 {
                print("[SolSnakeNet] players not a dict, type=\(type(of: raw))")
            }
            return
        }

        var newPlayers: [String: PlayerState] = [:]
        for (sessionId, value) in playersMap {
            guard let dict = value as? [String: Any] else { continue }

            let name = dict["name"] as? String ?? "Player"
            let score = toInt(dict["score"])
            let kills = toInt(dict["kills"])
            let isAlive = dict["isAlive"] as? Bool ?? true
            let skinIndex = toInt(dict["skinIndex"])
            let isBoosting = dict["isBoosting"] as? Bool ?? false

            var segments: [CGPoint] = []
            if let segsArray = dict["segments"] as? [[String: Any]] {
                for seg in segsArray {
                    let x = toDouble(seg["x"])
                    let y = toDouble(seg["y"])
                    segments.append(CGPoint(x: x, y: y))
                }
            } else if let segsArray = dict["segments"] as? [Any] {
                for seg in segsArray {
                    if let segDict = seg as? [String: Any] {
                        let x = toDouble(segDict["x"])
                        let y = toDouble(segDict["y"])
                        segments.append(CGPoint(x: x, y: y))
                    }
                }
            }

            if stateLogCount <= 5 {
                print("[SolSnakeNet] Player \(sessionId.prefix(8)): segs=\(segments.count) alive=\(isAlive) score=\(score)")
            }

            newPlayers[sessionId] = PlayerState(
                id: sessionId, name: name, score: score, kills: kills,
                isAlive: isAlive, isBoosting: isBoosting, skin: skinIndex,
                segments: segments
            )
        }
        players = newPlayers
    }

    private func parseOrbs(_ raw: Any) {
        guard let orbsMap = raw as? [String: Any] else {
            if stateLogCount <= 5 {
                print("[SolSnakeNet] orbs not a dict, type=\(type(of: raw))")
            }
            return
        }

        var newOrbs: [String: OrbState] = [:]
        for (orbId, value) in orbsMap {
            guard let dict = value as? [String: Any] else { continue }
            let x = toDouble(dict["x"])
            let y = toDouble(dict["y"])
            let colorIndex = toInt(dict["colorIndex"])
            newOrbs[orbId] = OrbState(id: orbId, position: CGPoint(x: x, y: y), colorIndex: colorIndex)
        }
        orbs = newOrbs
    }

    // MARK: - Number Helpers

    private func toInt(_ value: Any?) -> Int {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let d = value as? Double { return Int(d) }
        return 0
    }

    private func toDouble(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let i = value as? Int { return Double(i) }
        return 0
    }

    // MARK: - Input Throttle (30/sec)

    private func startInputThrottle() {
        inputTimer = Timer.scheduledTimer(withTimeInterval: SNConst.inputRate, repeats: true) { [weak self] _ in
            self?.flushInput()
        }
    }

    private func flushInput() {
        guard let input = pendingInput, gameStarted else { return }
        room?.send(type: "input", data: [
            "targetX": input.targetX,
            "targetY": input.targetY,
            "isBoosting": input.isBoosting
        ])
        pendingInput = nil
    }

    // MARK: - Ping

    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: SNConst.pingInterval, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        lastPingTime = Date().timeIntervalSince1970
        room?.send(type: "ping", data: ["timestamp": lastPingTime])
    }
}
