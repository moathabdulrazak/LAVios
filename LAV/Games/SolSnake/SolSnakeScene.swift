import SpriteKit

final class SolSnakeScene: SKScene {

    // MARK: - Rendering Properties

    private let cameraNode = SKCameraNode()
    private var backgroundSprite: SKSpriteNode?
    private var orbsNode = SKNode()
    private var snakesNode = SKNode()
    private var namesNode = SKNode()

    // Pre-rendered textures
    private var orbTexture: SKTexture?
    private var headTextures: [Int: SKTexture] = [:]       // skin -> head glow
    private var boostHeadTextures: [Int: SKTexture] = [:]

    // Orb pool
    private var orbPool: [SKSpriteNode] = []
    private var activeOrbs: [String: SKSpriteNode] = [:]

    // Snake rendering: SKShapeNode path per snake layer
    private struct SnakeRenderData {
        var glowPath: SKShapeNode     // outer glow
        var corePath: SKShapeNode     // core
        var spinePath: SKShapeNode    // bright spine
        var headGlow: SKSpriteNode    // head outer
        var headCore: SKSpriteNode    // head inner
        var headDot: SKSpriteNode     // white center
    }
    private var snakeRenderCache: [String: SnakeRenderData] = [:]

    // Camera smoothing
    private var cameraVelocity = CGPoint.zero
    private var targetCameraPos = SNConst.arenaCenter

    // Render state
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Game Engine Properties

    private var snakes: [String: SnakeData] = [:]
    private var orbData: [String: OrbData] = [:]
    private var orbIdCounter: Int = 0
    private var isGameRunning = false
    private var localPlayerDead = false
    private var localPlayerId = "local"

    // Online mode: skip local game logic, render server state
    var isOnlineMode = false

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

    // Leaderboard throttle
    private var leaderboardTimer: CGFloat = 0

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
        createBackgroundTexture()

        orbsNode.zPosition = 10
        addChild(orbsNode)

        snakesNode.zPosition = 20
        addChild(snakesNode)

