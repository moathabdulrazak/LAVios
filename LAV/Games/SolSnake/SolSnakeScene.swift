import SpriteKit

final class SolSnakeScene: SKScene {

    // MARK: - Rendering Properties

    private let cameraNode = SKCameraNode()
    private var gridNode: SKNode?
    private var arenaNode: SKNode?
    private var orbsNode = SKNode()
    private var snakesNode = SKNode()
    private var namesNode = SKNode()

    // Pre-rendered textures
    private var orbTexture: SKTexture?
    private var segmentTextures: [Int: SKTexture] = [:]
    private var boostTextures: [Int: SKTexture] = [:]
    private var headTextures: [Int: SKTexture] = [:]
    private var boostHeadTextures: [Int: SKTexture] = [:]

    // Node pools
    private var orbPool: [SKSpriteNode] = []
    private var activeOrbs: [String: SKSpriteNode] = [:]
    private var snakeNodeCache: [String: SKNode] = [:]
    private var segmentPool: [SKSpriteNode] = []

    // Camera smoothing
    private var cameraVelocity = CGPoint.zero
    private var targetCameraPos = SNConst.arenaCenter

    // Render state
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Game Engine Properties

    private var snakes: [String: SnakeData] = [:]
    private var orbData: [String: OrbData] = [:]
    private var orbIdCounter: Int = 0
    private var orbSpawnTimer: TimeInterval = 0
    private var isGameRunning = false
    private var localPlayerDead = false
    private let localPlayerId = "local"

    // Input
    var joystickDirX: CGFloat = 0
    var joystickDirY: CGFloat = 0
    var isBoosting = false

    // Bot names
    private let botNames = ["Viper", "Cobra", "Python", "Mamba", "Krait", "Taipan", "Adder", "Racer"]

    // Callbacks to ViewModel
    var onScoreChange: ((Int) -> Void)?
    var onLengthChange: ((Int) -> Void)?
    var onKill: ((String) -> Void)?
    var onDeath: ((String) -> Void)?
    var onLeaderboardChange: (([LeaderboardEntry]) -> Void)?

    // MARK: - Internal Models

    private struct SnakeData {
        let id: String
        var name: String
        var skin: Int
        var segments: [CGPoint]
        var pathHistory: [CGPoint]
        var score: Int = 0
        var kills: Int = 0
        var isAlive: Bool = true
        var isBoosting: Bool = false
        var targetX: CGFloat = 0
        var targetY: CGFloat = 0
        var respawnTimer: TimeInterval = 0
        var isBot: Bool
    }

    private struct OrbData {
        let id: String
        var position: CGPoint
        var colorIndex: Int
    }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 3/255, green: 5/255, blue: 8/255, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.setScale(1.0 / SNConst.mobileZoom)

        createTextures()
        setupBackground()
        setupArena()

        orbsNode.zPosition = 10
        addChild(orbsNode)

        snakesNode.zPosition = 20
        addChild(snakesNode)

