import SceneKit
import UIKit

final class WarpScene: NSObject, SCNSceneRendererDelegate {

    let scene = SCNScene()
    let cameraNode = SCNNode()

    // Nodes
    private(set) var shipNode: SCNNode!
    private var tunnelRings: [SCNNode] = []
    private var wallLightNode: SCNNode!

    // Game state
    enum GameState { case waiting, playing, gameOver }

    var gameState: GameState = .waiting {
        didSet { onStateChange?(gameState) }
    }

    var score: Int = 0 { didSet { onScoreChange?(score) } }
    var combo: Int = 0 { didSet { onComboChange?(combo) } }
    var maxCombo: Int = 0
    var wallsPassed: Int = 0
    var speedPercent: Float = 0 { didSet { onSpeedChange?(speedPercent) } }
    var highScore: Int = 0

    // Continuous XY position & velocity
    private var px: Float = 0
    private var py: Float = 0
    private var vx: Float = 0
    private var vy: Float = 0

    // Touch input
    private var touchActive = false
    private var targetX: Float = 0
    private var targetY: Float = 0

    // Walls
    private var walls: [WallData] = []
    private var wallIdx: Int = 0
    private var nextZ: Float = -15
    private var prevGapX: Float = 0
    private var prevGapY: Float = 0

    // Fixed-point scoring
    private var speedFp: Int = WConst.v0Fp
    private var distanceFp: Int = 0
    private var accumulator: Float = 0
    private var frameCount: Int = 0
    private var currentSpeed: Float = WConst.v0

    // Visual state
    private var bankZ: Float = 0
    private var bankX: Float = 0
    private var gameTime: Float = 0

    // Callbacks
    var onStateChange: ((GameState) -> Void)?
    var onScoreChange: ((Int) -> Void)?
    var onComboChange: ((Int) -> Void)?
    var onSpeedChange: ((Float) -> Void)?
    var onWallPass: (() -> Void)?

    // MARK: - Setup

    func setupScene() {
        setupBackground()
        setupLighting()
        setupFog()
        setupCamera()
        setupShip()
        setupTunnelRings()
        setupWallLight()

        highScore = UserDefaults.standard.integer(forKey: "warp_highscore")
    }

    private func setupBackground() {
        // Dark purple space background (0x0e0520)
        scene.background.contents = WConst.color(0x0e0520)
    }

