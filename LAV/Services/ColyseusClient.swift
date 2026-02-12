import Foundation
import Network

// MARK: - Colyseus Protocol Codes
private enum ColyseusProtocol: UInt8 {
    case handshake = 9
    case joinRoom = 10
    case error = 11
    case leaveRoom = 12
    case roomData = 13
    case roomState = 14
    case roomStatePatch = 15
    case roomDataSchema = 17
}

// MARK: - NWWebSocket (Network.framework, no permessage-deflate)

final class NWWebSocket {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.lav.websocket", qos: .userInitiated)
    private(set) var isConnected = false

    var onOpen: (() -> Void)?
    var onClose: ((UInt16) -> Void)?
    var onMessage: ((Data) -> Void)?
    var onError: ((String) -> Void)?

    func connect(url: URL) {
        guard let host = url.host, let scheme = url.scheme else {
            onError?("Invalid WebSocket URL")
            return
        }

        let isSecure = scheme == "wss" || scheme == "https"

        // WebSocket options — NO permessage-deflate, auto-reply to pings
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        wsOptions.setAdditionalHeaders([
            (name: "Origin", value: "https://lav.bot"),
        ])

        // Build NWParameters with TLS if wss://
        let params: NWParameters
        if isSecure {
            params = NWParameters(tls: NWProtocolTLS.Options(), tcp: .init())
        } else {
            params = NWParameters(tls: nil, tcp: .init())
        }
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        // Use .url endpoint so NWConnection includes the full path + query
        // in the WebSocket HTTP upgrade request (e.g. GET /processId/roomId?sessionId=...)
        let conn = NWConnection(to: .url(url), using: params)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[NWWebSocket] Connected")
                self?.isConnected = true
                self?.onOpen?()
                self?.receiveNext()
            case .failed(let error):
                print("[NWWebSocket] Failed: \(error)")
                self?.isConnected = false
                self?.onError?(error.localizedDescription)
                self?.onClose?(1006) // Abnormal closure
            case .waiting(let error):
                print("[NWWebSocket] Waiting: \(error)")
            case .cancelled:
                print("[NWWebSocket] Cancelled")
                self?.isConnected = false
            default:
                break
            }
        }

        conn.start(queue: queue)
    }

    func send(_ data: Data) {
        guard isConnected, let connection else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "ws", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("[NWWebSocket] Send error: \(error)")
                self?.isConnected = false
            }
        })
    }

    func close(code: UInt16 = 1000) {
        isConnected = false
        let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
        metadata.closeCode = .protocolCode(.init(rawValue: code) ?? .protocolError)
        let context = NWConnection.ContentContext(identifier: "close", metadata: [metadata])
        connection?.send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed { [weak self] _ in
            self?.connection?.cancel()
        })
    }

    func cancel() {
        isConnected = false
        connection?.cancel()
    }

    private func receiveNext() {
        connection?.receiveMessage { [weak self] content, context, isComplete, error in
            guard let self else { return }

            if let error = error {
                let nsErr = error as NSError
                // Cancelled connections are expected on leave
                if nsErr.code != 89 { // ECANCELED
                    print("[NWWebSocket] Receive error: \(error)")
                    self.onError?(error.localizedDescription)
                }
                return
            }

            if let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata {
                switch metadata.opcode {
                case .binary, .text:
                    if let data = content {
                        self.onMessage?(data)
                    }
                case .close:
                    self.isConnected = false
                    let closeCode: UInt16
                    switch metadata.closeCode {
                    case .protocolCode(let code): closeCode = UInt16(code.rawValue)
                    default: closeCode = 1000
                    }
                    print("[NWWebSocket] Server close frame, code=\(closeCode)")
                    self.onClose?(closeCode)
                    return
                default:
                    break
                }
            } else if let data = content {
                // No metadata — treat as binary message
                self.onMessage?(data)
            }

            self.receiveNext()
        }
    }
}

// MARK: - Colyseus Room

final class ColyseusRoom {
    let roomId: String
    let sessionId: String
    let reconnectionToken: String
    private let ws: NWWebSocket
    private var messageHandlers: [String: [([String: Any]) -> Void]] = [:]
    private var stateChangeHandler: (([String: Any]) -> Void)?
    private var leaveHandler: ((Int) -> Void)?
    private var errorHandler: ((String) -> Void)?
    private var currentState: [String: Any] = [:]
    private var serializerId: String = "schema"
    var onJoinConfirmed: (() -> Void)?

