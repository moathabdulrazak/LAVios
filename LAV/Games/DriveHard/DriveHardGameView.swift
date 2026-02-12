import SwiftUI
import SceneKit

struct DriveHardGameView: View {
    var isMatchMode = false
    @State private var vm = DriveHardViewModel()
    @State private var gameStartTime: Date?
    @Environment(\.dismiss) private var dismiss
    @Environment(GamesViewModel.self) private var gamesVM

    var body: some View {
        ZStack {
            // SceneKit view
            DriveHardSceneView(vm: vm)
                .ignoresSafeArea()
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            let dx = value.translation.width
                            if abs(dx) > abs(value.translation.height) {
                                if dx < 0 {
                                    vm.swipeLeft()
                                } else {
                                    vm.swipeRight()
                                }
                            }
                        }
                )
                .onTapGesture {
                    if vm.gameState == .waiting {
                        vm.tapToStart()
                    }
                }

            // HUD overlay
            VStack {
                hudTop
                Spacer()
                if vm.gameState == .playing {
                    speedBar
                        .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Near miss popup
            if vm.showNearMiss {
                nearMissPopup
                    .transition(.scale.combined(with: .opacity))
            }

            // Coin collect popup
            if vm.showCoinCollect {
                coinCollectPopup
                    .transition(.scale.combined(with: .opacity))
            }

            // Waiting overlay
            if vm.gameState == .waiting {
                waitingOverlay
                    .transition(.opacity)
            }

            // Game over overlay
            if vm.gameState == .gameOver {
                gameOverOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.gameState)
        .animation(.spring(response: 0.3), value: vm.showNearMiss)
        .animation(.spring(response: 0.2), value: vm.showCoinCollect)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .onAppear { vm.setup() }
        .onChange(of: vm.gameState) { _, newState in
            if newState == .playing && gameStartTime == nil {
                gameStartTime = Date()
            }
            if newState == .gameOver && isMatchMode {
                let durationMs = Int((Date().timeIntervalSince(gameStartTime ?? Date())) * 1000)
                gamesVM.lastGameScore = vm.score
                gamesVM.lastGameDurationMs = durationMs
                gamesVM.lastInputRecording = vm.gameScene.inputRecording.map { entry in
                    InputRecord(frame: entry["frame"] as? Int ?? 0, lane: entry["lane"] as? Int)
                }
                gamesVM.lastScoreBreakdown = [
                    "distance_fp": vm.gameScene.distanceFp,
                    "coins_collected": vm.gameScene.coinsCollected,
                    "near_miss_bonus": vm.gameScene.nearMissBonus,
                    "death_frame": vm.gameScene.frameCount,
                ]
                print("[LAV Game] Match game over: score=\(vm.score) duration=\(durationMs)ms inputs=\(gamesVM.lastInputRecording.count) distFp=\(vm.gameScene.distanceFp) coins=\(vm.gameScene.coinsCollected) nearMiss=\(vm.gameScene.nearMissBonus) frame=\(vm.gameScene.frameCount)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - HUD Top

    private var hudTop: some View {
        HStack {
            // Back button
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            if vm.gameState == .playing {
                // Score
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(vm.score)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

                Spacer()

                // Coins
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    Text("\(vm.coins)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Speed Bar

    private var speedBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(vm.speedPercent), height: 6)
                        .animation(.easeOut(duration: 0.2), value: vm.speedPercent)
                }
            }
            .frame(height: 6)
            .frame(maxWidth: 200)

            Text("\(Int(DHConst.baseSpeed + (DHConst.maxSpeed - DHConst.baseSpeed) * vm.speedPercent)) km/h")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Near Miss

    private var nearMissPopup: some View {
        Text("NEAR MISS +25")
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: .orange.opacity(0.8), radius: 10)
            .offset(y: -60)
    }

    // MARK: - Coin Collect

    private var coinCollectPopup: some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundColor(.yellow)
            Text("+50")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.yellow)
        }
        .shadow(color: .yellow.opacity(0.8), radius: 8)
        .offset(y: -30)
    }

    // MARK: - Waiting

    private var waitingOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("DRIVE HARD")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(uiColor: UIColor(red: 0.3, green: 0.55, blue: 1, alpha: 1))],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                if vm.highScore > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        Text("Best: \(vm.highScore)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Text("TAP TO START")
                    .font(.system(size: 18, weight: .black))
                    .tracking(3)
                    .foregroundColor(.white)

                Text("Swipe left/right to change lanes")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.bottom, 80)
        }
    }

    // MARK: - Game Over

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    scoreRow(label: "Score", value: "\(vm.score)", icon: "flag.checkered", color: .white)
                    scoreRow(label: "Coins", value: "\(vm.coins)", icon: "dollarsign.circle.fill", color: .yellow)
                    if vm.score >= vm.highScore {
                        scoreRow(label: "New Best!", value: "\(vm.highScore)", icon: "trophy.fill", color: .orange)
                    } else {
                        scoreRow(label: "Best", value: "\(vm.highScore)", icon: "trophy.fill", color: .white.opacity(0.6))
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )

                if isMatchMode {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Submitting score...")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(height: 54)
                } else {
                    Button {
                        vm.restart()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .bold))
                            Text("PLAY AGAIN")
                                .font(.system(size: 16, weight: .black))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [Color(uiColor: UIColor(red: 0.3, green: 0.55, blue: 1, alpha: 1)), Color(uiColor: UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1))],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .blue.opacity(0.5), radius: 16, y: 4)
                    }

                    Button { dismiss() } label: {
                        Text("Exit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private func scoreRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
        }
    }
}

// MARK: - SceneKit UIViewRepresentable

struct DriveHardSceneView: UIViewRepresentable {
    let vm: DriveHardViewModel

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = vm.gameScene.scene
        scnView.pointOfView = vm.gameScene.cameraNode
        scnView.delegate = vm.gameScene
        scnView.isPlaying = true
        scnView.showsStatistics = false
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60

        // HDR + Bloom to match web's UnrealBloomPass + ACES tone mapping
        let cam = vm.gameScene.cameraNode.camera
        cam?.wantsHDR = true
        cam?.bloomIntensity = 0.4
        cam?.bloomThreshold = 0.85
        cam?.bloomBlurRadius = 10
        cam?.wantsExposureAdaptation = false
        cam?.exposureOffset = 0.8
        cam?.minimumExposure = -1
        cam?.maximumExposure = 4
        cam?.contrast = 0.08
        cam?.saturation = 1.15

        // Sobel edge detection outline (Borderlands style)
        if let technique = DriveHardEdgeDetection.makeTechnique() {
            scnView.technique = technique
        }

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

#Preview {
    DriveHardGameView()
        .preferredColorScheme(.dark)
}
