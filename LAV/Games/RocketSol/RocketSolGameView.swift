import SwiftUI
import SpriteKit

struct RocketSolGameView: View {
    var isMatchMode = false
    @State private var vm = RocketSolViewModel()
    @State private var gameStartTime: Date?
    @Environment(\.dismiss) private var dismiss
    @Environment(GamesViewModel.self) private var gamesVM

    var body: some View {
        ZStack {
            // SpriteKit view
            RocketSolSpriteView(scene: vm.gameScene)
                .ignoresSafeArea()

            // HUD overlay
            VStack {
                hudTop
                Spacer()
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
        .onAppear {
            AppDelegate.orientationLock = .landscape
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            }
        }
        .onDisappear {
            AppDelegate.orientationLock = .all
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
            }
        }
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
                Text("\(vm.score)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .shadow(color: Color(RSConst.neonGreen).opacity(0.6), radius: 15)
            }

            Spacer()

            // High score badge
            if vm.highScore > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    Text("\(vm.highScore)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Waiting Overlay

    private var waitingOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    Text("ROCKET")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(RSConst.neonPurple),
                                    Color(RSConst.color(0x6366f1)),
                                    .cyan
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("SOL")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, Color(RSConst.neonGreen)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .font(.system(size: 48, weight: .black, design: .rounded))
                .tracking(3)

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
                Text("HOLD TO FLY")
                    .font(.system(size: 18, weight: .black))
                    .tracking(3)
                    .foregroundColor(.white)

                Text("Collect rings to widen the next pipe")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.bottom, 80)
        }
    }

    // MARK: - Game Over

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundColor(.red)

                VStack(spacing: 12) {
                    Text("\(vm.score)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)

                    Text("FINAL SCORE")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.4))

                    if vm.score >= vm.highScore && vm.score > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                            Text("NEW HIGH SCORE!")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding(24)
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
                            Text("TRY AGAIN")
                                .font(.system(size: 16, weight: .black))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(RSConst.neonGreen),
                                    Color(RSConst.color(0x22c55e))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(RSConst.neonGreen).opacity(0.5), radius: 16, y: 4)
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
}

// MARK: - SpriteKit UIViewRepresentable

struct RocketSolSpriteView: UIViewRepresentable {
    let scene: RocketSolScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.presentScene(scene)
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.showsFPS = false
        view.showsNodeCount = false
        view.allowsTransparency = false
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {}
}

#Preview {
    RocketSolGameView()
        .preferredColorScheme(.dark)
}