        namesNode.zPosition = 30
        addChild(namesNode)
    }

    // MARK: - Texture Generation

    private func createTextures() {
        // Orb: white center -> cyan -> transparent (matching web radial gradient)
        let orbDiam: CGFloat = 32
        orbTexture = SKTexture(image: renderOrbImage(size: orbDiam))

        // Head textures per skin
        for (i, skin) in SNConst.snakeSkins.enumerated() {
            let coreColor = skin.colors.count > 2 ? skin.colors[2] : skin.colors[0]
            let edgeColor = skin.colors.count > 1 ? skin.colors[1] : skin.colors[0]
            headTextures[i] = SKTexture(image: renderHeadImage(
                size: 32, coreColor: coreColor, edgeColor: edgeColor
            ))
            boostHeadTextures[i] = SKTexture(image: renderHeadImage(
                size: 32, coreColor: skin.boostColor, edgeColor: skin.boostColor
            ))
        }
    }

    private func renderOrbImage(size: CGFloat) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: fmt)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let center = CGPoint(x: size / 2, y: size / 2)
            let colors: [CGColor] = [
                UIColor.white.cgColor,
                SNColors.orbCyan.cgColor,
                SNColors.orbCyan.withAlphaComponent(0.65).cgColor,
                SNColors.orbCyan.withAlphaComponent(0.25).cgColor,
                UIColor.clear.cgColor
            ]
            let locations: [CGFloat] = [0, 0.15, 0.4, 0.7, 1.0]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors as CFArray,
                                            locations: locations) else { return }
            cg.drawRadialGradient(gradient,
                                  startCenter: center, startRadius: 0,
                                  endCenter: center, endRadius: size / 2,
                                  options: [])
        }
    }

    private func renderHeadImage(size: CGFloat, coreColor: UIColor, edgeColor: UIColor) -> UIImage {
        let totalSize = size * 2 // extra space for glow
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalSize, height: totalSize), format: fmt)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let center = CGPoint(x: totalSize / 2, y: totalSize / 2)

            // Outer glow
            let glowColors: [CGColor] = [
                edgeColor.withAlphaComponent(0.6).cgColor,
                edgeColor.withAlphaComponent(0.2).cgColor,
                UIColor.clear.cgColor
            ]
            let glowLocs: [CGFloat] = [0, 0.5, 1.0]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: glowColors as CFArray, locations: glowLocs) {
                cg.drawRadialGradient(g, startCenter: center, startRadius: 0,
                                      endCenter: center, endRadius: totalSize / 2, options: [])
            }

            // Core circle
            let coreR = size * 0.5
            cg.setFillColor(coreColor.cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - coreR, y: center.y - coreR,
                                      width: coreR * 2, height: coreR * 2))

            // White center dot
            let dotR = size * 0.2
            cg.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - dotR, y: center.y - dotR,
                                      width: dotR * 2, height: dotR * 2))
        }
    }

    // MARK: - Pre-rendered Background

    private func createBackgroundTexture() {
        // Render the entire arena background to a single texture.
        // Scale down to fit within Metal's 8192 max texture size.
        // Arena is 4000x4000, we need ~5200x5200 coverage (with padding).
        // Render at 0.35x scale -> 2450px image, then SpriteKit displays at 7000pt.
        let scale: CGFloat = 0.35
        let canvasSize = Int(7000 * scale)
        let offset: CGFloat = 1500 * scale
        let centerX = SNConst.arenaCenter.x * scale + offset
        let centerY = SNConst.arenaCenter.y * scale + offset
        let radius = SNConst.arenaRadius * scale

        // Force scale=1 so UIGraphicsImageRenderer doesn't multiply by device scale (3x)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize, height: canvasSize), format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext

            // 1. Fill with deep dark
            cg.setFillColor(UIColor(red: 3/255, green: 5/255, blue: 8/255, alpha: 1).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

            // 2. Radial gradient background (center brighter)
            let bgColors: [CGColor] = [
                UIColor(red: 10/255, green: 16/255, blue: 32/255, alpha: 1).cgColor,
                UIColor(red: 6/255, green: 12/255, blue: 20/255, alpha: 1).cgColor,
                UIColor(red: 3/255, green: 5/255, blue: 8/255, alpha: 1).cgColor
            ]
            let bgLocs: [CGFloat] = [0, 0.5, 1.0]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: bgColors as CFArray, locations: bgLocs) {
                cg.drawRadialGradient(g, startCenter: CGPoint(x: centerX, y: centerY), startRadius: 0,
                                      endCenter: CGPoint(x: centerX, y: centerY), endRadius: radius + 200 * scale, options: [])
            }

            // 3. Arena fill (slightly lighter circle)
            cg.setFillColor(UIColor(red: 10/255, green: 15/255, blue: 24/255, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: centerX - radius - 25 * scale, y: centerY - radius - 25 * scale,
                                      width: (radius + 25 * scale) * 2, height: (radius + 25 * scale) * 2))

            // 4. Grid dots (every 80px, inside arena)
            let gridStep: CGFloat = 80 * scale
            var gx = offset
            while gx < offset + 4100 * scale {
                var gy = offset
                while gy < offset + 4100 * scale {
                    let dx = gx - centerX
                    let dy = gy - centerY
                    let dist = sqrt(dx * dx + dy * dy)
                    if dist < radius - 100 * scale {
                        let fade = 1 - (dist / radius) * 0.5
                        cg.setFillColor(UIColor(red: 0, green: 210/255, blue: 1, alpha: 0.12 * fade).cgColor)
                        cg.fillEllipse(in: CGRect(x: gx - 1.5 * scale, y: gy - 1.5 * scale,
                                                  width: 3 * scale, height: 3 * scale))
                    }
                    gy += gridStep
                }
                gx += gridStep
            }

            // 5. Outer glow gradient for boundary
            let glowColors: [CGColor] = [
                UIColor.clear.cgColor,
                UIColor(red: 0, green: 212/255, blue: 1, alpha: 0.03).cgColor,
                UIColor(red: 0, green: 212/255, blue: 1, alpha: 0.08).cgColor,
                UIColor(red: 0, green: 212/255, blue: 1, alpha: 0.2).cgColor
            ]
            let glowLocs: [CGFloat] = [0, 0.5, 0.8, 1.0]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: glowColors as CFArray, locations: glowLocs) {
                // Ring-shaped gradient using clipping
                cg.saveGState()
                let outerR = radius + 80 * scale
                let innerR = radius - 100 * scale
                cg.addEllipse(in: CGRect(x: centerX - outerR, y: centerY - outerR,
                                         width: outerR * 2, height: outerR * 2))
                cg.addEllipse(in: CGRect(x: centerX - innerR, y: centerY - innerR,
                                         width: innerR * 2, height: innerR * 2))
                cg.clip(using: .evenOdd)
                cg.drawRadialGradient(g, startCenter: CGPoint(x: centerX, y: centerY), startRadius: innerR,
                                      endCenter: CGPoint(x: centerX, y: centerY), endRadius: outerR, options: [])
                cg.restoreGState()
            }

            // 6. Layered glow rings (no shadowBlur, just multiple strokes)
            for i in stride(from: 6, through: 0, by: -1) {
                let ci = CGFloat(i)
                cg.setStrokeColor(UIColor(red: 0, green: 212/255, blue: 1, alpha: 0.12 - ci * 0.018).cgColor)
                cg.setLineWidth((4 + ci * 3) * scale)
                cg.strokeEllipse(in: CGRect(x: centerX - radius - ci * 3 * scale,
                                            y: centerY - radius - ci * 3 * scale,
                                            width: (radius + ci * 3 * scale) * 2,
                                            height: (radius + ci * 3 * scale) * 2))
            }

            // 7. Main boundary ring
            cg.setStrokeColor(UIColor(red: 0, green: 212/255, blue: 1, alpha: 0.7).cgColor)
            cg.setLineWidth(3 * scale)
            cg.strokeEllipse(in: CGRect(x: centerX - radius, y: centerY - radius,
                                        width: radius * 2, height: radius * 2))

            // 8. Warning ring (dashed)
            let warnR = radius - 40 * scale
            cg.setStrokeColor(UIColor(red: 1, green: 42/255, blue: 109/255, alpha: 0.35).cgColor)
            cg.setLineWidth(2 * scale)
            cg.setLineDash(phase: 0, lengths: [30 * scale, 15 * scale])
            cg.strokeEllipse(in: CGRect(x: centerX - warnR, y: centerY - warnR,
                                        width: warnR * 2, height: warnR * 2))
        }

        let texture = SKTexture(image: image)
        let sprite = SKSpriteNode(texture: texture)
        // Scale back up since we rendered at 0.5x
        sprite.size = CGSize(width: 7000, height: 7000)
        // SpriteKit Y is flipped vs game coords, position at arena center
        sprite.position = CGPoint(x: SNConst.arenaCenter.x, y: SNConst.arenaCenter.y)
        sprite.zPosition = 0
        addChild(sprite)
        backgroundSprite = sprite
    }

    // MARK: - Game Start

    func startGame() {
        // Clear previous game render nodes
        for (_, rd) in snakeRenderCache {
            rd.glowPath.removeFromParent()
            rd.corePath.removeFromParent()
            rd.spinePath.removeFromParent()
            rd.headGlow.removeFromParent()
            rd.headCore.removeFromParent()
            rd.headDot.removeFromParent()
        }
        snakeRenderCache.removeAll()
        namesNode.removeAllChildren()

        snakes.removeAll()
        orbData.removeAll()
        orbIdCounter = 0
        localPlayerDead = false

        // Create local player at arena center
        let center = SNConst.arenaCenter
        let playerSkin = Int.random(in: 0..<SNConst.snakeSkins.count)
        let playerLen = 10
        var playerSegments: [CGPoint] = []
        var playerPath: [CGPoint] = []
        // Segments: head at index 0, tail at end. Laid out going downward.
        for i in 0..<playerLen {
            playerSegments.append(CGPoint(x: center.x, y: center.y + CGFloat(i) * SNConst.segmentSpacing))
        }
        // Path history: oldest (tail) first, newest (head) last
        for i in stride(from: playerLen - 1, through: 0, by: -1) {
            playerPath.append(CGPoint(x: center.x, y: center.y + CGFloat(i) * SNConst.segmentSpacing))
        }
        var playerSnake = SnakeData(
            id: localPlayerId, name: "You", skin: playerSkin,
            segments: playerSegments,
            pathHistory: playerPath,
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
            var botPath: [CGPoint] = []
            for j in 0..<startLen {
                botSegments.append(CGPoint(x: bx, y: by + CGFloat(j) * SNConst.segmentSpacing))
            }
            // Path history: tail first, head last
            for j in stride(from: startLen - 1, through: 0, by: -1) {
                botPath.append(CGPoint(x: bx, y: by + CGFloat(j) * SNConst.segmentSpacing))
            }

            var bot = SnakeData(
                id: botId, name: botNames[i], skin: botSkin,
                segments: botSegments,
                pathHistory: botPath,
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

    // MARK: - Online Mode

    /// Start game in online mode (no local entities created)
    func startOnlineGame(localId: String) {
        // Clear previous render nodes
        for (_, rd) in snakeRenderCache {
            rd.glowPath.removeFromParent()
            rd.corePath.removeFromParent()
            rd.spinePath.removeFromParent()
            rd.headGlow.removeFromParent()
            rd.headCore.removeFromParent()
            rd.headDot.removeFromParent()
        }
        snakeRenderCache.removeAll()
        namesNode.removeAllChildren()

        snakes.removeAll()
        orbData.removeAll()
        localPlayerDead = false
        localPlayerId = localId
        isOnlineMode = true
        isGameRunning = true
    }

    /// Update game state from server (online mode)
    func updateRemoteState(players: [String: PlayerState], orbs: [String: OrbState]) {
        // Convert PlayerState → SnakeData for rendering
        var newSnakes: [String: SnakeData] = [:]
        for (id, player) in players {
            var snake = SnakeData(
                id: id, name: player.name, skin: player.skin,
                segments: player.segments, pathHistory: [],
                isBot: false
            )
            snake.score = player.score
            snake.kills = player.kills
            snake.isAlive = player.isAlive
            snake.isBoosting = player.isBoosting
            newSnakes[id] = snake
        }
        snakes = newSnakes

        // Convert OrbState → OrbData for rendering
        var newOrbs: [String: OrbData] = [:]
        for (id, orb) in orbs {
            newOrbs[id] = OrbData(id: id, position: orb.position, colorIndex: orb.colorIndex)
        }
        orbData = newOrbs
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

        if isGameRunning && !isOnlineMode {
            updateLocalPlayer(dt: dt)
            updateBots(dt: dt)
            checkCollisions()
            updateOrbCollection()
            maintainOrbs()
            updateRespawns(dt: dt)

            leaderboardTimer += dt
            if leaderboardTimer > 0.5 {
                leaderboardTimer = 0
                updateLeaderboard()
            }
        }

        updateCamera(dt: dt)
        renderOrbs()
        renderSnakes()
    }

    // MARK: - Local Player Movement

    private func updateLocalPlayer(dt: CGFloat) {
        guard var snake = snakes[localPlayerId], snake.isAlive else { return }

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

    private func updateBots(dt: CGFloat) {
        for (id, var snake) in snakes where snake.isBot && snake.isAlive {
            snake.respawnTimer -= Double(dt)
            if snake.respawnTimer <= 0 {
                snake.respawnTimer = Double.random(in: 1.0...3.0)
                pickBotTarget(&snake)
            }

            // Avoidance
            let head = snake.segments[0]
            let angle = atan2(snake.targetY - head.y, snake.targetX - head.x)
            let lookX = head.x + cos(angle) * 50
            let lookY = head.y + sin(angle) * 50

            var needsAvoid = false
            for (otherId, other) in snakes where otherId != id && other.isAlive {
                // Only check nearby segments for performance
                for seg in other.segments.prefix(30) {
                    let dx = lookX - seg.x
                    let dy = lookY - seg.y
                    if dx * dx + dy * dy < 2500 {
                        snake.targetX = head.x + sin(angle) * 200
                        snake.targetY = head.y - cos(angle) * 200
                        needsAvoid = true
                        break
                    }
                }
                if needsAvoid { break }
            }

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
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 100...400)
            var tx = head.x + cos(angle) * dist
            var ty = head.y + sin(angle) * dist
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

    // MARK: - Snake Movement

    private func moveSnake(_ snake: inout SnakeData, dt: CGFloat) {
        guard !snake.segments.isEmpty else { return }

        let head = snake.segments[0]
        let speed = snake.isBoosting ? SNConst.boostSpeed : SNConst.baseSpeed
        let angle = atan2(snake.targetY - head.y, snake.targetX - head.x)

        var newX = head.x + cos(angle) * speed * dt
        var newY = head.y + sin(angle) * speed * dt

        let dx = newX - SNConst.arenaCenter.x
        let dy = newY - SNConst.arenaCenter.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist > SNConst.arenaRadius - 10 {
            newX = SNConst.arenaCenter.x + dx / dist * (SNConst.arenaRadius - 10)
            newY = SNConst.arenaCenter.y + dy / dist * (SNConst.arenaRadius - 10)
        }

        let newHead = CGPoint(x: newX, y: newY)
        snake.pathHistory.append(newHead)

        let maxPathLen = snake.segments.count * 3 + 50
        if snake.pathHistory.count > maxPathLen {
            snake.pathHistory.removeFirst(snake.pathHistory.count - maxPathLen)
        }

        snake.segments[0] = newHead

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
            if !placed { break }
        }

        // Boost consumes length
        if snake.isBoosting && snake.segments.count > SNConst.minBoostLength {
            if Int.random(in: 0..<6) == 0 {
                let lastSeg = snake.segments.removeLast()
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

            // Boundary
            let dx = head.x - SNConst.arenaCenter.x
            let dy = head.y - SNConst.arenaCenter.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist > SNConst.arenaRadius - hitRadius {
                killSnake(id: id, killerName: "Arena Boundary")
                continue
            }

            // Head-to-body
            for (otherId, other) in snakes where otherId != id && other.isAlive {
                let checkSegs = other.segments.dropFirst(3)
                for seg in checkSegs {
                    let sdx = head.x - seg.x
                    let sdy = head.y - seg.y
                    if sdx * sdx + sdy * sdy < (hitRadius * 2) * (hitRadius * 2) {
                        killSnake(id: id, killerName: other.name)
                        if var killer = snakes[otherId] {
                            killer.kills += 1
                            killer.score += 10
                            snakes[otherId] = killer
                            if otherId == localPlayerId { onKill?(snake.name) }
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

        for (i, seg) in snake.segments.enumerated() {
            if i % 4 == 0 { spawnOrbAt(position: seg) }
        }

        if id == localPlayerId {
            localPlayerDead = true
            isGameRunning = false
            onDeath?(killerName)
        } else if snake.isBot {
            var deadBot = snakes[id]!
            deadBot.respawnTimer = 3.0
            snakes[id] = deadBot
        }
    }

    // MARK: - Respawns

    private func updateRespawns(dt: CGFloat) {
        for (id, var snake) in snakes where snake.isBot && !snake.isAlive {
            snake.respawnTimer -= Double(dt)
            if snake.respawnTimer <= 0 {
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let dist = CGFloat.random(in: 400...1500)
                let bx = SNConst.arenaCenter.x + cos(angle) * dist
                let by = SNConst.arenaCenter.y + sin(angle) * dist
                let startLen = Int.random(in: 15...25)

                var newSegments: [CGPoint] = []
                var newPath: [CGPoint] = []
                for j in 0..<startLen {
                    newSegments.append(CGPoint(x: bx, y: by + CGFloat(j) * SNConst.segmentSpacing))
                }
                for j in stride(from: startLen - 1, through: 0, by: -1) {
                    newPath.append(CGPoint(x: bx, y: by + CGFloat(j) * SNConst.segmentSpacing))
                }

                snake.segments = newSegments
                snake.pathHistory = newPath
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
        orbData[id] = OrbData(id: id, position: position, colorIndex: 0)
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
                    if var s = snakes[id] {
                        s.score += 1
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
            for _ in 0..<min(toSpawn, 5) {
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

    // MARK: - Camera

    private func updateCamera(dt: CGFloat) {
        if let localSnake = snakes[localPlayerId], localSnake.isAlive {
            let head = localSnake.segments[0]
            targetCameraPos = CGPoint(x: head.x, y: -head.y + SNConst.arenaCenter.y * 2)
        }

        let dx = targetCameraPos.x - cameraNode.position.x
        let dy = targetCameraPos.y - cameraNode.position.y

        cameraVelocity.x += (dx * SNConst.cameraSpringStiffness - cameraVelocity.x * SNConst.cameraSpringDamping) * dt
        cameraVelocity.y += (dy * SNConst.cameraSpringStiffness - cameraVelocity.y * SNConst.cameraSpringDamping) * dt

        cameraNode.position.x += cameraVelocity.x * dt
        cameraNode.position.y += cameraVelocity.y * dt
    }

    // MARK: - Render Orbs (with frustum culling)

    private func renderOrbs() {
        let camPos = cameraNode.position
        let viewW = (size.width / SNConst.mobileZoom) / 2 + 50
        let viewH = (size.height / SNConst.mobileZoom) / 2 + 50

        var currentIds = Set<String>()

        for (id, orb) in orbData {
            // Frustum culling: skip orbs far from camera
            let screenX = orb.position.x
            let screenY = -orb.position.y + SNConst.arenaCenter.y * 2
            if abs(screenX - camPos.x) > viewW || abs(screenY - camPos.y) > viewH {
                // Remove if it was visible before
                if let sprite = activeOrbs[id] {
                    sprite.removeFromParent()
                    orbPool.append(sprite)
                    activeOrbs.removeValue(forKey: id)
                }
                continue
            }

            currentIds.insert(id)

            if let existing = activeOrbs[id] {
                existing.position = CGPoint(x: screenX, y: screenY)
            } else {
                let sprite: SKSpriteNode
                if let pooled = orbPool.popLast() {
                    sprite = pooled
                    sprite.alpha = 1
                } else {
                    sprite = SKSpriteNode(texture: orbTexture)
                    sprite.size = CGSize(width: 28, height: 28)
                    sprite.blendMode = .add
                }
                sprite.position = CGPoint(x: screenX, y: screenY)
                orbsNode.addChild(sprite)
                activeOrbs[id] = sprite
            }
        }

        // Remove orbs no longer in data
        for (id, sprite) in activeOrbs where !currentIds.contains(id) {
            sprite.removeFromParent()
            orbPool.append(sprite)
            activeOrbs.removeValue(forKey: id)
        }
    }

    // MARK: - Render Snakes (SKShapeNode paths for smooth tubes)

    private func renderSnakes() {
        var aliveIds = Set<String>()

        for (_, snake) in snakes where snake.isAlive && snake.segments.count >= 2 {
            aliveIds.insert(snake.id)
            renderSnake(snake)
        }

        // Remove dead snakes' render nodes
        for (id, rd) in snakeRenderCache where !aliveIds.contains(id) {
            rd.glowPath.removeFromParent()
            rd.corePath.removeFromParent()
            rd.spinePath.removeFromParent()
            rd.headGlow.removeFromParent()
            rd.headCore.removeFromParent()
            rd.headDot.removeFromParent()
            snakeRenderCache.removeValue(forKey: id)
            namesNode.children.first(where: { $0.name == "name_\(id)" })?.removeFromParent()
        }
    }

    private func renderSnake(_ snake: SnakeData) {
        let skinIndex = max(0, min(snake.skin, SNConst.snakeSkins.count - 1))
        let skin = SNConst.snakeSkins[skinIndex]
        let segCount = snake.segments.count
        let baseWidth = SNConst.baseSegmentWidth + min(CGFloat(segCount) * 0.15, SNConst.maxExtraWidth)
        let isLocal = snake.id == localPlayerId
        let isBoosting = snake.isBoosting

        // Colors
        let edgeColor = skin.colors.count > 1 ? skin.colors[1] : skin.colors[0]
        let coreColor = skin.colors.count > 2 ? skin.colors[2] : skin.colors[0]

        let glowColor: UIColor
        let mainColor: UIColor
        let spineColor: UIColor

        if isBoosting {
            glowColor = skin.boostColor.withAlphaComponent(0.4)
            mainColor = skin.boostColor.withAlphaComponent(0.8)
            spineColor = UIColor.white.withAlphaComponent(0.9)
        } else {
            glowColor = edgeColor.withAlphaComponent(0.25)
            mainColor = coreColor
            spineColor = UIColor.white.withAlphaComponent(0.4)
        }

        // Build CGPath from segments (with Y flip)
        let path = CGMutablePath()
        let firstSeg = snake.segments[0]
        path.move(to: CGPoint(x: firstSeg.x, y: -firstSeg.y + SNConst.arenaCenter.y * 2))

        for i in 1..<segCount {
            let seg = snake.segments[i]
            path.addLine(to: CGPoint(x: seg.x, y: -seg.y + SNConst.arenaCenter.y * 2))
        }

        // Get or create render nodes
        let rd: SnakeRenderData
        if let existing = snakeRenderCache[snake.id] {
            rd = existing
        } else {
            let glow = SKShapeNode()
            glow.lineCap = .round
            glow.lineJoin = .round
            glow.fillColor = .clear
            glow.zPosition = isLocal ? 21 : 20
            snakesNode.addChild(glow)

            let core = SKShapeNode()
            core.lineCap = .round
            core.lineJoin = .round
            core.fillColor = .clear
            core.zPosition = isLocal ? 23 : 22
            snakesNode.addChild(core)

            let spine = SKShapeNode()
            spine.lineCap = .round
            spine.lineJoin = .round
            spine.fillColor = .clear
            spine.zPosition = isLocal ? 24 : 23
            snakesNode.addChild(spine)

            let headGlowSprite = SKSpriteNode()
            headGlowSprite.blendMode = .add
            headGlowSprite.zPosition = isLocal ? 26 : 24
            snakesNode.addChild(headGlowSprite)

            let headCoreSprite = SKSpriteNode()
            headCoreSprite.zPosition = isLocal ? 27 : 25
            snakesNode.addChild(headCoreSprite)

            let headDotSprite = SKSpriteNode(color: .white, size: CGSize(width: 4, height: 4))
            headDotSprite.zPosition = isLocal ? 28 : 26
            snakesNode.addChild(headDotSprite)

            rd = SnakeRenderData(glowPath: glow, corePath: core, spinePath: spine,
                                 headGlow: headGlowSprite, headCore: headCoreSprite, headDot: headDotSprite)
            snakeRenderCache[snake.id] = rd
        }

        // Update paths
        rd.glowPath.path = path
        rd.glowPath.strokeColor = glowColor
        rd.glowPath.lineWidth = baseWidth * 1.5
        rd.glowPath.glowWidth = 0

        rd.corePath.path = path
        rd.corePath.strokeColor = mainColor
        rd.corePath.lineWidth = baseWidth * (isLocal ? 1.0 : 0.9)

        rd.spinePath.path = path
        rd.spinePath.strokeColor = spineColor
        rd.spinePath.lineWidth = baseWidth * 0.12

        // Head
        let headPos = snake.segments[0]
        let headScreen = CGPoint(x: headPos.x, y: -headPos.y + SNConst.arenaCenter.y * 2)
        let headRadius = baseWidth * SNConst.headScale

        let headTex = isBoosting ? boostHeadTextures[skinIndex] : headTextures[skinIndex]
        rd.headGlow.texture = headTex
        rd.headGlow.size = CGSize(width: headRadius * 4, height: headRadius * 4)
        rd.headGlow.position = headScreen

        rd.headCore.texture = headTex
        rd.headCore.size = CGSize(width: headRadius * 2.5, height: headRadius * 2.5)
        rd.headCore.position = headScreen
        rd.headCore.blendMode = .alpha

        rd.headDot.position = headScreen
        let dotSize = headRadius * 0.6
        rd.headDot.size = CGSize(width: dotSize, height: dotSize)

        // Name label
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
        nameLabel.position = CGPoint(x: headScreen.x, y: headScreen.y + headRadius + 14)
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
        snakeRenderCache.removeAll()
        snakes.removeAll()
        orbData.removeAll()
        isGameRunning = false
    }
}