    private func setupLighting() {
        // Purple ambient — matches web: AmbientLight(0x442266, 1.8)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = WConst.color(0x442266)
        ambient.light?.intensity = 1800
        scene.rootNode.addChildNode(ambient)

        // Main directional — matches web: DirectionalLight(0xffeeff, 1.8)
        let dir = SCNNode()
        dir.light = SCNLight()
        dir.light?.type = .directional
        dir.light?.color = WConst.color(0xffeeff)
        dir.light?.intensity = 1800
        dir.position = SCNVector3(3, 5, 8)
        dir.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(dir)

        // Purple fill — matches web: DirectionalLight(0x9966ff, 0.6)
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.color = WConst.color(0x9966ff)
        fill.light?.intensity = 600
        fill.position = SCNVector3(-3, -2, 4)
        fill.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fill)
    }

    private func setupFog() {
        // Approximate FogExp2(0x0e0520, 0.005) with linear fog
        scene.fogStartDistance = 30
        scene.fogEndDistance = 180
        scene.fogColor = WConst.color(0x0e0520)
        scene.fogDensityExponent = 2
    }

    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = WConst.baseFOV
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 300
        cameraNode.position = SCNVector3(0, WConst.cameraY, WConst.cameraZ)
        cameraNode.look(at: SCNVector3(0, 0, -50))
        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupShip() {
        shipNode = WarpShip.createShip()
        shipNode.position = SCNVector3(0, 0, WConst.playerZ)
        scene.rootNode.addChildNode(shipNode)
    }

    private func setupTunnelRings() {
        for i in 0..<WConst.ringCount {
            let ring = WarpTunnel.createTunnelRing(index: i)
            scene.rootNode.addChildNode(ring)
            tunnelRings.append(ring)
        }
    }

    private func setupWallLight() {
        wallLightNode = SCNNode()
        wallLightNode.light = SCNLight()
        wallLightNode.light?.type = .omni
        wallLightNode.light?.color = UIColor.white
        wallLightNode.light?.intensity = 0
        wallLightNode.light?.attenuationEndDistance = 16
        wallLightNode.position = SCNVector3(0, 0, WConst.playerZ - 2)
        scene.rootNode.addChildNode(wallLightNode)
    }

    // MARK: - Game Control

    func startGame() {
        gameState = .playing
        score = 0
        combo = 0
        maxCombo = 0
        wallsPassed = 0
        speedPercent = 0
        px = 0; py = 0; vx = 0; vy = 0
        touchActive = false; targetX = 0; targetY = 0
        wallIdx = 0; nextZ = -15; prevGapX = 0; prevGapY = 0
        speedFp = WConst.v0Fp; distanceFp = 0
        accumulator = 0; frameCount = 0
        currentSpeed = WConst.v0
        bankZ = 0; bankX = 0; gameTime = 0

        shipNode.position = SCNVector3(0, 0, WConst.playerZ)
        shipNode.isHidden = false
        shipNode.rotation = SCNVector4(0, 0, 0, 0)

        // Remove existing walls
        for w in walls {
            w.group.removeFromParentNode()
        }
        walls.removeAll()

        // Fill initial walls
        fillWalls()

        cameraNode.camera?.fieldOfView = WConst.baseFOV
    }

    func restart() {
        startGame()
    }

    // MARK: - Touch Input API

    func handleTouchBegan(normalizedX: Float, normalizedY: Float) {
        if gameState == .waiting || gameState == .gameOver {
            startGame()
            return
        }
        guard gameState == .playing else { return }
        touchActive = true
        let bw = WConst.arenaW / 2 - WConst.playerR - 0.1
        let bh = WConst.arenaH / 2 - WConst.playerR - 0.1
        targetX = normalizedX * bw
        targetY = (normalizedY + 0.15) * bh
    }

    func handleTouchMoved(normalizedX: Float, normalizedY: Float) {
        guard gameState == .playing, touchActive else { return }
        let bw = WConst.arenaW / 2 - WConst.playerR - 0.1
        let bh = WConst.arenaH / 2 - WConst.playerR - 0.1
        targetX = normalizedX * bw
        targetY = (normalizedY + 0.15) * bh
    }

    func handleTouchEnded() {
        touchActive = false
        targetX = px
        targetY = py
    }

    // MARK: - Game Loop

    private var lastTime: TimeInterval = 0

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard gameState == .playing else {
            lastTime = time
            return
        }

        var frameTime = Float(time - lastTime)
        lastTime = time
        if frameTime > WConst.maxFrameTime { frameTime = WConst.maxFrameTime }
        if frameTime <= 0 { return }

        gameTime += frameTime

        // Fixed timestep accumulator (120Hz)
        accumulator += frameTime
        if accumulator > WConst.fixedDT * 10 { accumulator = WConst.fixedDT * 10 }

        var ticksThisFrame = 0
        var wallPassed = false

        while accumulator >= WConst.fixedDT {
            fixedTick(&wallPassed)
            accumulator -= WConst.fixedDT
            ticksThisFrame += 1
        }

        // Per-frame visual updates
        updateVisuals(frameTime: frameTime, ticksThisFrame: ticksThisFrame)

        if wallPassed {
            onWallPass?()
        }
    }

    // MARK: - Fixed Tick (120Hz Deterministic)

    private func fixedTick(_ wallPassed: inout Bool) {
        // Touch-lerp movement
        if touchActive {
            let dx = targetX - px
            let dy = targetY - py
            vx = dx * WConst.touchLerp
            vy = dy * WConst.touchLerp
            vx = max(-WConst.touchClamp, min(WConst.touchClamp, vx))
            vy = max(-WConst.touchClamp, min(WConst.touchClamp, vy))
            px += vx * WConst.fixedDT
            py += vy * WConst.fixedDT
        } else {
            vx *= 0.87
            vy *= 0.87
            px += vx * WConst.fixedDT
            py += vy * WConst.fixedDT
        }

        // Arena bounds bounce
        let bw = WConst.arenaW / 2 - WConst.playerR - 0.05
        let bh = WConst.arenaH / 2 - WConst.playerR - 0.05
        if px < -bw { px = -bw; vx *= -0.3 }
        if px > bw { px = bw; vx *= -0.3 }
        if py < -bh { py = -bh; vy *= -0.3 }
        if py > bh { py = bh; vy *= -0.3 }

        // Speed from difficulty (FP deterministic)
        speedFp = WConst.getSpeedFp(wallIdx: wallsPassed + WConst.nWalls)
        currentSpeed = Float(speedFp) / Float(WConst.fpScale)

        // Move walls by FP moveZ
        let moveZFp = speedFp / WConst.ticksPerSec
        let moveZ = Float(moveZFp) / Float(WConst.fpScale)

        for i in 0..<walls.count {
            walls[i].group.position.z += moveZ

            let wz = walls[i].group.position.z

            // Collision (circle vs rect closest-point)
            if wz > WConst.playerZ - 0.6 && wz < WConst.playerZ + 0.6 {
                if checkCollision(px: px, py: py, wallGroup: walls[i].group) {
                    handleGameOver()
                    return
                }
            }

            // Wall pass scoring
            if !walls[i].passed && wz > WConst.playerZ + 1 {
                walls[i].passed = true
                combo += 1
                wallsPassed += 1
                score += 10 + combo * 2
                if combo > maxCombo { maxCombo = combo }
                wallPassed = true
            }
        }

        // Distance tracking (FP)
        distanceFp += moveZFp

        // Prune walls that passed camera
        pruneWalls()
        fillWalls()

        // Speed percent for UI
        let sn = (currentSpeed - WConst.v0) / (WConst.vMax - WConst.v0)
        speedPercent = min(1, max(0, sn))

        frameCount += 1
    }

    // MARK: - Collision

    private func checkCollision(px: Float, py: Float, wallGroup: SCNNode) -> Bool {
        for child in wallGroup.childNodes {
            guard let geo = child.geometry as? SCNBox else { continue }
            // Skip outline meshes (cullMode .front)
            if child.geometry?.firstMaterial?.cullMode == .front { continue }

            let wp = child.position
            let hw = Float(geo.width) / 2
            let hh = Float(geo.height) / 2

            // Circle vs AABB closest point
            let cx = px - wp.x
            let cy = py - wp.y
            let nx = max(-hw, min(hw, cx))
            let ny = max(-hh, min(hh, cy))
            let dx = cx - nx
            let dy = cy - ny
            let dist = sqrt(dx * dx + dy * dy)

            if dist < WConst.hitR {
                return true
            }
        }
        return false
    }

    // MARK: - Wall Management

    private func fillWalls() {
        while walls.count < WConst.nWalls {
            let diff = WConst.getDifficulty(wallIdx: wallIdx)
            let spacing = WConst.getSpacing(difficulty: diff)
            let palette = WConst.palettes[wallIdx % WConst.palettes.count]

            let wall = WarpTunnel.generateWall(
                idx: wallIdx, z: nextZ,
                prevGapX: prevGapX, prevGapY: prevGapY,
                difficulty: diff, palette: palette
            )

            scene.rootNode.addChildNode(wall.group)
            walls.append(wall)
            prevGapX = wall.gapX
            prevGapY = wall.gapY
            nextZ = nextZ - spacing
            wallIdx += 1
        }
    }

    private func pruneWalls() {
        while walls.count > 3 && walls[0].group.position.z > 12 {
            walls[0].group.removeFromParentNode()
            walls.removeFirst()
        }
    }

    // MARK: - Visual Updates (per-frame)

    private func updateVisuals(frameTime: Float, ticksThisFrame: Int) {
        let sn = speedPercent

        // Ship position
        shipNode.position = SCNVector3(px, py, WConst.playerZ)

        // Ship banking (frame-rate independent exponential damping)
        let targetBankZ = -vx * 0.07
        let targetBankX = vy * 0.04
        let bankDamp = 1 - pow(0.00005, frameTime)
        bankZ += (targetBankZ - bankZ) * bankDamp
        bankX += (targetBankX - bankX) * bankDamp
        shipNode.eulerAngles.z = bankZ
        shipNode.eulerAngles.x = bankX

        // Engine glow pulse
        if let engine = shipNode.childNode(withName: "engineGlow", recursively: false) {
            let pulse = 0.8 + sin(gameTime * 12) * 0.2 + sn * 0.3
            engine.scale = SCNVector3(pulse, pulse, pulse)
        }

        // Tunnel ring scroll
        let ringDist = currentSpeed * Float(ticksThisFrame) * WConst.fixedDT
        for ring in tunnelRings {
            ring.position.z += ringDist
            if ring.position.z > 9 {
                ring.position.z -= Float(WConst.ringCount) * WConst.ringSpacing
            }
        }

        // Wall emissive glow + proximity light
        var nearestDist: Float = .infinity
        var nearestWall: WallData?
        for w in walls {
            let wdist = abs(w.group.position.z - WConst.playerZ)
            if wdist < 14 {
                let glow = max(0, 1 - wdist / 14) * 0.6 + 0.15
                w.toonMat.emission.contents = WConst.color(w.palette.base)
                w.toonMat.emission.intensity = CGFloat(glow)
                if wdist < nearestDist {
                    nearestDist = wdist
                    nearestWall = w
                }
            } else {
                w.toonMat.emission.intensity = 0
            }
        }

        if let nearest = nearestWall, nearestDist < 12 {
            wallLightNode.light?.color = WConst.color(nearest.palette.base)
            wallLightNode.light?.intensity = CGFloat((1 - nearestDist / 12) * 4.0) * 1000
            wallLightNode.position = SCNVector3(px, py, WConst.playerZ - 2)
        } else {
            wallLightNode.light?.intensity = 0
        }

        // Camera FOV + follow
        let targetFov = WConst.baseFOV + CGFloat(sn) * WConst.maxExtraFOV
        if let cam = cameraNode.camera, abs(targetFov - cam.fieldOfView) > 0.05 {
            cam.fieldOfView = targetFov
        }
        cameraNode.position.x = px * 0.2
        cameraNode.position.y = 0.4 + py * 0.13
        cameraNode.position.z = WConst.cameraZ
        cameraNode.look(at: SCNVector3(px * 0.07, py * 0.05, -50))
    }

    // MARK: - Game Over

    private func handleGameOver() {
        gameState = .gameOver
        combo = 0

        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "warp_highscore")
        }
    }
}