    // Queue messages received before handlers are registered
    private var pendingMessages: [(type: String, data: [String: Any])] = []

    // Schema decoder for binary state
    let schemaDecoder = ColyseusSchemaDecoder()

    init(roomId: String, sessionId: String, reconnectionToken: String, ws: NWWebSocket) {
        self.roomId = roomId
        self.sessionId = sessionId
        self.reconnectionToken = reconnectionToken
        self.ws = ws

        // Wire up WebSocket message handler
        ws.onMessage = { [weak self] data in
            self?.handleRawMessage(data)
        }
        ws.onClose = { [weak self] code in
            print("[Colyseus] WebSocket closed: code=\(code)")
            self?.leaveHandler?(Int(code))
        }
        ws.onError = { [weak self] msg in
            print("[Colyseus] WebSocket error: \(msg)")
            self?.leaveHandler?(1006)
        }
    }

    deinit {
        print("[Colyseus] ColyseusRoom DEALLOCATED for \(roomId)")
    }

    // MARK: - Public API

    var isActive: Bool { ws.isConnected }

    private var sendLogCount = 0

    func send(type: String, data: [String: Any]? = nil) {
        guard ws.isConnected else { return }
        var bytes = Data([ColyseusProtocol.roomData.rawValue])
        bytes.append(MessagePack.encode(type))
        if let data = data {
            bytes.append(MessagePack.encode(data))
        }
        sendLogCount += 1
        if sendLogCount <= 5 {
            print("[Colyseus] SEND \(type) (\(bytes.count) bytes): \(bytes.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " "))")
        }
        ws.send(bytes)
    }

    func onMessage(type: String, handler: @escaping ([String: Any]) -> Void) {
        if messageHandlers[type] == nil {
            messageHandlers[type] = []
        }
        messageHandlers[type]?.append(handler)

        // Replay any pending messages for this type
        let matching = pendingMessages.filter { $0.type == type || type == "*" }
        if !matching.isEmpty {
            print("[Colyseus] Replaying \(matching.count) pending '\(type)' messages")
            DispatchQueue.main.async {
                for msg in matching {
                    handler(msg.data)
                }
            }
        }
    }

    func onStateChange(handler: @escaping ([String: Any]) -> Void) {
        stateChangeHandler = handler
        // Replay current state if we already received one before the handler was set
        if !currentState.isEmpty {
            print("[Colyseus] Replaying existing state to new handler (\(currentState.count) keys)")
            DispatchQueue.main.async {
                handler(self.currentState)
            }
        }
    }

    func onLeave(handler: @escaping (Int) -> Void) {
        leaveHandler = handler
    }

    func onError(handler: @escaping (String) -> Void) {
        errorHandler = handler
    }

    func leave() {
        print("[Colyseus] leave() called — sending LEAVE_ROOM")
        if ws.isConnected {
            ws.send(Data([ColyseusProtocol.leaveRoom.rawValue]))
            ws.close(code: 1000)
        } else {
            ws.cancel()
        }
        leaveHandler?(1000)
    }

    // MARK: - Raw Binary Message Handling

    private func handleRawMessage(_ data: Data) {
        guard !data.isEmpty else { return }

        let code = data[data.startIndex]
        let payload = data.dropFirst()

        print("[Colyseus] Received \(data.count) bytes, protocol code=\(code)")

        switch code {
        case ColyseusProtocol.joinRoom.rawValue:
            handleJoinRoom(Data(payload))

        case ColyseusProtocol.error.rawValue:
            handleError(Data(payload))

        case ColyseusProtocol.roomState.rawValue:
            handleRoomState(Data(payload))

        case ColyseusProtocol.roomStatePatch.rawValue:
            handleStatePatch(Data(payload))

        case ColyseusProtocol.roomData.rawValue:
            handleRoomData(Data(payload))

        case ColyseusProtocol.roomDataSchema.rawValue:
            handleRoomData(Data(payload))

        case ColyseusProtocol.leaveRoom.rawValue:
            print("[Colyseus] Server sent LEAVE_ROOM")
            leaveHandler?(1000)

        default:
            print("[Colyseus] Unknown protocol code: \(code), hex: \(data.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " "))")
        }
    }

    // MARK: - JOIN_ROOM Handler

