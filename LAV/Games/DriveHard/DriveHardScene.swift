import SceneKit
import UIKit

final class DriveHardScene: NSObject, SCNSceneRendererDelegate {

    let scene = SCNScene()
    let cameraNode = SCNNode()

    // Node pools
    private(set) var playerNode: SCNNode!
    private var roadSegments: [SCNNode] = []
    private var obstaclePool: [SCNNode] = []
    private var coinPool: [SCNNode] = []
    private var buildingsLeft: [SCNNode] = []
    private var buildingsRight: [SCNNode] = []
    private var lampsLeft: [SCNNode] = []
    private var lampsRight: [SCNNode] = []

    // Game state
    var gameState: GameState = .waiting {
        didSet { onStateChange?(gameState) }
    }
    var score: Int = 0 { didSet { onScoreChange?(score) } }
    var coinsCollected: Int = 0 { didSet { onCoinsChange?(coinsCollected) } }
    var speed: Float = DHConst.baseSpeed
    var speedPercent: Float = 0 { didSet { onSpeedChange?(speedPercent) } }
    var highScore: Int = 0

    // Lane state
    private var currentLane = 1
    private var playerX: Float = DHConst.laneCenter
    private var targetLaneX: Float = DHConst.laneCenter
    private var laneSwitchProgress: Float = 1
    private var laneSwitchStartX: Float = 0
    private var inputQueue: [Int] = [] // -1 left, +1 right

    // Spawn timers
    private var spawnTimer: Float = 1.2
    private var coinSpawnTimer: Float = 0.8
    private var distanceTraveled: Float = 0
    private var nearMissTimer: Float = 0

    // Death camera animation state
    private var deathAnimTime: Float = 0
    private var deathStartCamPos = SCNVector3Zero
    private var deathStartFOV: CGFloat = 72
    private var deathPlayerX: Float = 0
    private var trailNode: SCNNode?

    // Fixed-point scoring state (matches web deterministic math)
    private var accumulator: Float = 0
    private(set) var frameCount: Int = 0
    private var speedFp: Int = DHConst.baseSpeedFP
    private(set) var distanceFp: Int = 0
    private(set) var nearMissBonus: Int = 0

    // Input recording for score verification
    var inputRecording: [[String: Any]] = []

    // Callbacks
    var onStateChange: ((GameState) -> Void)?
    var onScoreChange: ((Int) -> Void)?
    var onCoinsChange: ((Int) -> Void)?
    var onSpeedChange: ((Float) -> Void)?
    var onNearMiss: (() -> Void)?
    var onCoinCollect: (() -> Void)?

    enum GameState {
        case waiting, playing, gameOver
    }

    // MARK: - Setup

    func setupScene() {
        setupSky()
        setupLighting()
        setupFog()
        setupCamera()
        setupGround()
        setupRoad()
        setupPlayer()
        setupObstaclePool()
        setupCoinPool()
        setupScenery()

        highScore = UserDefaults.standard.integer(forKey: "drivehard_highscore")
    }

