import SpriteKit

// MARK: - Data Types

struct RSObstacle {
    let node: SKNode
    let topBar: SKSpriteNode
    let botBar: SKSpriteNode
    let topCap: SKSpriteNode
    let botCap: SKSpriteNode
    let topCapStripe: SKSpriteNode
    let botCapStripe: SKSpriteNode
    var x: CGFloat
    var gapY: CGFloat        // web coords
    var gapSize: CGFloat
    var baseGap: CGFloat
    var w: CGFloat
    var passed = false
    var type: String         // "pipe" or "laser"
    var ringsCollected = 0
    var id: Int
}

struct RSRing {
    let node: SKNode
    var x: CGFloat
    var y: CGFloat           // web coords
    var collected = false
    var pulse: CGFloat
    var forPipeId: Int
}

struct RSParticle {
    var x: CGFloat; var y: CGFloat
    var vx: CGFloat; var vy: CGFloat
    var r: CGFloat; var life: CGFloat
    var color: UIColor
    var type: String         // "circle", "star", "text"
    var text: String?
}

// MARK: - Simple LCG RNG (matches web SeededRandom)

final class RSRNG {
    var seed: Int

    init(seedStr: String) {
        var hash = 0
        for ch in seedStr.unicodeScalars {
            hash = ((hash << 5) &- hash) &+ Int(ch.value)
            hash = hash & hash
        }
        seed = abs(hash)
    }

    init() {
        seed = abs(Int(Date().timeIntervalSince1970 * 1000) ^ Int.random(in: 0..<Int.max))
    }

    func next() -> CGFloat {
        seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
        return CGFloat(seed) / CGFloat(0x7fffffff)
    }

    func nextFloat(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        lo + next() * (hi - lo)
    }

    func nextInt(_ lo: Int, _ hi: Int) -> Int {
        Int(next() * CGFloat(hi - lo + 1)) + lo
    }
}

// MARK: - Scene

final class RocketSolScene: SKScene {

    // Callbacks
    var onStateChange: ((RSGameState) -> Void)?
    var onScoreChange: ((Int) -> Void)?

    enum RSGameState { case waiting, playing, gameOver }

    private(set) var gameState: RSGameState = .waiting {
        didSet { onStateChange?(gameState) }
    }

    // Player state (web coords: y-down)
    private var px: CGFloat = RSConst.playerX
    private var py: CGFloat = RSConst.playerStartY
    private var vy: CGFloat = 0
    private var thrusting = false
    private var thrustFade: CGFloat = 0
    private var runPhase: CGFloat = 0
    private var landImpact: CGFloat = 0

    // World
    private var spd: CGFloat = RSConst.startSpeed
    private var dist: CGFloat = 0
    private var pts: CGFloat = 0
    private var t: Int = 0
    private var nextObs: CGFloat = RSConst.firstObsDist
    private var shake: CGFloat = 0
    private var flash: CGFloat = 0

    private var obstacles: [RSObstacle] = []
    private var rings: [RSRing] = []
    private var particles: [RSParticle] = []
    private var trail: [(x: CGFloat, y: CGFloat, life: CGFloat)] = []

    private var highScore: Int = 0
    private(set) var finalScore: Int = 0

    // Timestep
    private var lastTime: TimeInterval = 0
    private var accumulator: Double = 0

    // RNG
    private var rng = RSRNG()

    // Nodes
    private var worldNode = SKNode()
    private var bgNode = SKNode()
    private var playerNode = SKNode()
    private var obstaclesNode = SKNode()
    private var ringsNode = SKNode()
    private var fxNode = SKNode()
    private var flashNode = SKSpriteNode()

    // Character sub-nodes
    private var jetpackNode = SKNode()
    private var leftFlame = SKShapeNode()
    private var rightFlame = SKShapeNode()
    private var bodyNode = SKShapeNode()
    private var emblemNode = SKShapeNode()
    private var helmetNode = SKShapeNode()
    private var visorNode = SKShapeNode()
    private var antennaNode = SKShapeNode()
    private var antennaTip = SKShapeNode()
    private var backLeg = SKNode()
    private var frontLeg = SKNode()
    private var backArm = SKNode()
    private var frontArm = SKNode()
    private var trailNode = SKNode()
    private var flameGlow = SKShapeNode()

    // Background sub-nodes
    private var stars: [(node: SKShapeNode, twinkle: CGFloat, speed: CGFloat, baseAlpha: CGFloat)] = []
    private var mountains1: [(node: SKShapeNode, w: CGFloat)] = []
    private var mountains2: [(node: SKShapeNode, w: CGFloat)] = []
    private var groundLineNode = SKShapeNode()
    private var ceilLineNode = SKShapeNode()
    private var gridNode = SKNode()

    // MARK: - Setup