    private func handleJoinRoom(_ payload: Data) {
        guard !payload.isEmpty else {
            sendJoinAck()
            return
        }

        var offset = 0

        // 1. Read reconnection token
        let tokenLen = Int(payload[offset]); offset += 1
        if offset + tokenLen <= payload.count {
            let tokenData = payload[offset..<offset + tokenLen]
            let token = String(data: tokenData, encoding: .utf8) ?? ""
            print("[Colyseus] Server reconnection token: \(token)")
            offset += tokenLen
        }

        // 2. Read serializer ID
        if offset < payload.count {
            let idLen = Int(payload[offset]); offset += 1
            if offset + idLen <= payload.count {
                let idData = payload[offset..<offset + idLen]
                serializerId = String(data: idData, encoding: .utf8) ?? "schema"
                offset += idLen
            }
        }

        print("[Colyseus] JOIN_ROOM confirmed, serializer=\(serializerId), handshake=\(payload.count - offset) bytes")

        // 3. Parse handshake (schema reflection)
        if offset < payload.count && serializerId == "schema" {
            let handshakeData = Data(payload[offset...])
            schemaDecoder.parseHandshake(handshakeData)

            schemaDecoder.onStateChange = { [weak self] state in
                guard let self else { return }
                self.currentState = state
                // Dispatch to main thread — @Observable and SpriteKit need it
                DispatchQueue.main.async {
                    self.stateChangeHandler?(state)
                }
            }
        }

        sendJoinAck()
    }

    private func sendJoinAck() {
        let ack = Data([ColyseusProtocol.joinRoom.rawValue])
        ws.send(ack)
        print("[Colyseus] JOIN_ROOM ack sent")

        DispatchQueue.main.async { [weak self] in
            self?.onJoinConfirmed?()
            self?.onJoinConfirmed = nil
        }
    }

    // MARK: - ERROR Handler

    private func handleError(_ payload: Data) {
        var errorMsg = "Unknown error"
        if !payload.isEmpty {
            let msgData = payload.dropFirst()
            if let decoded = MessagePack.decode(Data(msgData)) as? String {
                errorMsg = decoded
            } else if let str = String(data: Data(msgData), encoding: .utf8) {
                errorMsg = str
            }
        }
        print("[Colyseus] ERROR from server: \(errorMsg)")
        DispatchQueue.main.async { [weak self] in
            self?.errorHandler?(errorMsg)
        }
    }

    // MARK: - ROOM_STATE Handler

    private func handleRoomState(_ payload: Data) {
        print("[Colyseus] ROOM_STATE received: \(payload.count) bytes")

        if schemaDecoder.isReady {
            schemaDecoder.decodeFullState(payload)
        } else {
            print("[Colyseus] Schema decoder not ready, dropping ROOM_STATE")
        }
    }

    // MARK: - ROOM_STATE_PATCH Handler

    private var patchLogCount = 0

    private func handleStatePatch(_ payload: Data) {
        patchLogCount += 1
        if patchLogCount <= 10 {
            print("[Colyseus] ROOM_STATE_PATCH #\(patchLogCount): \(payload.count) bytes")
        }
        if schemaDecoder.isReady {
            schemaDecoder.decodePatch(payload)
        }
    }

    // MARK: - ROOM_DATA Handler

    private func handleRoomData(_ payload: Data) {
        var offset = 0

        guard let typeVal = MessagePack.decode(payload, offset: &offset) else {
            print("[Colyseus] Failed to decode ROOM_DATA type")
            return
        }

        let type: String
        if let t = typeVal as? String {
            type = t
        } else if let t = typeVal as? Int {
            type = "\(t)"
        } else {
            print("[Colyseus] ROOM_DATA: unexpected type field: \(typeVal)")
            return
        }

        var msgData: [String: Any] = [:]
        if offset < payload.count {
            if let dataVal = MessagePack.decode(payload, offset: &offset) {
                if let d = dataVal as? [String: Any] {
                    msgData = d
                } else if let s = dataVal as? String {
                    msgData = ["message": s]
                } else {
                    msgData = ["value": dataVal]
                }
            }
        }

        print("[Colyseus] ROOM_DATA: type=\(type) data=\(msgData)")
        dispatchMessage(type: type, data: msgData)
    }

    // MARK: - Dispatch

    private func dispatchMessage(type: String, data: [String: Any]) {
        let hasHandler = messageHandlers[type] != nil || messageHandlers["*"] != nil
        if !hasHandler {
            // Queue for later replay when handler is registered
            pendingMessages.append((type: type, data: data))
            return
        }

        DispatchQueue.main.async { [weak self] in
            if let handlers = self?.messageHandlers[type] {
                for handler in handlers {
                    handler(data)
                }
            }
            if let handlers = self?.messageHandlers["*"] {
                var enriched = data
                enriched["__type"] = type
                for handler in handlers {
                    handler(enriched)
                }
            }
        }
    }
}