        namesNode.zPosition = 30
        addChild(namesNode)
    }

    // MARK: - Texture Generation

    private func createTextures() {
        let orbSize = SNConst.orbTextureSize
        orbTexture = SKTexture(image: renderCircle(
            size: orbSize,
            coreColor: SNColors.orbCyan,
            glowColor: SNColors.orbCyan.withAlphaComponent(0.3),
            glowRadius: orbSize * 0.4
        ))

        for (i, skin) in SNConst.snakeSkins.enumerated() {
            let segSize: CGFloat = 20
            let coreColor = skin.colors.count > 2 ? skin.colors[2] : skin.colors[0]
            let edgeColor = skin.colors.count > 1 ? skin.colors[1] : skin.colors[0]
            let boostCore = skin.boostColor
            let glowAlpha: CGFloat = 0.4

            segmentTextures[i] = SKTexture(image: renderCircle(
                size: segSize, coreColor: coreColor,
                glowColor: edgeColor.withAlphaComponent(glowAlpha), glowRadius: segSize * 0.3
            ))
            boostTextures[i] = SKTexture(image: renderCircle(
                size: segSize, coreColor: boostCore,
                glowColor: boostCore.withAlphaComponent(0.6), glowRadius: segSize * 0.4
            ))
            headTextures[i] = SKTexture(image: renderCircle(
                size: segSize * 1.3, coreColor: coreColor,
                glowColor: edgeColor.withAlphaComponent(0.5), glowRadius: segSize * 0.5
            ))
            boostHeadTextures[i] = SKTexture(image: renderCircle(
                size: segSize * 1.3, coreColor: boostCore,
                glowColor: boostCore.withAlphaComponent(0.7), glowRadius: segSize * 0.5
            ))
        }
    }

    private func renderCircle(size: CGFloat, coreColor: UIColor, glowColor: UIColor, glowRadius: CGFloat) -> UIImage {
        let totalSize = size + glowRadius * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalSize, height: totalSize))
        return renderer.image { ctx in
            let center = CGPoint(x: totalSize / 2, y: totalSize / 2)
            let cg = ctx.cgContext

            cg.setShadow(offset: .zero, blur: glowRadius, color: glowColor.cgColor)
            cg.setFillColor(coreColor.cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size))

            cg.setShadow(offset: .zero, blur: 0, color: nil)
            cg.setFillColor(coreColor.cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size))
        }
    }

    // MARK: - Background & Arena

    private func setupBackground() {}

    private func setupArena() {
        arenaNode = SKNode()
        arenaNode?.zPosition = 2
        addChild(arenaNode!)

        let center = SNConst.arenaCenter
        let radius = SNConst.arenaRadius

        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = center
        ring.strokeColor = SNColors.arenaStroke
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.glowWidth = 8
        arenaNode?.addChild(ring)

        let dashPath = CGMutablePath()
        let dashRadius = radius - 50
        let dashCount = 60
        for i in 0..<dashCount {
            let startAngle = CGFloat(i) * (2 * .pi / CGFloat(dashCount))
            let endAngle = startAngle + (0.6 * 2 * .pi / CGFloat(dashCount))
            dashPath.addArc(center: CGPoint(x: center.x, y: center.y),
                            radius: dashRadius, startAngle: startAngle,
                            endAngle: endAngle, clockwise: false)
            dashPath.move(to: CGPoint(
                x: center.x + cos(endAngle + 0.02) * dashRadius,
                y: center.y + sin(endAngle + 0.02) * dashRadius
            ))
        }
        let warningRing = SKShapeNode(path: dashPath)
        warningRing.strokeColor = SNColors.arenaWarning
        warningRing.lineWidth = 2
        warningRing.fillColor = .clear
        arenaNode?.addChild(warningRing)
    }

    // MARK: - Game Start

    func startGame() {
        // Clear previous game
        snakes.removeAll()
        orbData.removeAll()
        orbIdCounter = 0
        localPlayerDead = false

        // Create local player at arena center
        let center = SNConst.arenaCenter
        let playerSkin = Int.random(in: 0..<SNConst.snakeSkins.count)
        var playerSegments: [CGPoint] = []
        for i in 0..<10 {
            playerSegments.append(CGPoint(x: center.x, y: center.y + CGFloat(i) * SNConst.segmentSpacing))
        }
        var playerSnake = SnakeData(
            id: localPlayerId, name: "You", skin: playerSkin,
            segments: playerSegments,
            pathHistory: [center],
            isBot: false
        )
        playerSnake.targetX = center.x
        playerSnake.targetY = center.y - 100
        snakes[localPlayerId] = playerSnake

        // Create 8 bots
        for i in 0..<8 {
            let botId = "bot_\(i)"
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 400...1500)
            let bx = center.x + cos(angle) * dist
            let by = center.y + sin(angle) * dist
            let botSkin = (playerSkin + i + 1) % SNConst.snakeSkins.count
            let startLen = Int.random(in: 15...25)

            var botSegments: [CGPoint] = []
            for j in 0..<startLen {
                botSegments.append(CGPoint(x: bx, y: by + CGFloat(j) * SNConst.segmentSpacing))
            }

            var bot = SnakeData(
                id: botId, name: botNames[i], skin: botSkin,
                segments: botSegments,
                pathHistory: [CGPoint(x: bx, y: by)],
                score: Int.random(in: 5...30),
                isBot: true
            )
            bot.targetX = bx + CGFloat.random(in: -200...200)
            bot.targetY = by + CGFloat.random(in: -200...200)
            snakes[botId] = bot
        }

        // Spawn initial orbs
        for _ in 0..<200 {
            spawnOrb()
        }

        isGameRunning = true
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = CGFloat(min(currentTime - lastUpdateTime, 0.05))
        }
        lastUpdateTime = currentTime

        if isGameRunning {
            updateLocalPlayer(dt: dt)
            updateBots(dt: dt, currentTime: currentTime)
            checkCollisions()
            updateOrbCollection()
            maintainOrbs()
            updateRespawns(dt: dt)
            syncRenderState()
            updateLeaderboard()
        }

        updateCamera(dt: dt)
        renderOrbs()
        renderSnakes()
        updateGridDots()
    }

    // MARK: - Local Player Movement

    private func updateLocalPlayer(dt: CGFloat) {
        guard var snake = snakes[localPlayerId], snake.isAlive else { return }

        // Determine target from joystick
        let head = snake.segments[0]
        if joystickDirX != 0 || joystickDirY != 0 {
            snake.targetX = head.x + joystickDirX * 200
            snake.targetY = head.y + joystickDirY * 200
        }

        moveSnake(&snake, dt: dt)
        snakes[localPlayerId] = snake

        onScoreChange?(snake.score)
        onLengthChange?(snake.segments.count)
    }

    // MARK: - Bot AI

    private func updateBots(dt: CGFloat, currentTime: TimeInterval) {
        for (id, var snake) in snakes where snake.isBot && snake.isAlive {
            // Re-evaluate target periodically
            snake.respawnTimer -= Double(dt)
            if snake.respawnTimer <= 0 {
                snake.respawnTimer = Double.random(in: 1.0...3.0)
                pickBotTarget(&snake)
            }

            // Avoidance: check if another snake body is ahead
            let head = snake.segments[0]
            let angle = atan2(snake.targetY - head.y, snake.targetX - head.x)
            let lookAheadX = head.x + cos(angle) * 50
            let lookAheadY = head.y + sin(angle) * 50

            var needsAvoidance = false
            for (otherId, other) in snakes where otherId != id && other.isAlive {
                for seg in other.segments {
                    let dx = lookAheadX - seg.x
                    let dy = lookAheadY - seg.y
                    if dx * dx + dy * dy < 2500 { // 50px
                        // Steer perpendicular
                        snake.targetX = head.x + sin(angle) * 200
                        snake.targetY = head.y - cos(angle) * 200
                        needsAvoidance = true
                        break
                    }
                }
                if needsAvoidance { break }
            }

            // Random boost
            if snake.segments.count > 20 {
                snake.isBoosting = Double.random(in: 0...1) < 0.1
            } else {
                snake.isBoosting = false
            }

            moveSnake(&snake, dt: dt)
            snakes[id] = snake
        }
    }

    private func pickBotTarget(_ snake: inout SnakeData) {
        let head = snake.segments[0]
        let roll = Double.random(in: 0...1)

        if roll < 0.7 {
            // Seek nearest orb
            var bestDist: CGFloat = .greatestFiniteMagnitude
            var bestPos = head
            for (_, orb) in orbData {
                let dx = orb.position.x - head.x
                let dy = orb.position.y - head.y
                let dist = dx * dx + dy * dy
                if dist < bestDist {
                    bestDist = dist
                    bestPos = orb.position
                }
            }
            snake.targetX = bestPos.x
            snake.targetY = bestPos.y
        } else if roll < 0.9 {
            // Random wander within arena
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 100...400)
            var tx = head.x + cos(angle) * dist
            var ty = head.y + sin(angle) * dist
            // Clamp inside arena
            let dx = tx - SNConst.arenaCenter.x
            let dy = ty - SNConst.arenaCenter.y
            let d = sqrt(dx * dx + dy * dy)
            if d > SNConst.arenaRadius - 100 {
                tx = SNConst.arenaCenter.x + dx / d * (SNConst.arenaRadius - 100)
                ty = SNConst.arenaCenter.y + dy / d * (SNConst.arenaRadius - 100)
            }
            snake.targetX = tx
            snake.targetY = ty
        } else {
            // Chase smaller snake
            var bestTarget: CGPoint?
            var bestScore = Int.max
            for (otherId, other) in snakes where otherId != snake.id && other.isAlive && other.segments.count < snake.segments.count {
                if other.score < bestScore {
                    bestScore = other.score
                    bestTarget = other.segments.first
                }
            }
            if let t = bestTarget {
                snake.targetX = t.x
                snake.targetY = t.y
            }
        }
    }

    // MARK: - Snake Movement (shared)

    private func moveSnake(_ snake: inout SnakeData, dt: CGFloat) {
        guard !snake.segments.isEmpty else { return }

        let head = snake.segments[0]
        let speed = snake.isBoosting ? SNConst.boostSpeed : SNConst.baseSpeed
        let angle = atan2(snake.targetY - head.y, snake.targetX - head.x)

        var newX = head.x + cos(angle) * speed * dt
        var newY = head.y + sin(angle) * speed * dt

        // Clamp to arena
        let dx = newX - SNConst.arenaCenter.x
        let dy = newY - SNConst.arenaCenter.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist > SNConst.arenaRadius - 10 {
            newX = SNConst.arenaCenter.x + dx / dist * (SNConst.arenaRadius - 10)
            newY = SNConst.arenaCenter.y + dy / dist * (SNConst.arenaRadius - 10)
        }

        let newHead = CGPoint(x: newX, y: newY)

        // Append to path history
        snake.pathHistory.append(newHead)

        // Trim path history (keep enough for all segments)
        let maxPathLen = snake.segments.count * 3 + 50
        if snake.pathHistory.count > maxPathLen {
            snake.pathHistory.removeFirst(snake.pathHistory.count - maxPathLen)
        }

        // Place head
        snake.segments[0] = newHead

        // Place body segments along path history at SEGMENT_SPACING intervals
        let spacing = SNConst.segmentSpacing
        var distanceNeeded: CGFloat = spacing
        var pathIdx = snake.pathHistory.count - 1
        var prevPoint = newHead

        for segIdx in 1..<snake.segments.count {
            var placed = false
            while pathIdx > 0 {
                let pathPoint = snake.pathHistory[pathIdx - 1]
                let segDx = prevPoint.x - pathPoint.x
                let segDy = prevPoint.y - pathPoint.y
                let segDist = sqrt(segDx * segDx + segDy * segDy)

                if segDist >= distanceNeeded {
                    let ratio = distanceNeeded / segDist
                    let px = prevPoint.x - segDx * ratio
                    let py = prevPoint.y - segDy * ratio
                    snake.segments[segIdx] = CGPoint(x: px, y: py)
                    prevPoint = CGPoint(x: px, y: py)
                    distanceNeeded = spacing
                    placed = true
                    break
                } else {
                    distanceNeeded -= segDist
                    prevPoint = pathPoint
                    pathIdx -= 1
                }
            }
            if !placed {
                // Not enough path history — just leave segment where it is, it'll catch up
                break
            }
        }

        // Boost consumes length
        if snake.isBoosting && snake.segments.count > SNConst.minBoostLength {
            // Lose a segment every few frames when boosting
            if Int.random(in: 0..<6) == 0 {
                let lastSeg = snake.segments.removeLast()
                // Drop a small orb at the tail
                spawnOrbAt(position: lastSeg)
                snake.score = max(0, snake.score - 1)
            }
        }
    }

    // MARK: - Collision Detection

    private func checkCollisions() {
        let hitRadius: CGFloat = 10

        for (id, snake) in snakes where snake.isAlive {
            let head = snake.segments[0]

            // Head-to-boundary
            let dx = head.x - SNConst.arenaCenter.x
            let dy = head.y - SNConst.arenaCenter.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist > SNConst.arenaRadius - hitRadius {
                killSnake(id: id, killerName: "Arena Boundary")
                continue
            }

            // Head-to-body (other snakes only)
            for (otherId, other) in snakes where otherId != id && other.isAlive {
                // Skip first 3 segments of other snake (head area)
                let checkSegments = other.segments.dropFirst(3)
                for seg in checkSegments {
                    let sdx = head.x - seg.x
                    let sdy = head.y - seg.y
                    if sdx * sdx + sdy * sdy < (hitRadius * 2) * (hitRadius * 2) {
                        killSnake(id: id, killerName: other.name)
                        // Credit the kill to the other snake
                        if var killer = snakes[otherId] {
                            killer.kills += 1
                            killer.score += 10
                            snakes[otherId] = killer
                            if otherId == localPlayerId {
                                onKill?(snake.name)
                            }
                        }
                        break
                    }
                }
                if snakes[id]?.isAlive == false { break }
            }
        }
    }

    private func killSnake(id: String, killerName: String) {
        guard var snake = snakes[id] else { return }
        snake.isAlive = false
        snakes[id] = snake

        // Drop orbs along body
        for (i, seg) in snake.segments.enumerated() {
            if i % 4 == 0 { // Every 4th segment
                spawnOrbAt(position: seg)
            }
        }

        if id == localPlayerId {
            localPlayerDead = true
            isGameRunning = false
            onDeath?(killerName)
        } else if snake.isBot {
            // Schedule bot respawn
            var deadBot = snakes[id]!
            deadBot.respawnTimer = 3.0
            snakes[id] = deadBot
        }
    }

    // MARK: - Respawns (bots)

    private func updateRespawns(dt: CGFloat) {
        for (id, var snake) in snakes where snake.isBot && !snake.isAlive {
            snake.respawnTimer -= Double(dt)
            if snake.respawnTimer <= 0 {
                // Respawn bot
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let dist = CGFloat.random(in: 400...1500)
                let bx = SNConst.arenaCenter.x + cos(angle) * dist
                let by = SNConst.arenaCenter.y + sin(angle) * dist
                let startLen = Int.random(in: 15...25)

                var newSegments: [CGPoint] = []
                for j in 0..<startLen {
                    newSegments.append(CGPoint(x: bx, y: by + CGFloat(j) * SNConst.segmentSpacing))
                }

                snake.segments = newSegments
                snake.pathHistory = [CGPoint(x: bx, y: by)]
                snake.isAlive = true
                snake.isBoosting = false
                snake.score = Int.random(in: 5...15)
                snake.kills = 0
                snake.targetX = bx + CGFloat.random(in: -200...200)
                snake.targetY = by + CGFloat.random(in: -200...200)
                snake.respawnTimer = Double.random(in: 1.0...3.0)
            }
            snakes[id] = snake
        }
    }

    // MARK: - Orb System

    private func spawnOrb() {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let dist = CGFloat.random(in: 0...(SNConst.arenaRadius - 50))
        let pos = CGPoint(
            x: SNConst.arenaCenter.x + cos(angle) * dist,
            y: SNConst.arenaCenter.y + sin(angle) * dist
        )
        spawnOrbAt(position: pos)
    }

    private func spawnOrbAt(position: CGPoint) {
        orbIdCounter += 1
        let id = "orb_\(orbIdCounter)"
        orbData[id] = OrbData(id: id, position: position, colorIndex: Int.random(in: 0...6))
    }

    private func updateOrbCollection() {
        let eatRadius: CGFloat = 15

        var orbsToRemove: [String] = []

        for (id, snake) in snakes where snake.isAlive {
            let head = snake.segments[0]

            for (orbId, orb) in orbData {
                let dx = head.x - orb.position.x
                let dy = head.y - orb.position.y
                if dx * dx + dy * dy < eatRadius * eatRadius {
                    orbsToRemove.append(orbId)

                    // Grow snake
                    if var s = snakes[id] {
                        s.score += 1
                        // Add 2 segments at the tail
                        let tail = s.segments.last ?? head
                        s.segments.append(tail)
                        s.segments.append(tail)
                        snakes[id] = s
                    }
                }
            }
        }

        for orbId in orbsToRemove {
            orbData.removeValue(forKey: orbId)
        }
    }

    private func maintainOrbs() {
        if orbData.count < 150 {
            let toSpawn = 200 - orbData.count
            for _ in 0..<min(toSpawn, 5) { // Spawn a few per frame
                spawnOrb()
            }
        }
    }

    // MARK: - Leaderboard

    private func updateLeaderboard() {
        let sorted = snakes.values
            .filter { $0.isAlive }
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { LeaderboardEntry(id: $0.id, name: $0.name, score: $0.score) }

        onLeaderboardChange?(Array(sorted))
    }

    // MARK: - Sync render state from game data

    private func syncRenderState() {
        // No-op: renderSnakes/renderOrbs read directly from snakes/orbData
    }

    // MARK: - Camera

    private func updateCamera(dt: CGFloat) {
        if let localSnake = snakes[localPlayerId], localSnake.isAlive {
            let head = localSnake.segments[0]
            targetCameraPos = CGPoint(x: head.x, y: -head.y + SNConst.arenaCenter.y * 2)
        }

        let dx = targetCameraPos.x - cameraNode.position.x
        let dy = targetCameraPos.y - cameraNode.position.y

        let springForceX = dx * SNConst.cameraSpringStiffness
        let springForceY = dy * SNConst.cameraSpringStiffness

        cameraVelocity.x += (springForceX - cameraVelocity.x * SNConst.cameraSpringDamping) * dt
        cameraVelocity.y += (springForceY - cameraVelocity.y * SNConst.cameraSpringDamping) * dt

        cameraNode.position.x += cameraVelocity.x * dt
        cameraNode.position.y += cameraVelocity.y * dt
    }

    // MARK: - Grid Dots

    private var gridDotsNode: SKNode?
    private var lastGridCenter = CGPoint.zero

    private func updateGridDots() {
        let camPos = cameraNode.position
        let gridStep: CGFloat = 80

        let moved = abs(camPos.x - lastGridCenter.x) + abs(camPos.y - lastGridCenter.y)
        guard moved > gridStep * 2 || gridDotsNode == nil else { return }
        lastGridCenter = camPos

        gridDotsNode?.removeFromParent()
        let node = SKNode()
        node.zPosition = 1

        let viewW = (size.width / SNConst.mobileZoom) / 2 + gridStep
        let viewH = (size.height / SNConst.mobileZoom) / 2 + gridStep

        let startX = (floor((camPos.x - viewW) / gridStep)) * gridStep
        let endX = camPos.x + viewW
        let startY = (floor((camPos.y - viewH) / gridStep)) * gridStep
        let endY = camPos.y + viewH

        var x = startX
        while x <= endX {
            var y = startY
            while y <= endY {
                let dx = x - SNConst.arenaCenter.x
                let dy = y - (SNConst.arenaCenter.y * 2 - SNConst.arenaCenter.y)
                if dx * dx + dy * dy < SNConst.arenaRadius * SNConst.arenaRadius {
                    let dot = SKShapeNode(circleOfRadius: 1.5)
                    dot.position = CGPoint(x: x, y: y)
                    dot.fillColor = SNColors.gridDot
                    dot.strokeColor = .clear
                    node.addChild(dot)
                }
                y += gridStep
            }
            x += gridStep
        }

        addChild(node)
        gridDotsNode = node
    }

    // MARK: - Render Orbs

    private func renderOrbs() {
        var currentIds = Set<String>()

        for (id, orb) in orbData {
            currentIds.insert(id)

            if let existing = activeOrbs[id] {
                existing.position = CGPoint(x: orb.position.x, y: -orb.position.y + SNConst.arenaCenter.y * 2)
            } else {
                let sprite: SKSpriteNode
                if let pooled = orbPool.popLast() {
                    sprite = pooled
                    sprite.alpha = 0
                } else {
                    sprite = SKSpriteNode(texture: orbTexture)
                    sprite.size = CGSize(width: SNConst.orbTextureSize * 1.5, height: SNConst.orbTextureSize * 1.5)
                }
                sprite.position = CGPoint(x: orb.position.x, y: -orb.position.y + SNConst.arenaCenter.y * 2)
                sprite.run(.fadeIn(withDuration: 0.3))
                orbsNode.addChild(sprite)
                activeOrbs[id] = sprite
            }
        }

        for (id, sprite) in activeOrbs where !currentIds.contains(id) {
            sprite.run(.sequence([
                .fadeOut(withDuration: 0.2),
                .removeFromParent()
            ])) { [weak self] in
                self?.orbPool.append(sprite)
            }
            activeOrbs.removeValue(forKey: id)
        }
    }

    // MARK: - Render Snakes

    private func renderSnakes() {
        var currentIds = Set<String>()

        for (_, snake) in snakes where snake.isAlive && !snake.segments.isEmpty {
            currentIds.insert(snake.id)
            renderSnake(snake)
        }

        for (id, node) in snakeNodeCache where !currentIds.contains(id) {
            node.removeFromParent()
            for child in node.children {
                if let sprite = child as? SKSpriteNode {
                    sprite.removeFromParent()
                    segmentPool.append(sprite)
                }
            }
            snakeNodeCache.removeValue(forKey: id)
            namesNode.children.first(where: { $0.name == "name_\(id)" })?.removeFromParent()
        }
    }

    private func renderSnake(_ snake: SnakeData) {
        let skinIndex = max(0, min(snake.skin, SNConst.snakeSkins.count - 1))
        let segCount = snake.segments.count
        let baseWidth = SNConst.baseSegmentWidth + min(CGFloat(segCount) * 0.15, SNConst.maxExtraWidth)
        let isBoosting = snake.isBoosting
        let isLocal = snake.id == localPlayerId

        let container: SKNode
        if let existing = snakeNodeCache[snake.id] {
            container = existing
        } else {
            container = SKNode()
            container.zPosition = isLocal ? 25 : 20
            snakesNode.addChild(container)
            snakeNodeCache[snake.id] = container
        }

        while container.children.count < segCount + 1 {
            let sprite: SKSpriteNode
            if let pooled = segmentPool.popLast() {
                sprite = pooled
            } else {
                sprite = SKSpriteNode()
            }
            container.addChild(sprite)
        }

        while container.children.count > segCount + 1 {
            if let last = container.children.last as? SKSpriteNode {
                last.removeFromParent()
                segmentPool.append(last)
            }
        }

        let segTexture = isBoosting ? boostTextures[skinIndex] : segmentTextures[skinIndex]
        let headTex = isBoosting ? boostHeadTextures[skinIndex] : headTextures[skinIndex]

        for i in (0..<segCount).reversed() {
            let childIndex = segCount - i
            guard childIndex < container.children.count,
                  let sprite = container.children[childIndex] as? SKSpriteNode else { continue }

            let seg = snake.segments[i]
            sprite.position = CGPoint(x: seg.x, y: -seg.y + SNConst.arenaCenter.y * 2)
            sprite.texture = segTexture
            let segWidth = baseWidth * (i == 0 ? 1.0 : max(0.6, 1.0 - CGFloat(i) * 0.002))
            sprite.size = CGSize(width: segWidth * 1.5, height: segWidth * 1.5)
            sprite.alpha = max(0.4, 1.0 - CGFloat(i) * 0.003)
            sprite.zPosition = CGFloat(segCount - i)
        }

        if let headSprite = container.children.first as? SKSpriteNode {
            let headPos = snake.segments[0]
            headSprite.position = CGPoint(x: headPos.x, y: -headPos.y + SNConst.arenaCenter.y * 2)
            headSprite.texture = headTex
            let headSize = baseWidth * SNConst.headScale * 2 * 1.3
            headSprite.size = CGSize(width: headSize, height: headSize)
            headSprite.zPosition = CGFloat(segCount + 1)
        }

        let headPos = snake.segments[0]
        let nameKey = "name_\(snake.id)"
        let nameLabel: SKLabelNode
        if let existing = namesNode.children.first(where: { $0.name == nameKey }) as? SKLabelNode {
            nameLabel = existing
        } else {
            nameLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
            nameLabel.fontSize = 12
            nameLabel.fontColor = .white
            nameLabel.name = nameKey
            namesNode.addChild(nameLabel)
        }
        nameLabel.text = snake.name.isEmpty ? "Player" : snake.name
        nameLabel.position = CGPoint(
            x: headPos.x,
            y: -headPos.y + SNConst.arenaCenter.y * 2 + baseWidth * SNConst.headScale + 12
        )
    }

    // MARK: - Death Flash

    func showDeathFlash() {
        let flashSize = CGSize(width: size.width * 3, height: size.height * 3)
        let flash = SKSpriteNode(color: SNColors.uiDanger.withAlphaComponent(0.4), size: flashSize)
        flash.position = cameraNode.position
        flash.zPosition = 100
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.8),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Cleanup

    func cleanup() {
        removeAllChildren()
        removeAllActions()
        orbPool.removeAll()
        activeOrbs.removeAll()
        snakeNodeCache.removeAll()
        segmentPool.removeAll()
        snakes.removeAll()
        orbData.removeAll()
        isGameRunning = false
    }
}