    override func didMove(to view: SKView) {
        self.size = CGSize(width: RSConst.gameW, height: RSConst.gameH)
        self.scaleMode = .aspectFit
        self.backgroundColor = UIColor(red: 0x0a/255, green: 0x06/255, blue: 0x12/255, alpha: 1)

        highScore = UserDefaults.standard.integer(forKey: "rocketsol_best")

        addChild(bgNode)
        addChild(worldNode)
        worldNode.addChild(obstaclesNode)
        worldNode.addChild(ringsNode)
        worldNode.addChild(trailNode)
        worldNode.addChild(playerNode)
        worldNode.addChild(fxNode)

        flashNode = SKSpriteNode(color: .white, size: self.size)
        flashNode.position = CGPoint(x: RSConst.gameW / 2, y: RSConst.gameH / 2)
        flashNode.alpha = 0
        flashNode.zPosition = 100
        addChild(flashNode)

        setupBackground()
        setupCharacter()
    }

    // MARK: - Background

    private func setupBackground() {
        // Sky gradient texture
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: RSConst.gameW, height: RSConst.gameH))
        let skyImage = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = RSConst.skyStops.map { $0.0.cgColor }
            let locations = RSConst.skyStops.map { $0.1 }
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors as CFArray,
                                            locations: locations) else { return }
            cg.drawLinearGradient(gradient,
                                  start: .zero,
                                  end: CGPoint(x: 0, y: RSConst.gameH),
                                  options: [])
        }
        let skySprite = SKSpriteNode(texture: SKTexture(image: skyImage), size: self.size)
        skySprite.position = CGPoint(x: RSConst.gameW / 2, y: RSConst.gameH / 2)
        skySprite.zPosition = -10
        bgNode.addChild(skySprite)

        // Stars
        for _ in 0..<120 {
            let s = SKShapeNode(circleOfRadius: rng.nextFloat(0.5, 2.5))
            s.fillColor = .white
            s.strokeColor = .clear
            s.position = CGPoint(x: rng.nextFloat(0, RSConst.gameW),
                                 y: skY(rng.nextFloat(0, RSConst.gameH * 0.6)))
            s.zPosition = -9
            let baseA = rng.nextFloat(0.3, 0.8)
            s.alpha = baseA
            bgNode.addChild(s)
            stars.append((node: s, twinkle: rng.nextFloat(0, .pi * 2),
                          speed: rng.nextFloat(0.5, 2), baseAlpha: baseA))
        }

        // Far mountains
        var mx: CGFloat = 0
        while mx < RSConst.gameW + 400 {
            let mw = rng.nextFloat(150, 350)
            let mh = rng.nextFloat(80, 200)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: mw * 0.5, y: mh))
            path.addLine(to: CGPoint(x: mw, y: 0))
            path.closeSubpath()
            let m = SKShapeNode(path: path)
            m.fillColor = RSConst.deepPurple1
            m.strokeColor = .clear
            m.position = CGPoint(x: mx, y: skY(RSConst.groundY))
            m.zPosition = -8
            bgNode.addChild(m)
            mountains1.append((node: m, w: mw))
            mx += mw * 0.7
        }

        // Near mountains
        mx = 0
        while mx < RSConst.gameW + 300 {
            let mw = rng.nextFloat(100, 250)
            let mh = rng.nextFloat(120, 300)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: mw * 0.5, y: mh))
            path.addLine(to: CGPoint(x: mw, y: 0))
            path.closeSubpath()
            let m = SKShapeNode(path: path)
            m.fillColor = RSConst.deepPurple2
            m.strokeColor = RSConst.neonPurple.withAlphaComponent(0.3)
            m.lineWidth = 1
            m.position = CGPoint(x: mx, y: skY(RSConst.groundY))
            m.zPosition = -7
            bgNode.addChild(m)
            mountains2.append((node: m, w: mw))
            mx += mw * 0.6
        }

        // Ground fill
        let groundFill = SKSpriteNode(color: RSConst.bgDark, size: CGSize(width: RSConst.gameW, height: 60))
        groundFill.anchorPoint = CGPoint(x: 0, y: 1)
        groundFill.position = CGPoint(x: 0, y: skY(RSConst.groundY))
        groundFill.zPosition = -5
        worldNode.addChild(groundFill)

        // Ceiling fill
        let ceilFill = SKSpriteNode(color: RSConst.bgDark, size: CGSize(width: RSConst.gameW, height: 60))
        ceilFill.anchorPoint = CGPoint(x: 0, y: 0)
        ceilFill.position = CGPoint(x: 0, y: skY(RSConst.ceilY))
        ceilFill.zPosition = -5
        worldNode.addChild(ceilFill)

        // Ground neon line
        let gPath = CGMutablePath()
        gPath.move(to: CGPoint(x: 0, y: skY(RSConst.groundY)))
        gPath.addLine(to: CGPoint(x: RSConst.gameW, y: skY(RSConst.groundY)))
        groundLineNode = SKShapeNode(path: gPath)
        groundLineNode.strokeColor = RSConst.neonGreen
        groundLineNode.lineWidth = 3
        groundLineNode.glowWidth = 8
        groundLineNode.zPosition = -4
        worldNode.addChild(groundLineNode)

        // Ceiling neon line
        let cPath = CGMutablePath()
        cPath.move(to: CGPoint(x: 0, y: skY(RSConst.ceilY)))
        cPath.addLine(to: CGPoint(x: RSConst.gameW, y: skY(RSConst.ceilY)))
        ceilLineNode = SKShapeNode(path: cPath)
        ceilLineNode.strokeColor = RSConst.neonPurple
        ceilLineNode.lineWidth = 3
        ceilLineNode.glowWidth = 8
        ceilLineNode.zPosition = -4
        worldNode.addChild(ceilLineNode)

        // Grid lines on ground
        setupGridLines()
    }

    private func setupGridLines() {
        let gridPath = CGMutablePath()
        let skGround = skY(RSConst.groundY)

        // Vertical perspective lines on ground
        for i in 0..<40 {
            let lx = CGFloat(i) * 60
            gridPath.move(to: CGPoint(x: lx, y: skGround))
            let vanishX = RSConst.gameW * 0.5 + (lx - RSConst.gameW * 0.5) * 0.3
            gridPath.addLine(to: CGPoint(x: vanishX, y: 0))
        }

        // Horizontal grid lines on ground
        let groundHeight = RSConst.gameH - RSConst.groundY
        for i in 1..<12 {
            let fy = CGFloat(i) / 12 * groundHeight
            let webGridY = RSConst.groundY + fy
            gridPath.move(to: CGPoint(x: 0, y: skY(webGridY)))
            gridPath.addLine(to: CGPoint(x: RSConst.gameW, y: skY(webGridY)))
        }

        gridNode = SKNode()
        let gridShape = SKShapeNode(path: gridPath)
        gridShape.strokeColor = RSConst.neonGreen.withAlphaComponent(0.15)
        gridShape.lineWidth = 1
        gridNode.addChild(gridShape)

        // Vertical perspective lines on ceiling
        let ceilPath = CGMutablePath()
        let skCeil = skY(RSConst.ceilY)
        for i in 0..<40 {
            let lx = CGFloat(i) * 60
            ceilPath.move(to: CGPoint(x: lx, y: skCeil))
            let vanishX = RSConst.gameW * 0.5 + (lx - RSConst.gameW * 0.5) * 0.3
            ceilPath.addLine(to: CGPoint(x: vanishX, y: RSConst.gameH))
        }
        let ceilGrid = SKShapeNode(path: ceilPath)
        ceilGrid.strokeColor = RSConst.neonPurple.withAlphaComponent(0.12)
        ceilGrid.lineWidth = 1
        gridNode.addChild(ceilGrid)

        gridNode.zPosition = -6
        worldNode.addChild(gridNode)
    }

    // MARK: - Character

    private func setupCharacter() {
        playerNode.zPosition = 10

        // Jetpack
        let jpBody = SKShapeNode(rect: CGRect(x: -10, y: -16, width: 20, height: 36), cornerRadius: 5)
        jpBody.fillColor = RSConst.color(0x4f46e5)
        jpBody.strokeColor = RSConst.color(0x6366f1)
        jpBody.lineWidth = 1
        jetpackNode.addChild(jpBody)

        // Fuel gauge
        let fuel = SKShapeNode(rect: CGRect(x: -4, y: -4, width: 8, height: 12), cornerRadius: 1)
        fuel.fillColor = RSConst.neonGreen
        fuel.strokeColor = .clear
        jetpackNode.addChild(fuel)

        // Nozzles
        for nx: CGFloat in [-6, 4] {
            let nozzle = SKShapeNode(rect: CGRect(x: nx, y: -26, width: 6, height: 10), cornerRadius: 2)
            nozzle.fillColor = RSConst.color(0x1e1b4b)
            nozzle.strokeColor = .clear
            jetpackNode.addChild(nozzle)
        }

        // Flames (hidden by default)
        leftFlame = makeFlame()
        leftFlame.position = CGPoint(x: -3, y: -32)
        jetpackNode.addChild(leftFlame)
        rightFlame = makeFlame()
        rightFlame.position = CGPoint(x: 7, y: -32)
        jetpackNode.addChild(rightFlame)

        // Flame glow
        flameGlow = SKShapeNode(ellipseOf: CGSize(width: 30, height: 40))
        flameGlow.fillColor = RSConst.neonGreen.withAlphaComponent(0.25)
        flameGlow.strokeColor = .clear
        flameGlow.position = CGPoint(x: 2, y: -35)
        flameGlow.isHidden = true
        jetpackNode.addChild(flameGlow)

        jetpackNode.position = CGPoint(x: -18, y: 0)
        playerNode.addChild(jetpackNode)

        // Body
        let bodyPath = CGMutablePath()
        bodyPath.addRoundedRect(in: CGRect(x: -14, y: -14, width: 30, height: 36), cornerWidth: 6, cornerHeight: 6)
        bodyNode = SKShapeNode(path: bodyPath)
        bodyNode.fillColor = RSConst.color(0x334155)
        bodyNode.strokeColor = RSConst.color(0x475569)
        bodyNode.lineWidth = 1
        playerNode.addChild(bodyNode)

        // LAV emblem (diamond)
        let ePath = CGMutablePath()
        ePath.move(to: CGPoint(x: 0, y: 12))
        ePath.addLine(to: CGPoint(x: -8, y: 2))
        ePath.addLine(to: CGPoint(x: 0, y: -8))
        ePath.addLine(to: CGPoint(x: 8, y: 2))
        ePath.closeSubpath()
        emblemNode = SKShapeNode(path: ePath)
        emblemNode.fillColor = RSConst.neonGreen
        emblemNode.strokeColor = .clear
        emblemNode.glowWidth = 4
        playerNode.addChild(emblemNode)

        // Arms
        backArm = makeLimb(color: RSConst.color(0x1e293b), length: 28)
        backArm.position = CGPoint(x: -11, y: 8)
        backArm.zPosition = -1
        playerNode.addChild(backArm)
        frontArm = makeLimb(color: RSConst.color(0x334155), length: 28)
        frontArm.position = CGPoint(x: 11, y: 8)
        frontArm.zPosition = 1
        playerNode.addChild(frontArm)

        // Gloves
        let backGlove = SKShapeNode(circleOfRadius: 5)
        backGlove.fillColor = RSConst.color(0x16a34a)
        backGlove.strokeColor = .clear
        backGlove.position = CGPoint(x: 0, y: -28)
        backArm.addChild(backGlove)
        let frontGlove = SKShapeNode(circleOfRadius: 5)
        frontGlove.fillColor = RSConst.color(0x22c55e)
        frontGlove.strokeColor = .clear
        frontGlove.position = CGPoint(x: 0, y: -28)
        frontArm.addChild(frontGlove)

        // Legs
        backLeg = makeLimb(color: RSConst.color(0x1e293b), length: 26)
        backLeg.position = CGPoint(x: -3, y: -14)
        backLeg.zPosition = -1
        playerNode.addChild(backLeg)
        frontLeg = makeLimb(color: RSConst.color(0x334155), length: 26)
        frontLeg.position = CGPoint(x: 3, y: -14)
        frontLeg.zPosition = 1
        playerNode.addChild(frontLeg)

        // Shoes
        let backShoe = SKShapeNode(rect: CGRect(x: -3, y: -28, width: 12, height: 6), cornerRadius: 3)
        backShoe.fillColor = RSConst.color(0x16a34a)
        backShoe.strokeColor = .clear
        backLeg.addChild(backShoe)
        let frontShoe = SKShapeNode(rect: CGRect(x: -2, y: -28, width: 12, height: 6), cornerRadius: 3)
        frontShoe.fillColor = RSConst.color(0x22c55e)
        frontShoe.strokeColor = .clear
        frontLeg.addChild(frontShoe)

        // Helmet
        helmetNode = SKShapeNode(circleOfRadius: 16)
        helmetNode.fillColor = RSConst.color(0x64748b)
        helmetNode.strokeColor = RSConst.neonGreen
        helmetNode.lineWidth = 2
        helmetNode.glowWidth = 3
        helmetNode.position = CGPoint(x: 2, y: 30)
        playerNode.addChild(helmetNode)

        // Visor
        visorNode = SKShapeNode(ellipseOf: CGSize(width: 22, height: 18))
        visorNode.fillColor = RSConst.color(0x22c55e)
        visorNode.strokeColor = RSConst.color(0x334155)
        visorNode.lineWidth = 1.5
        visorNode.position = CGPoint(x: 6, y: 30)
        playerNode.addChild(visorNode)

        // Visor shine
        let shine = SKShapeNode(ellipseOf: CGSize(width: 10, height: 5))
        shine.fillColor = UIColor.white.withAlphaComponent(0.5)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 4, y: 34)
        playerNode.addChild(shine)

        // Antenna
        let aPath = CGMutablePath()
        aPath.move(to: CGPoint(x: -6, y: 44))
        aPath.addQuadCurve(to: CGPoint(x: -10, y: 58), control: CGPoint(x: -12, y: 50))
        antennaNode = SKShapeNode(path: aPath)
        antennaNode.strokeColor = RSConst.color(0x64748b)
        antennaNode.lineWidth = 2.5
        playerNode.addChild(antennaNode)

        antennaTip = SKShapeNode(circleOfRadius: 3.5)
        antennaTip.fillColor = RSConst.neonGreen
        antennaTip.strokeColor = .clear
        antennaTip.glowWidth = 4
        antennaTip.position = CGPoint(x: -10, y: 58)
        playerNode.addChild(antennaTip)

        // Ear piece
        let ear = SKShapeNode(circleOfRadius: 4)
        ear.fillColor = RSConst.color(0x475569)
        ear.strokeColor = .clear
        ear.position = CGPoint(x: -12, y: 32)
        playerNode.addChild(ear)
        let earDot = SKShapeNode(circleOfRadius: 2)
        earDot.fillColor = RSConst.neonGreen
        earDot.strokeColor = .clear
        earDot.position = CGPoint(x: -12, y: 32)
        playerNode.addChild(earDot)
    }

    private func makeFlame() -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -3, y: 0))
        path.addCurve(to: CGPoint(x: 0, y: -30), control1: CGPoint(x: -5, y: -10), control2: CGPoint(x: -2, y: -20))
        path.addCurve(to: CGPoint(x: 3, y: 0), control1: CGPoint(x: 2, y: -20), control2: CGPoint(x: 5, y: -10))
        path.closeSubpath()
        let flame = SKShapeNode(path: path)
        flame.fillColor = RSConst.neonGreen.withAlphaComponent(0.8)
        flame.strokeColor = .white
        flame.lineWidth = 1
        flame.glowWidth = 3
        flame.isHidden = true
        return flame
    }

    private func makeLimb(color: UIColor, length: CGFloat) -> SKNode {
        let limb = SKNode()
        let shape = SKShapeNode(rect: CGRect(x: -3.5, y: -length, width: 7, height: length), cornerRadius: 3)
        shape.fillColor = color
        shape.strokeColor = .clear
        limb.addChild(shape)
        return limb
    }

    // MARK: - Coordinate Helpers

    private func skY(_ webY: CGFloat) -> CGFloat { RSConst.gameH - webY }
    private func skPos(_ x: CGFloat, _ webY: CGFloat) -> CGPoint { CGPoint(x: x, y: skY(webY)) }

    // MARK: - Game Control

    func startGame() {
        gameState = .playing
        px = RSConst.playerX
        py = RSConst.playerStartY
        vy = 0
        thrusting = false
        thrustFade = 0
        runPhase = 0
        landImpact = 0

        spd = RSConst.startSpeed
        dist = 0
        pts = 0
        t = 0
        nextObs = RSConst.firstObsDist
        shake = 0
        flash = 0

        // Clear entities
        for obs in obstacles { obs.node.removeFromParent() }
        obstacles.removeAll()
        for ring in rings { ring.node.removeFromParent() }
        rings.removeAll()
        particles.removeAll()
        trail.removeAll()
        trailNode.removeAllChildren()
        fxNode.removeAllChildren()

        rng = RSRNG()

        playerNode.isHidden = false
        lastTime = 0
        accumulator = 0

        onScoreChange?(0)
    }

    func restart() {
        startGame()
    }

    func setThrust(_ val: Bool) {
        thrusting = val
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .waiting || gameState == .gameOver {
            startGame()
            return
        }
        thrusting = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        thrusting = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        thrusting = false
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else {
            lastTime = currentTime
            return
        }

        if lastTime == 0 { lastTime = currentTime }
        var frameTime = currentTime - lastTime
        lastTime = currentTime
        if frameTime > RSConst.maxFrameTime { frameTime = RSConst.maxFrameTime }
        if frameTime <= 0 { return }

        accumulator += frameTime
        var dead = false

        while accumulator >= RSConst.fixedDT && !dead {
            fixedTick(&dead)
            accumulator -= RSConst.fixedDT
        }

        if dead {
            handleGameOver()
            return
        }

        updateVisuals()
    }

    // MARK: - Fixed Tick (120Hz)

    private func fixedTick(_ dead: inout Bool) {
        t += 1

        // Speed ramp
        let elapsed = CGFloat(t) / 120
        spd = RSConst.speedBase + min(elapsed / RSConst.speedRampSec, 1) * RSConst.speedExtra

        // Jetpack physics (web coords: +y = down)
        if thrusting {
            vy += RSConst.thrust
            thrustFade = 1
        } else {
            vy += RSConst.gravity
            thrustFade *= RSConst.thrustFadeDecay
        }

        vy = max(RSConst.vyMin, min(RSConst.vyMax, vy))
        py += vy

        // Bounds
        if py < RSConst.ceilY + 30 {
            py = RSConst.ceilY + 30
            vy = max(0, vy)
        }
        if py > RSConst.groundY - 30 {
            if vy > 4 {
                landImpact = min(vy * 0.06, 0.6)
                burst(at: CGPoint(x: px, y: RSConst.groundY), color: RSConst.neonGreen, count: 6, spread: 4)
            }
            py = RSConst.groundY - 30
            vy = min(0, vy)
        }

        landImpact *= 0.85

        // Running animation
        if py >= RSConst.groundY - 31 {
            runPhase += 0.08 + spd * 0.008
        }

        // Trail
        if t % 2 == 0 {
            trail.append((x: px - 25, y: py + 10, life: 1))
        }
        if trail.count > RSConst.trailMax { trail.removeFirst() }
        for i in 0..<trail.count {
            trail[i].life -= 0.07
        }
        trail.removeAll { $0.life <= 0 }

        dist += spd * 0.1

        // Spawn obstacles
        if dist >= nextObs {
            spawnObstacle()
            nextObs = dist + max(320, 500 - spd * 8)
        }

        // Update obstacles
        for i in (0..<obstacles.count).reversed() {
            obstacles[i].x -= spd

            // Collision
            let opx = px + RSConst.hitOffX
            let opy = py + RSConst.hitOffY
            if opx + RSConst.hitW > obstacles[i].x && opx < obstacles[i].x + obstacles[i].w {
                if opy < obstacles[i].gapY || opy + RSConst.hitH > obstacles[i].gapY + obstacles[i].gapSize {
                    dead = true
                    return
                }
            }

            // Passed
            if !obstacles[i].passed && obstacles[i].x + obstacles[i].w < px {
                obstacles[i].passed = true
                pts += CGFloat(RSConst.pipeScore)
                flash = 0.15
            }

            // Remove off-screen
            if obstacles[i].x < -100 {
                obstacles[i].node.removeFromParent()
                obstacles.remove(at: i)
            }
        }

        // Update rings
        for i in (0..<rings.count).reversed() {
            rings[i].x -= spd
            rings[i].pulse += 0.1

            if !rings[i].collected {
                let dx = px - rings[i].x
                let dy = py - rings[i].y
                let d = sqrt(dx * dx + dy * dy)
                if d < RSConst.ringCollectDist {
                    rings[i].collected = true
                    pts += CGFloat(RSConst.ringScore)

                    // Boost associated pipe
                    if let idx = obstacles.firstIndex(where: { $0.id == rings[i].forPipeId }) {
                        obstacles[idx].gapSize += RSConst.ringBoostAmount
                        obstacles[idx].ringsCollected += 1
                    }

                    sparkle(at: CGPoint(x: rings[i].x, y: rings[i].y), color: RSConst.neonGreen)
                    burst(at: CGPoint(x: rings[i].x, y: rings[i].y), color: RSConst.color(0x22c55e), count: 20, spread: 10)

                    particles.append(RSParticle(x: rings[i].x, y: rings[i].y, vx: 0, vy: -3,
                                                r: 0, life: 1.5, color: RSConst.neonGreen,
                                                type: "text", text: "+PIPE OPEN"))

                    flash = 0.25
                    shake = 3

                    rings[i].node.removeFromParent()
                    rings.remove(at: i)
                    continue
                }
            }

            if rings[i].x < -50 {
                rings[i].node.removeFromParent()
                rings.remove(at: i)
            }
        }

        // Update particles
        for i in (0..<particles.count).reversed() {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            if particles[i].type == "text" {
                particles[i].life -= 0.02
            } else {
                particles[i].vy += 0.12
                particles[i].life -= 0.025
            }
            if particles[i].life <= 0 { particles.remove(at: i) }
        }

        // Continuous scoring
        pts += spd * 0.005
        shake *= 0.85
        flash *= 0.88

        // Background parallax
        for i in 0..<stars.count {
            stars[i].twinkle += 0.04
        }
        for i in 0..<mountains1.count {
            mountains1[i].node.position.x -= spd * 0.1
            if mountains1[i].node.position.x + mountains1[i].w < 0 {
                mountains1[i].node.position.x = RSConst.gameW + CGFloat.random(in: 0...200)
            }
        }
        for i in 0..<mountains2.count {
            mountains2[i].node.position.x -= spd * 0.25
            if mountains2[i].node.position.x + mountains2[i].w < 0 {
                mountains2[i].node.position.x = RSConst.gameW + CGFloat.random(in: 0...150)
            }
        }
    }

    // MARK: - Spawn

    private func spawnObstacle() {
        let baseGap = max(160, 240 - spd * 5)
        let gapY = RSConst.ceilY + 100 + rng.nextFloat(0, RSConst.groundY - RSConst.ceilY - baseGap - 200)
        let pipeId = t + Int(rng.nextFloat(0, 1000))
        let obsWidth = rng.nextFloat(50, 80)
        let isPipe = rng.next() < 0.7

        let obs = createObstacleNode(x: RSConst.gameW + 60, gapY: gapY, gapSize: baseGap,
                                      w: obsWidth, type: isPipe ? "pipe" : "laser", id: pipeId)
        obstacles.append(obs)

        // Spawn 2 rings for this obstacle
        let ringY1 = RSConst.ceilY + 120 + rng.nextFloat(0, RSConst.groundY - RSConst.ceilY - 240)
        let ringY2 = RSConst.ceilY + 120 + rng.nextFloat(0, RSConst.groundY - RSConst.ceilY - 240)

        let r1x = RSConst.gameW + 60 - 900 - rng.nextFloat(0, 100)
        let r2x = RSConst.gameW + 60 - 600 - rng.nextFloat(0, 100)

        spawnRing(x: r1x, y: ringY1, forPipeId: pipeId)
        spawnRing(x: r2x, y: ringY2, forPipeId: pipeId)
    }

    private func createObstacleNode(x: CGFloat, gapY: CGFloat, gapSize: CGFloat,
                                     w: CGFloat, type: String, id: Int) -> RSObstacle {
        let node = SKNode()
        node.zPosition = 5

        let isPipe = type == "pipe"
        let barColor = isPipe ? RSConst.pipeDkGray : RSConst.laserRed.withAlphaComponent(0.7)
        let capColor = isPipe ? RSConst.capGray : RSConst.color(0x1f2937)
        let stripeColor = isPipe ? RSConst.color(0xf59e0b) : RSConst.laserRed

        // Top barrier
        let topH = gapY - RSConst.ceilY
        let topBar = SKSpriteNode(color: barColor, size: CGSize(width: w, height: topH))
        topBar.anchorPoint = CGPoint(x: 0, y: 0)
        topBar.position = CGPoint(x: 0, y: skY(RSConst.ceilY) - topH)
        node.addChild(topBar)

        // Top cap
        let topCap = SKSpriteNode(color: capColor, size: CGSize(width: w + 10, height: 20))
        topCap.anchorPoint = CGPoint(x: 0.5, y: 1)
        topCap.position = CGPoint(x: w / 2, y: skY(gapY) + 20)
        node.addChild(topCap)

        // Top cap stripe
        let topCapStripe = SKSpriteNode(color: stripeColor, size: CGSize(width: w + 10, height: 4))
        topCapStripe.anchorPoint = CGPoint(x: 0.5, y: 1)
        topCapStripe.position = CGPoint(x: w / 2, y: skY(gapY) + 20)
        node.addChild(topCapStripe)

        // Bottom barrier
        let botH = RSConst.groundY - gapY - gapSize
        let botBar = SKSpriteNode(color: barColor, size: CGSize(width: w, height: max(0, botH)))
        botBar.anchorPoint = CGPoint(x: 0, y: 1)
        botBar.position = CGPoint(x: 0, y: skY(RSConst.groundY) + botH)
        node.addChild(botBar)

        // Bottom cap
        let botCap = SKSpriteNode(color: capColor, size: CGSize(width: w + 10, height: 20))
        botCap.anchorPoint = CGPoint(x: 0.5, y: 0)
        botCap.position = CGPoint(x: w / 2, y: skY(gapY + gapSize) - 20)
        node.addChild(botCap)

        // Bottom cap stripe
        let botCapStripe = SKSpriteNode(color: stripeColor, size: CGSize(width: w + 10, height: 4))
        botCapStripe.anchorPoint = CGPoint(x: 0.5, y: 0)
        botCapStripe.position = CGPoint(x: w / 2, y: skY(gapY + gapSize) - 20)
        node.addChild(botCapStripe)

        // Laser core (white line in center)
        if !isPipe {
            let coreTop = SKSpriteNode(color: .white, size: CGSize(width: 4, height: topH))
            coreTop.anchorPoint = CGPoint(x: 0.5, y: 0)
            coreTop.position = CGPoint(x: w / 2, y: skY(gapY))
            coreTop.alpha = 0.8
            node.addChild(coreTop)

            let coreBot = SKSpriteNode(color: .white, size: CGSize(width: 4, height: max(0, botH)))
            coreBot.anchorPoint = CGPoint(x: 0.5, y: 1)
            coreBot.position = CGPoint(x: w / 2, y: skY(gapY + gapSize))
            coreBot.alpha = 0.8
            node.addChild(coreBot)
        }

        node.position = CGPoint(x: x, y: 0)
        obstaclesNode.addChild(node)

        return RSObstacle(node: node, topBar: topBar, botBar: botBar, topCap: topCap, botCap: botCap,
                          topCapStripe: topCapStripe, botCapStripe: botCapStripe,
                          x: x, gapY: gapY, gapSize: gapSize, baseGap: gapSize,
                          w: w, type: type, id: id)
    }

    private func spawnRing(x: CGFloat, y: CGFloat, forPipeId: Int) {
        let node = SKNode()
        node.zPosition = 6

        // Outer ring
        let outer = SKShapeNode(circleOfRadius: RSConst.ringRadius)
        outer.strokeColor = RSConst.neonGreen
        outer.fillColor = .clear
        outer.lineWidth = 6
        outer.glowWidth = 8
        node.addChild(outer)

        // Inner ring
        let inner = SKShapeNode(circleOfRadius: RSConst.ringRadius - 8)
        inner.strokeColor = RSConst.neonGreenLt
        inner.fillColor = .clear
        inner.lineWidth = 3
        node.addChild(inner)

        node.position = skPos(x, y)
        ringsNode.addChild(node)

        rings.append(RSRing(node: node, x: x, y: y, pulse: rng.nextFloat(0, .pi * 2), forPipeId: forPipeId))
    }

    // MARK: - Visual Updates (per frame)

    private func updateVisuals() {
        // Player position
        playerNode.position = skPos(px, py)

        // Tilt based on velocity (web y-down: negative vy = going up)
        let tilt = max(-0.3, min(0.3, vy * 0.025))
        playerNode.zRotation = -tilt

        // Squash/stretch
        let sx = 1 - abs(vy) * 0.012
        let sy = 1 + abs(vy) * 0.015
        playerNode.xScale = sx * (1 + landImpact * 0.2)
        playerNode.yScale = sy * (1 - landImpact * 0.12)

        // Flames
        let showFlame = thrusting || thrustFade > 0.1
        leftFlame.isHidden = !showFlame
        rightFlame.isHidden = !showFlame
        flameGlow.isHidden = !showFlame
        if showFlame {
            let intensity = thrusting ? 1.0 : thrustFade
            let flameScale = 0.6 + intensity * 0.8 + CGFloat.random(in: 0...0.3)
            leftFlame.yScale = flameScale
            rightFlame.yScale = flameScale
            leftFlame.alpha = intensity
            rightFlame.alpha = intensity
            flameGlow.alpha = intensity * 0.3
        }

        // Legs animation
        let onGround = py >= RSConst.groundY - 31
        if onGround {
            let a1 = sin(runPhase) * 0.45
            let a2 = sin(runPhase + .pi) * 0.45
            backLeg.zRotation = a1
            frontLeg.zRotation = a2
        } else {
            let dangle = sin(CGFloat(t) * 0.04) * 0.06
            backLeg.zRotation = -(0.4 + dangle)
            frontLeg.zRotation = -(0.2 - dangle)
        }

        // Arms animation
        let armBob = onGround ? sin(runPhase) * 0.3 : sin(CGFloat(t) * 0.04) * 0.08
        backArm.zRotation = 0.6 + armBob
        frontArm.zRotation = 0.4 - armBob

        // Trail
        trailNode.removeAllChildren()
        for tr in trail where tr.life > 0 {
            let dot = SKShapeNode(circleOfRadius: 8 * tr.life)
            dot.fillColor = RSConst.neonGreen.withAlphaComponent(0.3 * tr.life)
            dot.strokeColor = .clear
            dot.position = skPos(tr.x, tr.y)
            trailNode.addChild(dot)
        }

        // Obstacle positions & ring boost visuals
        for i in 0..<obstacles.count {
            obstacles[i].node.position.x = obstacles[i].x

            // Update barrier sizes if ring-boosted
            if obstacles[i].ringsCollected > 0 {
                let gapY = obstacles[i].gapY
                let gapSize = obstacles[i].gapSize
                let w = obstacles[i].w

                let topH = gapY - RSConst.ceilY
                obstacles[i].topBar.size.height = topH
                obstacles[i].topBar.position.y = skY(RSConst.ceilY) - topH

                let botH = RSConst.groundY - gapY - gapSize
                obstacles[i].botBar.size.height = max(0, botH)
                obstacles[i].botBar.position.y = skY(RSConst.groundY) + max(0, botH)

                obstacles[i].topCap.position.y = skY(gapY) + 20
                obstacles[i].topCapStripe.position.y = skY(gapY) + 20
                obstacles[i].botCap.position.y = skY(gapY + gapSize) - 20
                obstacles[i].botCapStripe.position.y = skY(gapY + gapSize) - 20

                // Green tint for boosted
                obstacles[i].topBar.color = RSConst.pipeGreen
                obstacles[i].botBar.color = RSConst.pipeGreen
                obstacles[i].topCap.color = RSConst.capGreen
                obstacles[i].botCap.color = RSConst.capGreen
                obstacles[i].topCapStripe.color = RSConst.neonGreen
                obstacles[i].botCapStripe.color = RSConst.neonGreen
            }
        }

        // Ring positions & pulse
        for i in 0..<rings.count {
            let pulse = 1 + sin(rings[i].pulse) * 0.12
            rings[i].node.position = skPos(rings[i].x, rings[i].y)
            rings[i].node.setScale(pulse)
        }

        // Particle FX
        fxNode.removeAllChildren()
        for p in particles {
            if p.type == "text", let text = p.text {
                let label = SKLabelNode(text: text)
                label.fontName = "AvenirNext-Bold"
                label.fontSize = 16
                label.fontColor = p.color
                label.alpha = min(1, p.life)
                label.position = skPos(p.x, p.y)
                fxNode.addChild(label)
            } else {
                let dot = SKShapeNode(circleOfRadius: p.r * p.life)
                dot.fillColor = p.color
                dot.strokeColor = .clear
                dot.alpha = min(1, p.life)
                dot.position = skPos(p.x, p.y)
                fxNode.addChild(dot)
            }
        }

        // Star twinkle
        for i in 0..<stars.count {
            let tw = (sin(stars[i].twinkle) + 1) * 0.5
            stars[i].node.alpha = stars[i].baseAlpha * (0.4 + tw * 0.6)
        }

        // Screen shake
        if shake > 0.5 {
            worldNode.position = CGPoint(x: CGFloat.random(in: -shake...shake),
                                         y: CGFloat.random(in: -shake...shake))
        } else {
            worldNode.position = .zero
        }

        // Screen flash
        flashNode.alpha = flash * 0.25

        // Score
        let score = Int(pts + dist * 1.5)
        onScoreChange?(score)
    }

    // MARK: - Game Over

    private func handleGameOver() {
        gameState = .gameOver
        burst(at: CGPoint(x: px, y: py), color: RSConst.laserRed, count: 50, spread: 15)
        shake = 30

        finalScore = Int(pts + dist * 1.5)
        onScoreChange?(finalScore)

        if finalScore > highScore {
            highScore = finalScore
            UserDefaults.standard.set(highScore, forKey: "rocketsol_best")
        }
    }

    var currentHighScore: Int { highScore }

    // MARK: - Effects

    private func burst(at pos: CGPoint, color: UIColor, count: Int, spread: CGFloat) {
        for _ in 0..<count {
            let a = CGFloat.random(in: 0...(.pi * 2))
            let v = 2 + CGFloat.random(in: 0...spread)
            particles.append(RSParticle(
                x: pos.x, y: pos.y,
                vx: cos(a) * v, vy: sin(a) * v,
                r: 2 + CGFloat.random(in: 0...5),
                life: 1, color: color, type: "circle", text: nil
            ))
        }
    }

    private func sparkle(at pos: CGPoint, color: UIColor) {
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * .pi * 2
            particles.append(RSParticle(
                x: pos.x, y: pos.y,
                vx: cos(a) * 5, vy: sin(a) * 5,
                r: 4, life: 1, color: color, type: "star", text: nil
            ))
        }
    }
}