// MARK: - Colyseus Client

final class ColyseusClient {
    private let serverURL: String
    private let httpSession: URLSession

    init(serverURL: String) {
        self.serverURL = serverURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.httpSession = URLSession(configuration: config)
    }

    deinit {
        print("[Colyseus] ColyseusClient DEALLOCATED")
    }

    /// Join or create a room via Colyseus matchmaking.
    func joinOrCreate(roomType: String, options: [String: Any] = [:]) async throws -> ColyseusRoom {
        // Step 1: HTTP matchmake request
        let httpURL = serverURL
            .replacingOccurrences(of: "wss://", with: "https://")
            .replacingOccurrences(of: "ws://", with: "http://")

        let matchmakeURL = "\(httpURL)/matchmake/joinOrCreate/\(roomType)"
        guard let url = URL(string: matchmakeURL) else {
            throw ColyseusError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainManager.shared.sessionToken {
            request.setValue("session_token=\(token)", forHTTPHeaderField: "Cookie")
        }
        request.setValue("https://lav.bot", forHTTPHeaderField: "Origin")
        request.setValue("https://lav.bot/", forHTTPHeaderField: "Referer")

        let body = try JSONSerialization.data(withJSONObject: options)
        request.httpBody = body

        let (data, response) = try await httpSession.data(for: request)

        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            print("[Colyseus] Matchmake failed: \(bodyStr)")
            throw ColyseusError.matchmakeFailed(bodyStr)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ColyseusError.invalidResponse
        }

        print("[Colyseus] Matchmake response: \(json)")

        let roomId: String
        let processId: String
        let sessionId = json["sessionId"] as? String ?? ""
        let reconnectionToken = json["reconnectionToken"] as? String ?? ""

        if let room = json["room"] as? [String: Any] {
            roomId = room["roomId"] as? String ?? ""
            processId = room["processId"] as? String ?? ""
        } else {
            roomId = json["roomId"] as? String ?? ""
            processId = json["processId"] as? String ?? ""
        }

        guard !roomId.isEmpty, !sessionId.isEmpty else {
            throw ColyseusError.invalidResponse
        }

        print("[Colyseus] reconnectionToken: \(reconnectionToken.isEmpty ? "MISSING" : String(reconnectionToken.prefix(20)) + "...")")

        // Step 2: Connect WebSocket using Network.framework (avoids URLSessionWebSocketTask
        // permessage-deflate compression issues that cause server close code 4000)
        var wsURL = "\(serverURL)/\(processId)/\(roomId)?sessionId=\(sessionId)"
        if !reconnectionToken.isEmpty {
            let encoded = reconnectionToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? reconnectionToken
            wsURL += "&reconnectionToken=\(encoded)"
        }
        guard let wsUrlObj = URL(string: wsURL) else {
            throw ColyseusError.invalidURL
        }

        print("[Colyseus] Connecting WS to: \(wsURL)")

        let ws = NWWebSocket()
        let room = ColyseusRoom(
            roomId: roomId,
            sessionId: sessionId,
            reconnectionToken: reconnectionToken,
            ws: ws
        )

        // Wait for JOIN_ROOM confirmation or error
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false

            room.onJoinConfirmed = {
                guard !resumed else { return }
                resumed = true
                continuation.resume()
            }

            room.onError { msg in
                guard !resumed else { return }
                resumed = true
                continuation.resume(throwing: ColyseusError.matchmakeFailed(msg))
            }

            ws.onClose = { code in
                guard !resumed else { return }
                resumed = true
                print("[Colyseus] WS closed before join completed, code=\(code)")
                continuation.resume(throwing: ColyseusError.connectionFailed)
            }

            // Timeout after 15 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 15) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(throwing: ColyseusError.connectionFailed)
            }

            // Connect (message handling is wired up in ColyseusRoom.init)
            ws.connect(url: wsUrlObj)
        }

        print("[Colyseus] Joined room \(roomId) as \(sessionId)")
        return room
    }
}

// MARK: - Errors

enum ColyseusError: Error, LocalizedError {
    case invalidURL
    case matchmakeFailed(String)
    case invalidResponse
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .matchmakeFailed(let msg): return "Failed to join: \(msg)"
        case .invalidResponse: return "Invalid server response"
        case .connectionFailed: return "Connection failed"
        }
    }
}
