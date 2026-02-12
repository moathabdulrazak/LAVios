import SwiftUI
import SceneKit

struct WarpGameView: View {
    var isMatchMode = false
    @State private var vm = WarpViewModel()
    @State private var gameStartTime: Date?
    @Environment(\.dismiss) private var dismiss
    @Environment(GamesViewModel.self) private var gamesVM

    var body: some View {
        ZStack {
            // SceneKit view
            WarpSceneView(vm: vm)
                .ignoresSafeArea()

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
                print("[LAV Game] Match game over: score=\(vm.score) duration=\(durationMs)ms")
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
                Text("\(vm.score)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .shadow(color: vm.showWallPass ? .yellow.opacity(0.8) : .purple.opacity(0.3), radius: vm.showWallPass ? 15 : 8)

                Spacer()

                // Combo
                if vm.combo > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("x\(vm.combo)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundColor(
                        vm.combo >= 10 ? .orange :
                        vm.combo >= 5 ? .yellow :
                        Color(uiColor: WConst.color(0x88ccff))
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
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
                                colors: [
                                    Color(uiColor: WConst.color(0x6366f1)),
                                    Color(uiColor: WConst.color(0x8b5cf6)),
                                    .orange,
                                    .red
                                ],
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

            Text("\(Int(WConst.v0 + (WConst.vMax - WConst.v0) * vm.speedPercent)) m/s")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Waiting Overlay

    private var waitingOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("WARP")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(uiColor: WConst.color(0x8b5cf6))],
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
                Text("TOUCH TO LAUNCH")
                    .font(.system(size: 18, weight: .black))
                    .tracking(3)
                    .foregroundColor(.white)

                Text("Drag to move through the gaps")
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
                Text("CRASHED")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundColor(.red)

                VStack(spacing: 12) {
                    scoreRow(label: "Score", value: "\(vm.score)", icon: "flag.checkered", color: .white)
                    scoreRow(label: "Walls", value: "\(vm.wallsPassed)", icon: "square.grid.3x3", color: Color(uiColor: WConst.color(0x8b5cf6)))
                    if vm.gameScene.maxCombo > 1 {
                        scoreRow(label: "Max Combo", value: "x\(vm.gameScene.maxCombo)", icon: "bolt.fill", color: .orange)
                    }
                    if vm.score >= vm.highScore && vm.score > 0 {
                        scoreRow(label: "New Best!", value: "\(vm.highScore)", icon: "trophy.fill", color: .yellow)
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
                                colors: [
                                    Color(uiColor: WConst.color(0x8b5cf6)),
                                    Color(uiColor: WConst.color(0x6366f1))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .purple.opacity(0.5), radius: 16, y: 4)
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

// MARK: - SceneKit UIViewRepresentable (raw touches for zero-latency tracking)

struct WarpSceneView: UIViewRepresentable {
    let vm: WarpViewModel

    func makeUIView(context: Context) -> WarpTouchView {
        let touchView = WarpTouchView(vm: vm)
        return touchView
    }

    func updateUIView(_ uiView: WarpTouchView, context: Context) {}
}

/// Custom UIView that hosts SCNView and handles touches directly.
/// Using raw touchesBegan/Moved/Ended instead of gesture recognizers
/// eliminates the ~150ms pan-gesture recognition delay — ship starts
/// tracking instantly on finger contact.
final class WarpTouchView: UIView {
    let vm: WarpViewModel
    private let scnView: SCNView

    init(vm: WarpViewModel) {
        self.vm = vm
        self.scnView = SCNView()
        super.init(frame: .zero)
        isMultipleTouchEnabled = false

        // Configure SceneKit view
        scnView.scene = vm.gameScene.scene
        scnView.pointOfView = vm.gameScene.cameraNode
        scnView.delegate = vm.gameScene
        scnView.isPlaying = true
        scnView.showsStatistics = false
        scnView.backgroundColor = UIColor(red: 0x0e/255, green: 0x05/255, blue: 0x20/255, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.isUserInteractionEnabled = false // touches go through to us

        // HDR + Bloom
        let cam = vm.gameScene.cameraNode.camera
        cam?.wantsHDR = true
        cam?.bloomIntensity = 0.35
        cam?.bloomThreshold = 0.85
        cam?.bloomBlurRadius = 10
        cam?.wantsExposureAdaptation = false
        cam?.exposureOffset = 1.0
        cam?.minimumExposure = -1
        cam?.maximumExposure = 4
        cam?.saturation = 1.2

        // Edge detection
        if let technique = WarpEdgeDetection.makeTechnique() {
            scnView.technique = technique
        }

        scnView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scnView)
        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: topAnchor),
            scnView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scnView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private func normalizedCoords(from touch: UITouch) -> (Float, Float) {
        let loc = touch.location(in: self)
        let nx = Float((loc.x / bounds.width) * 2 - 1)
        let ny = Float(-((loc.y / bounds.height) * 2 - 1))
        return (nx, ny)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let (nx, ny) = normalizedCoords(from: touch)
        vm.touchBegan(normalizedX: nx, normalizedY: ny)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let (nx, ny) = normalizedCoords(from: touch)
        vm.touchMoved(normalizedX: nx, normalizedY: ny)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        vm.touchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        vm.touchEnded()
    }
}

#Preview {
    WarpGameView()
        .preferredColorScheme(.dark)
}
