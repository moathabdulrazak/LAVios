import SwiftUI
import SpriteKit

struct SolSnakeGameView: View {
    var isOnlineMode: Bool = true  // Default to online sandbox
    var entryAmount: Double = 0
    var txSignature: String? = nil
    var verificationToken: String? = nil
    var paymentTimestamp: Int? = nil
    var walletAddress: String = ""

    @State private var vm = SolSnakeViewModel()
    @State private var scene: SolSnakeScene?
    @State private var boostPressed = false
    @State private var showDebug = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // SpriteKit game
            if let scene = scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
            } else {
                Color(uiColor: SNColors.bgPrimary).ignoresSafeArea()
            }

            // Joystick overlay (only during gameplay)
            if vm.gameStarted && vm.isAlive {
                SolSnakeJoystick { dx, dy in
                    vm.sendInput(dirX: Float(dx), dirY: Float(dy), isBoosting: boostPressed)
                }
                .ignoresSafeArea()

                boostButton
            }

            // HUD (only during gameplay)
            if vm.gameStarted && !vm.showEndScreen {
                gameHUD
            }

            // Close button
            closeButton

            // Start overlay (offline only)
            if !isOnlineMode && !vm.gameStarted {
                startOverlay
            }

            // Online overlays
            if isOnlineMode && !vm.gameStarted {
                onlineOverlay
            }

            // Kill notifications (online)
            if isOnlineMode && !vm.killNotifications.isEmpty {
                killNotificationOverlay
            }

            // Debug overlay (tap close button 3 times to toggle)
            if showDebug {
                debugOverlay
            }

            // Death flash
            if vm.showDeathFlash {
                Color.red.opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // End screen
            if vm.showEndScreen {
                endScreenOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.showDeathFlash)
        .animation(.spring(response: 0.4), value: vm.showEndScreen)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .onAppear {
            setupScene()
            // Force landscape
            AppDelegate.orientationLock = .landscape
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            }
        }
        .onDisappear {
            vm.cleanup()
            scene?.cleanup()
            scene = nil
            // Restore portrait
            AppDelegate.orientationLock = .all
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
            }
        }
    }

    // MARK: - Scene Setup

    private func setupScene() {
        let s = SolSnakeScene(size: CGSize(width: 844, height: 390))
        s.scaleMode = .resizeFill
        vm.isOnlineMode = isOnlineMode
        vm.scene = s
        vm.setup()
        scene = s

        // Connect to server
        if isOnlineMode {
            let skin = Int.random(in: 0..<SNConst.snakeSkins.count)
            let mode = entryAmount > 0 ? "arena" : "sandbox"
            print("[SolSnakeGV] Connecting: online=\(isOnlineMode), mode=\(mode), entry=\(entryAmount), wallet=\(walletAddress.prefix(8))..., ts=\(paymentTimestamp.map(String.init) ?? "nil")")
            vm.connectToServer(
                playerName: "Player",
                skin: skin,
                mode: mode,
                entryAmount: entryAmount,
                txSignature: txSignature,
                verificationToken: verificationToken,
                walletAddress: walletAddress,
                paymentTimestamp: paymentTimestamp
            )
        }
    }

    // MARK: - Start Overlay (Offline)

    private var startOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("SOL SNAKE")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(uiColor: SNColors.uiPrimary)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("TAP TO START")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .onTapGesture {
            vm.startGame()
        }
    }

    // MARK: - Online Overlay

    private var onlineOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("SOL SNAKE")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(uiColor: SNColors.uiPrimary)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                switch vm.connectionState {
                case .disconnected:
                    connectionStatusView(text: "Disconnected", showSpinner: false)
                case .connecting:
                    connectionStatusView(text: "Connecting...", showSpinner: true)
                case .lobby(let playerCount):
                    lobbyView(playerCount: playerCount)
                case .countdown(let seconds):
                    countdownView(seconds: seconds)
                case .playing:
                    connectionStatusView(text: "Starting...", showSpinner: true)
                case .gameEnded:
                    connectionStatusView(text: "Game Ended", showSpinner: false)
                case .error(let msg):
                    errorView(message: msg)
                }
            }
        }
    }

    private func connectionStatusView(text: String, showSpinner: Bool) -> some View {
        VStack(spacing: 16) {
            if showSpinner {
                ProgressView()
                    .tint(Color(uiColor: SNColors.uiPrimary))
                    .scaleEffect(1.2)
            }
            Text(text)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private func lobbyView(playerCount: Int) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(uiColor: SNColors.uiPrimary))
                Text("\(playerCount) player\(playerCount == 1 ? "" : "s") in lobby")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text("Waiting for game to start...")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))

            ProgressView()
                .tint(Color(uiColor: SNColors.uiPrimary))
        }
    }

    private func countdownView(seconds: Int) -> some View {
        VStack(spacing: 16) {
            Text("\(seconds)")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundColor(Color(uiColor: SNColors.uiPrimary))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: seconds)

            Text("Game starting soon...")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(Color(uiColor: SNColors.uiDanger))

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                let skin = Int.random(in: 0..<SNConst.snakeSkins.count)
                let mode = entryAmount > 0 ? "arena" : "sandbox"
                vm.connectToServer(
                    playerName: "Player",
                    skin: skin,
                    mode: mode,
                    entryAmount: entryAmount,
                    txSignature: txSignature,
                    verificationToken: verificationToken,
                    walletAddress: walletAddress,
                    paymentTimestamp: paymentTimestamp
                )
            } label: {
                Text("RETRY")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundColor(.black)
                    .frame(width: 140, height: 44)
                    .background(Color(uiColor: SNColors.uiPrimary))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Kill Notifications

    private var killNotificationOverlay: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    ForEach(vm.killNotifications) { notification in
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(uiColor: SNColors.uiDanger))
                            Text("Killed \(notification.victimName)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            if notification.reward > 0 {
                                Text("+\(String(format: "%.4f", notification.reward)) SOL")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(uiColor: SNColors.uiSuccess))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.top, 50)
                .padding(.trailing, 16)
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.3), value: vm.killNotifications.count)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
            }
            Spacer()
        }
    }

    // MARK: - Boost Button

    private var boostButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Button {} label: {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 28))
                            .foregroundColor(boostPressed ? .white : (vm.length >= SNConst.minBoostLength ? .white : .gray))
                    }
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(boostPressed
                                ? LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : vm.length >= SNConst.minBoostLength
                                    ? LinearGradient(colors: [Color(uiColor: .hex("ff6600")), .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(boostPressed ? Color.orange.opacity(0.8) : Color.orange.opacity(0.4), lineWidth: 3)
                    )
                    .shadow(color: boostPressed ? .orange.opacity(0.7) : .clear, radius: 15)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if vm.length >= SNConst.minBoostLength {
                                    boostPressed = true
                                }
                            }
                            .onEnded { _ in
                                boostPressed = false
                            }
                    )

                    Text("BOOST")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(vm.length >= SNConst.minBoostLength ? .orange : .gray)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Game HUD

    private var gameHUD: some View {
        ZStack {
            // Leaderboard (top-left)
            VStack {
                HStack {
                    leaderboardView
                        .padding(.top, 8)
                        .padding(.leading, 16)
                    Spacer()
                }
                Spacer()
            }

            // Score + length (bottom-left)
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 11))
                            Text("\(vm.score)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        .foregroundColor(.white)

                        HStack(spacing: 4) {
                            Text("Length: \(vm.length)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        // Latency (online only)
                        if isOnlineMode && vm.latency > 0 {
                            Text("\(vm.latency)ms")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(vm.latency < 100 ? .green.opacity(0.6) : .orange.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.leading, 16)
                    .padding(.bottom, 24)

                    Spacer()
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Leaderboard

    private var leaderboardView: some View {
        return VStack(alignment: .leading, spacing: 2) {
            Text("LEADERBOARD")
                .font(.system(size: 8, weight: .black))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 2)

            ForEach(Array(vm.leaderboard.prefix(5).enumerated()), id: \.element.id) { i, entry in
                let isLocal = isOnlineMode ? entry.name == "Player" || entry.name == "You" : entry.id == "local"
                HStack(spacing: 6) {
                    Text("\(i + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 14, alignment: .trailing)

                    Text(entry.name)
                        .font(.system(size: 10, weight: isLocal ? .bold : .medium))
                        .foregroundColor(isLocal ? Color(uiColor: SNColors.uiPrimary) : .white)
                        .lineLimit(1)
                        .frame(maxWidth: 80, alignment: .leading)

                    Spacer()

                    Text("\(entry.score)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(8)
        .frame(width: 150)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - End Screen

    private var endScreenOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("ELIMINATED")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundColor(Color(uiColor: SNColors.uiDanger))

                // Stats
                VStack(spacing: 12) {
                    statRow(label: "Score", value: "\(vm.score)", icon: "flag.checkered", color: .white)
                    statRow(label: "Kills", value: "\(vm.killCount)", icon: "xmark.circle.fill", color: Color(uiColor: SNColors.uiDanger))
                    statRow(label: "High Score", value: "\(vm.highScore)", icon: "trophy.fill", color: .yellow)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )

                // Buttons
                HStack(spacing: 16) {
                    Button {
                        vm.restart()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .bold))
                            Text("PLAY AGAIN")
                                .font(.system(size: 15, weight: .black))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(width: 180, height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color(uiColor: SNColors.uiPrimary), Color(uiColor: SNColors.uiPrimary).opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color(uiColor: SNColors.uiPrimary).opacity(0.5), radius: 16, y: 4)
                    }

                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 12, weight: .bold))
                            Text("LEAVE")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(0.5)
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 120, height: 50)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }

    private func statRow(label: String, value: String, icon: String, color: Color) -> some View {
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
                .font(.system(size: 18, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
        }
    }

    // MARK: - Debug Overlay

    private var debugOverlay: some View {
        VStack {
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEBUG")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(.yellow)
                    Text("mode: \(isOnlineMode ? "ONLINE" : "OFFLINE")")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Text("conn: \(vm.debugConnectionState)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Text("started: \(vm.gameStarted ? "YES" : "NO")")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Text("alive: \(vm.isAlive ? "YES" : "NO")")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Text("players: \(vm.debugPlayerCount)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Text("orbs: \(vm.debugOrbCount)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Text("schema: \(vm.debugSchemaInfo)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Text("latency: \(vm.latency)ms")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.green.opacity(0.8))
                .padding(6)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.leading, 16)
                .padding(.bottom, 80)

                Spacer()
            }
        }
        .allowsHitTesting(false)
    }
}