    private func setupSky() {
        // Dubai clear sky gradient matching web: blue top → golden horizon
        let size = CGSize(width: 2, height: 512)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let colors: [(CGFloat, UIColor)] = [
            (0.0,  UIColor(red: 0x1a/255, green: 0x40/255, blue: 0x70/255, alpha: 1)),  // #1a4070 deep sky blue
            (0.15, UIColor(red: 0x3a/255, green: 0x70/255, blue: 0xa0/255, alpha: 1)),  // #3a70a0 medium blue
            (0.3,  UIColor(red: 0x5a/255, green: 0x90/255, blue: 0xb8/255, alpha: 1)),  // #5a90b8 sky blue
            (0.45, UIColor(red: 0x87/255, green: 0xce/255, blue: 0xeb/255, alpha: 1)),  // #87ceeb light sky blue
            (0.6,  UIColor(red: 0xa8/255, green: 0xd8/255, blue: 0xe8/255, alpha: 1)),  // #a8d8e8 pale blue
            (0.72, UIColor(red: 0xc8/255, green: 0xd8/255, blue: 0xd0/255, alpha: 1)),  // #c8d8d0 haze transition
            (0.85, UIColor(red: 0xe0/255, green: 0xc8/255, blue: 0x90/255, alpha: 1)),  // #e0c890 warm golden
            (1.0,  UIColor(red: 0xf0/255, green: 0xd8/255, blue: 0x80/255, alpha: 1)),  // #f0d880 golden horizon
        ]

        let cgColors = colors.map { $0.1.cgColor }
        let locations = colors.map { CGFloat($0.0) }
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: cgColors as CFArray,
                                   locations: locations)!
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: 0),
                               end: CGPoint(x: 0, y: 512),
                               options: [])

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        scene.background.contents = image
    }

    private func setupLighting() {
        // Ambient light — matches web: AmbientLight(0xffffff, 0.9)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor.white
        ambient.light?.intensity = 900
        scene.rootNode.addChildNode(ambient)

        // Directional (sun) — matches web: DirectionalLight(0xfff5e8, 1.6)
        let dir = SCNNode()
        dir.light = SCNLight()
        dir.light?.type = .directional
        dir.light?.color = UIColor(red: 1.0, green: 0.96, blue: 0.91, alpha: 1) // 0xfff5e8
        dir.light?.intensity = 1600
        dir.light?.castsShadow = true
        dir.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
        dir.light?.shadowMode = .deferred
        dir.light?.shadowRadius = 3
        dir.light?.shadowCascadeCount = 2
        dir.light?.maximumShadowDistance = 60
        dir.position = SCNVector3(5, 18, 10)
        dir.eulerAngles = SCNVector3(-0.8, 0.3, 0)
        scene.rootNode.addChildNode(dir)

        // Hemisphere-like fill light — web: HemisphereLight(0xaaddff, 0x66bb66, 0.6)
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.color = UIColor(red: 0x66/255, green: 0xbb/255, blue: 0x66/255, alpha: 1)
        fill.light?.intensity = 300
        fill.position = SCNVector3(0, -5, 0)
        fill.eulerAngles = SCNVector3(0.8, 0, 0)
        scene.rootNode.addChildNode(fill)

        // Sky fill from above-front
        let skyFill = SCNNode()
        skyFill.light = SCNLight()
        skyFill.light?.type = .directional
        skyFill.light?.color = UIColor(red: 0xaa/255, green: 0xdd/255, blue: 0xff/255, alpha: 1)
        skyFill.light?.intensity = 300
        skyFill.position = SCNVector3(0, 10, -5)
        skyFill.eulerAngles = SCNVector3(-0.5, 0, 0)
        scene.rootNode.addChildNode(skyFill)
    }

    private func setupFog() {
        // Matches web: scene.fog = new THREE.Fog(0xddeeff, 55, 130)
        scene.fogStartDistance = 55
        scene.fogEndDistance = 130
        scene.fogColor = UIColor(red: 0xdd/255.0, green: 0xee/255.0, blue: 0xff/255.0, alpha: 1) // #ddeeff
        scene.fogDensityExponent = 1.5
    }

    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = DHConst.baseFOV
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 250
        cameraNode.position = SCNVector3(0, DHConst.cameraY, DHConst.cameraZ)
        cameraNode.look(at: SCNVector3(0, 0.3, -20))
        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupGround() {
        scene.rootNode.addChildNode(DriveHardRoad.createGround())
        for sw in DriveHardRoad.createSidewalks() {
            scene.rootNode.addChildNode(sw)
        }
    }

    private func setupRoad() {
        for i in 0..<DHConst.numRoadSegments {
            let seg = DriveHardRoad.createRoadSegment()
            seg.position.z = Float(-i) * DHConst.roadSegmentLength
            scene.rootNode.addChildNode(seg)
            roadSegments.append(seg)
        }
    }

    private func setupPlayer() {
        playerNode = DriveHardCar.createPlayerCar()
        playerNode.position = SCNVector3(DHConst.laneCenter, 0, 0)
        scene.rootNode.addChildNode(playerNode)
    }

    private func setupObstaclePool() {
        let types = DHConst.obstacleTypes
        for i in 0..<DHConst.obstaclePoolSize {
            let car = DriveHardCar.createObstacleCar(type: types[i % types.count])
            car.isHidden = true
            car.setValue(false, forKey: "active")
            scene.rootNode.addChildNode(car)
            obstaclePool.append(car)
        }
    }

    private func setupCoinPool() {
        for _ in 0..<DHConst.coinPoolSize {
            let coin = DriveHardRoad.createCoin()
            coin.isHidden = true
            coin.setValue(false, forKey: "active")
            scene.rootNode.addChildNode(coin)
            coinPool.append(coin)
        }
    }

    private func setupScenery() {
        // Front row buildings (close to road, dense skyline matching web)
        for i in 0..<14 {
            let bL = DriveHardRoad.createBuilding()
            bL.position = SCNVector3(-7.5 - Float.random(in: 0...1.5), 0, Float(-i) * 9 + Float.random(in: 0...3))
            scene.rootNode.addChildNode(bL)
            buildingsLeft.append(bL)

            let bR = DriveHardRoad.createBuilding()
            bR.position = SCNVector3(7.5 + Float.random(in: 0...1.5), 0, Float(-i) * 9 + Float.random(in: 0...3))
            scene.rootNode.addChildNode(bR)
            buildingsRight.append(bR)
        }

        // Back row buildings (fill skyline depth)
        for i in 0..<10 {
            let bL = DriveHardRoad.createBuilding()
            bL.position = SCNVector3(-13 - Float.random(in: 0...3), 0, Float(-i) * 12 + Float.random(in: 0...4))
            scene.rootNode.addChildNode(bL)
            buildingsLeft.append(bL)

            let bR = DriveHardRoad.createBuilding()
            bR.position = SCNVector3(13 + Float.random(in: 0...3), 0, Float(-i) * 12 + Float.random(in: 0...4))
            scene.rootNode.addChildNode(bR)
            buildingsRight.append(bR)
        }

        // Lamp posts
        for i in 0..<12 {
            let lpL = DriveHardRoad.createLampPost()
            lpL.position = SCNVector3(-5.8, 0, Float(-i) * 14)
            scene.rootNode.addChildNode(lpL)
            lampsLeft.append(lpL)

            let lpR = DriveHardRoad.createLampPost()
            lpR.position = SCNVector3(5.8, 0, Float(-i) * 14)
            lpR.scale.x = -1
            scene.rootNode.addChildNode(lpR)
            lampsRight.append(lpR)
        }
    }

    // MARK: - Game Control

    func startGame() {
        gameState = .playing
        speed = DHConst.baseSpeed
        score = 0
        coinsCollected = 0
        distanceTraveled = 0
        speedPercent = 0
        currentLane = 1
        playerX = DHConst.laneCenter
        targetLaneX = DHConst.laneCenter
        laneSwitchProgress = 1
        inputQueue = []
        spawnTimer = 1.2
        coinSpawnTimer = 0.8
        nearMissTimer = 0
        accumulator = 0
        frameCount = 0
        speedFp = DHConst.baseSpeedFP
        distanceFp = 0
        nearMissBonus = 0
        inputRecording = []

        playerNode.position = SCNVector3(DHConst.laneCenter, 0, 0)
        playerNode.isHidden = false

        // Reset camera
        cameraNode.position = SCNVector3(0, DHConst.cameraY, DHConst.cameraZ)
        cameraNode.look(at: SCNVector3(0, 0.3, -20))
        cameraNode.camera?.fieldOfView = DHConst.baseFOV
        deathAnimTime = 0

        // Remove death trail
        trailNode?.removeFromParentNode()
        trailNode = nil

        // Reset pools
        for obs in obstaclePool {
            obs.isHidden = true
            obs.setValue(false, forKey: "active")
        }
        for coin in coinPool {
            coin.isHidden = true
            coin.setValue(false, forKey: "active")
        }

        cameraNode.camera?.fieldOfView = DHConst.baseFOV
    }

    func handleSwipe(direction: Int) {
        if gameState == .waiting {
            startGame()
            return
        }
        guard gameState == .playing else { return }
        inputQueue.append(direction)
    }

    // MARK: - Game Loop (SCNSceneRendererDelegate)

    private var lastTime: TimeInterval = 0

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        var frameTime = Float(time - lastTime)
        lastTime = time
        if frameTime > 0.25 { frameTime = 0.25 }
        if frameTime <= 0 { return }

        if gameState == .gameOver {
            updateDeathCamera(frameTime)
            return
        }

        guard gameState == .playing else { return }

        // Fixed timestep accumulator (120Hz, matches web)
        // Cap at 10 ticks (~83ms) so we never lose game time above ~12fps
        accumulator += frameTime
        if accumulator > DHConst.fixedDT * 10 { accumulator = DHConst.fixedDT * 10 }

        while accumulator >= DHConst.fixedDT {
            fixedTick()
            accumulator -= DHConst.fixedDT
        }

        // Visual-only updates (per-frame, not scoring-critical)
        updateScenery(frameTime)
        updateCamera(frameTime)
    }

    /// Fixed 120Hz tick — all scoring/physics use integer FP math matching web
    private func fixedTick() {
        frameCount += 1
        let dt = DHConst.fixedDT

        let prevLane = currentLane
        updateInput(dt)
        if currentLane != prevLane {
            inputRecording.append(["frame": frameCount, "lane": currentLane])
        }

        // 1. Movement distance from current speed (integer FP, matches web)
        // Web: const moveZFp = Math.floor(speedFpRef.current / 120)
        let moveZFp = speedFp / DHConst.ticksPerSec
        distanceFp += moveZFp

        // 2. Speed update based on distance score
        // Web: getSpeedMultFp(prevDistScore) uses distance-only score
        let distScore = distanceFp / DHConst.fpScale
        let multFp: Int
        if distScore >= DHConst.diffNightmare { multFp = DHConst.multNightmareFP }
        else if distScore >= DHConst.diffInsane { multFp = DHConst.multInsaneFP }
        else if distScore >= DHConst.diffHard { multFp = DHConst.multHardFP }
        else { multFp = DHConst.multDefaultFP }
        // Web: speedFp = Math.min(MAX_SPEED_FP, speedFp + Math.floor(multFp / 120))
        speedFp = min(DHConst.maxSpeedFP, speedFp + multFp / DHConst.ticksPerSec)

        // Convert FP to float for rendering
        let moveZ = Float(moveZFp) / Float(DHConst.fpScale)
        speed = Float(speedFp) / Float(DHConst.fpScale)
        speedPercent = Float(speedFp - DHConst.baseSpeedFP) / Float(DHConst.maxSpeedFP - DHConst.baseSpeedFP)

        // Move road segments
        for seg in roadSegments {
            seg.position.z += moveZ
            if seg.position.z > DHConst.roadSegmentLength {
                seg.position.z -= DHConst.roadSegmentLength * Float(DHConst.numRoadSegments)
            }
        }

        updateSpawning(dt)
        updateObstacles(moveZ)
        updateCoins(moveZ)

        // Score = distance + coins*50 + nearMiss (matches web exactly)
        // Web: scoreRef.current = Math.floor(distanceFpRef.current / FP_SCALE) + coinsCollectedRef.current * 50 + nearMissBonusRef.current
        score = distanceFp / DHConst.fpScale + coinsCollected * 50 + nearMissBonus
    }

    // MARK: - Update Steps

    private func updateInput(_ dt: Float) {
        if laneSwitchProgress >= 1, !inputQueue.isEmpty {
            let dir = inputQueue.removeFirst()
            let newLane = currentLane + dir
            if newLane >= 0, newLane <= 2 {
                currentLane = newLane
                laneSwitchStartX = playerX
                targetLaneX = DHConst.lanes[currentLane]
                laneSwitchProgress = 0
            }
        }

        if laneSwitchProgress < 1 {
            laneSwitchProgress += dt / DHConst.laneSwitchDuration
            if laneSwitchProgress >= 1 {
                laneSwitchProgress = 1
                playerX = targetLaneX
            } else {
                let t = laneSwitchProgress
                let ease = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
                playerX = laneSwitchStartX + (targetLaneX - laneSwitchStartX) * ease
            }
        }

        playerNode.position.x = playerX
    }

    private func updateSpawning(_ dt: Float) {
        // Obstacles
        spawnTimer -= dt
        if spawnTimer <= 0 {
            spawnPattern()
        }

        // Coins — matches web: spawn 2-5 coins in clear lane
        coinSpawnTimer -= dt
        if coinSpawnTimer <= 0 {
            spawnCoinGroup()
            coinSpawnTimer = 1.2 + Float.random(in: 0...1.8) // web: 1.2 + rng.next() * 1.8
        }
    }

    private func updateObstacles(_ moveZ: Float) {
        var nearMissThisFrame = false

        for obs in obstaclePool {
            guard obs.value(forKey: "active") as? Bool == true else { continue }

            obs.position.z += moveZ

            // Despawn
            if obs.position.z > DHConst.despawnDistance {
                obs.isHidden = true
                obs.setValue(false, forKey: "active")
                continue
            }

            // Collision check (AABB)
            let dx = abs(obs.position.x - playerX)
            let dz = abs(obs.position.z - playerNode.position.z)
            let halfW = (obs.value(forKey: "halfExtents") as? NSValue)?.scnVector3Value.x ?? 0.75
            let halfD = (obs.value(forKey: "halfExtents") as? NSValue)?.scnVector3Value.z ?? 1.4

            if dx < (DHConst.playerHalfW + halfW) && dz < (DHConst.playerHalfD + halfD) {
                handleGameOver()
                return
            }

            // Near miss (matches web: z-range check + lateral distance)
            let obsZ = obs.position.z
            if obsZ > -DHConst.playerHalfD && obsZ < DHConst.playerHalfD + 1.0 {
                let lateralDist = abs(obs.position.x - playerX) - (DHConst.playerHalfW + halfW)
                if lateralDist > 0 && lateralDist < DHConst.nearMissDist && nearMissTimer <= 0 {
                    nearMissBonus += 25
                    nearMissThisFrame = true
                    nearMissTimer = 0.5
                }
            }
        }

        if nearMissThisFrame {
            onNearMiss?()
        }
        if nearMissTimer > 0 {
            nearMissTimer -= DHConst.fixedDT
        }
    }

    private func updateCoins(_ moveZ: Float) {
        for coin in coinPool {
            guard coin.value(forKey: "active") as? Bool == true else { continue }

            coin.position.z += moveZ

            // Spin & bob
            coin.eulerAngles.y += DHConst.fixedDT * 3
            let bob = sin(Float(CACurrentMediaTime()) * 3) * 0.25
            coin.position.y = 1.4 + bob

            // Despawn
            if coin.position.z > DHConst.despawnDistance {
                coin.isHidden = true
                coin.setValue(false, forKey: "active")
                continue
            }

            // Collection — circular distance < 1.6, matches web
            let dx = coin.position.x - playerX
            let dz = coin.position.z - playerNode.position.z
            if sqrt(dx * dx + dz * dz) < 1.6 {
                coin.isHidden = true
                coin.setValue(false, forKey: "active")
                coinsCollected += 1
                onCoinCollect?()
            }
        }
    }

    private func updateScenery(_ dt: Float) {
        let moveZ = speed * dt

        func recycleArray(_ arr: inout [SCNNode], spacing: Float, xRange: ClosedRange<Float>) {
            for node in arr {
                node.position.z += moveZ
                if node.position.z > 20 {
                    let minZ = arr.map { $0.position.z }.min() ?? 0
                    node.position.z = minZ - spacing + Float.random(in: 0...spacing * 0.3)
                    if xRange.upperBound > xRange.lowerBound {
                        let sign: Float = node.position.x < 0 ? -1 : 1
                        node.position.x = sign * Float.random(in: xRange)
                    }
                }
            }
        }

        recycleArray(&buildingsLeft, spacing: 9, xRange: 7.5...16)
        recycleArray(&buildingsRight, spacing: 9, xRange: 7.5...16)
        recycleArray(&lampsLeft, spacing: 14, xRange: 5.8...5.8)
        recycleArray(&lampsRight, spacing: 14, xRange: 5.8...5.8)
    }

    private func updateCamera(_ dt: Float) {
        // FOV scales with speed
        let extraFOV = CGFloat(speedPercent) * DHConst.maxExtraFOV
        let targetFOV = DHConst.baseFOV + extraFOV
        if let cam = cameraNode.camera {
            cam.fieldOfView += (targetFOV - cam.fieldOfView) * CGFloat(dt * 3)
        }

        // Camera follows player X slightly
        let targetX = playerX * 0.3
        cameraNode.position.x += (targetX - cameraNode.position.x) * dt * 5
    }

    // MARK: - Spawning

    private func spawnPattern() {
        let sc = score

        if sc >= DHConst.diffNightmare && Float.random(in: 0...1) < 0.55 {
            var lanes = [0, 1, 2]
            lanes.shuffle()
            spawnObstacle(lane: lanes[0])
            spawnObstacle(lane: lanes[1], zOffset: -(2.5 + Float.random(in: 0...3)))
            if Float.random(in: 0...1) < 0.4 {
                spawnObstacle(lane: lanes[2], zOffset: -(6 + Float.random(in: 0...3)))
            }
        } else if sc >= DHConst.diffInsane && Float.random(in: 0...1) < 0.6 {
            let gap = Int.random(in: 0...2)
            for i in 0..<3 where i != gap {
                spawnObstacle(lane: i)
            }
        } else if sc >= DHConst.diffHard && Float.random(in: 0...1) < 0.55 {
            let start = Int.random(in: 0...1)
            spawnObstacle(lane: start)
            spawnObstacle(lane: start + 1)
        } else if sc >= DHConst.diffMedium && Float.random(in: 0...1) < 0.45 {
            let l1 = Int.random(in: 0...2)
            var l2 = Int.random(in: 0...2)
            while l2 == l1 { l2 = Int.random(in: 0...2) }
            spawnObstacle(lane: l1)
            spawnObstacle(lane: l2, zOffset: -4.5)
        } else {
            spawnObstacle(lane: Int.random(in: 0...2))
        }

        let minI: Float
        let maxExtra: Float
        if sc >= DHConst.diffNightmare { minI = 0.28; maxExtra = 0.22 }
        else if sc >= DHConst.diffInsane { minI = 0.36; maxExtra = 0.35 }
        else if sc >= DHConst.diffHard { minI = 0.45; maxExtra = 0.45 }
        else if sc >= DHConst.diffMedium { minI = 0.58; maxExtra = 0.6 }
        else { minI = 0.8; maxExtra = 1.0 }
        spawnTimer = minI + Float.random(in: 0...maxExtra)
    }

    private func spawnObstacle(lane: Int, zOffset: Float = 0) {
        guard let obs = obstaclePool.first(where: { $0.value(forKey: "active") as? Bool == false }) else { return }
        let spawnZ = DHConst.spawnDistance + zOffset
        obs.position = SCNVector3(DHConst.lanes[lane], 0, spawnZ)
        obs.setValue(true, forKey: "active")
        obs.isHidden = false
    }

    /// Spawn 2-5 coins in a clear lane (matches web logic)
    private func spawnCoinGroup() {
        // Find clear lanes — no active obstacles near spawn zone
        let clearLanes = [0, 1, 2].filter { li in
            let lx = DHConst.lanes[li]
            return !obstaclePool.contains { obs in
                guard obs.value(forKey: "active") as? Bool == true else { return false }
                return abs(obs.position.x - lx) < 1.5 &&
                       obs.position.z < DHConst.spawnDistance + 15 &&
                       obs.position.z > DHConst.spawnDistance - 15
            }
        }
        guard !clearLanes.isEmpty else { return }

        let lane = clearLanes.randomElement()!
        let count = 2 + Int.random(in: 0..<4) // 2-5 coins (web: 2 + Math.floor(rng.next() * 4))

        for i in 0..<count {
            guard let coin = coinPool.first(where: { $0.value(forKey: "active") as? Bool == false }) else { break }
            // Web: coin.position.set(LANES[lane], 1.4, SPAWN_DISTANCE - i * 2.2)
            coin.position = SCNVector3(DHConst.lanes[lane], 1.4, DHConst.spawnDistance - Float(i) * 2.2)
            coin.setValue(true, forKey: "active")
            coin.isHidden = false
        }
    }

    // MARK: - Game Over

    private func handleGameOver() {
        gameState = .gameOver
        deathPlayerX = playerX
        deathAnimTime = 0
        deathStartCamPos = cameraNode.position
        deathStartFOV = cameraNode.camera?.fieldOfView ?? DHConst.baseFOV

        // Add trail at crash position
        addDeathTrail()

        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "drivehard_highscore")
        }
    }

    // MARK: - Death Camera Animation

    private func addDeathTrail() {
        let trailLength: Float = 40
        let trailGeo = SCNBox(width: 0.3, height: 0.02, length: CGFloat(trailLength), chamferRadius: 0)
        let trailMat = SCNMaterial()
        trailMat.diffuse.contents = UIColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 0.8)
        trailMat.emission.contents = UIColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1)
        trailMat.lightingModel = .constant
        trailGeo.firstMaterial = trailMat
        let trail = SCNNode(geometry: trailGeo)
        trail.position = SCNVector3(deathPlayerX, 0.03, -trailLength / 2)
        scene.rootNode.addChildNode(trail)
        trailNode = trail
    }

    private func updateDeathCamera(_ dt: Float) {
        deathAnimTime += dt
        let t = deathAnimTime

        if t < 0.6 {
            // Phase 1: Dramatic shake
            let intensity: Float = 0.12 * (1 - t / 0.6)
            let shakeX = Float.random(in: -intensity...intensity)
            let shakeY = Float.random(in: -intensity * 0.5...intensity * 0.5)
            cameraNode.position = SCNVector3(
                deathStartCamPos.x + shakeX,
                deathStartCamPos.y + shakeY,
                deathStartCamPos.z
            )
        } else if t < 2.1 {
            // Phase 2: Sweeping arc zoom out
            let p = (t - 0.6) / 1.5
            let ease = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
            let target = SCNVector3(deathPlayerX * 0.2 + 3, 16, 22)
            cameraNode.position = SCNVector3(
                deathStartCamPos.x + (target.x - deathStartCamPos.x) * ease,
                deathStartCamPos.y + (target.y - deathStartCamPos.y) * ease,
                deathStartCamPos.z + (target.z - deathStartCamPos.z) * ease
            )
            cameraNode.camera?.fieldOfView = deathStartFOV + CGFloat(ease) * 18
        } else if t < 3.5 {
            // Phase 3: Settle at overview
            let p = (t - 2.1) / 1.4
            let ease: Float = 1 - pow(1 - p, 3)
            let arcEnd = SCNVector3(deathPlayerX * 0.2 + 3, 16, 22)
            let settleEnd = SCNVector3(deathPlayerX * 0.15 + 2, 17, 24)
            cameraNode.position = SCNVector3(
                arcEnd.x + (settleEnd.x - arcEnd.x) * ease,
                arcEnd.y + (settleEnd.y - arcEnd.y) * ease,
                arcEnd.z + (settleEnd.z - arcEnd.z) * ease
            )
            cameraNode.camera?.fieldOfView = deathStartFOV + 18 + CGFloat(ease) * 5
        }

        // Look at crash area throughout animation
        let lookT = min(t / 3.5, 1)
        cameraNode.look(at: SCNVector3(deathPlayerX * 0.15, 0.3 + lookT * 1.5, -4 + lookT * 4))
    }
}
