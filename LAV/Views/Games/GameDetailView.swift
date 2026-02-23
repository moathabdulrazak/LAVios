import SwiftUI

struct GameDetailView: View {
    let game: GameInfo
    @Environment(GamesViewModel.self) private var gamesVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: EntryTier?
    @State private var showConfirmation = false
    @State private var appeared = false
    @State private var glowPulse = false
    @State private var showGame = false
    @State private var errorShake: Int = 0
    @Namespace private var tierNS

    var body: some View {
        ZStack {
            // Background
            ZStack {
                Color.lavBackground.ignoresSafeArea()

                VStack {
                    EllipticalGradient(
                        colors: [game.accentColor.opacity(0.12), .clear],
                        center: .top,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.6
                    )
                    .frame(height: 300)
                    .ignoresSafeArea()
                    Spacer()
                }
            }

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Back button
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        .buttonStyle(CardPressStyle())
                        Spacer()
                    }
                    .padding(.top, 6)

                    Spacer().frame(height: 16)

                    compactHero
                        .staggerIn(appeared: appeared, delay: 0)

                    Spacer().frame(height: 20)

                    tierSelector
                        .staggerIn(appeared: appeared, delay: 0.06)

                    // 1v1 games: standard pay-then-join flow
                    Spacer().frame(height: 16)

                    ctaButton
                        .staggerIn(appeared: appeared, delay: 0.12)

                    if game.gameType == .drivehard || game.gameType == .warp || game.gameType == .rocketsol || game.gameType == .solsnake {
                        Spacer().frame(height: 16)

                        playNowButton
                            .staggerIn(appeared: appeared, delay: 0.18)
                    }
                }
                .padding(.horizontal, 20)
            }

            // Error toast
            if let error = gamesVM.errorMessage {
                VStack {
                    Spacer()
                    errorToast(error)
                        .shake(trigger: errorShake)
                        .padding(20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Custom confirmation modal
            if showConfirmation, let tier = selectedTier {
                confirmationModal(tier: tier)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            // Match result
            if let result = gamesVM.matchResult {
                MatchResultView(result: result, game: game) {
                    gamesVM.resetMatch()
                    if result != .waiting { selectedTier = nil }
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            // Joining / Submitting overlay
            if gamesVM.isJoining || gamesVM.isSubmitting {
                joiningOverlay
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.3), value: gamesVM.errorMessage)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: gamesVM.matchResult)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showConfirmation)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: gamesVM.isJoining)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: gamesVM.isSubmitting)
        .sensoryFeedback(.impact(weight: .medium), trigger: showConfirmation)
        .sensoryFeedback(.error, trigger: errorShake)
        .onChange(of: gamesVM.errorMessage) { _, newVal in
            if newVal != nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    errorShake += 1
                }
            }
        }
        .fullScreenCover(isPresented: $showGame, onDismiss: {
            if gamesVM.matchData != nil && gamesVM.lastGameScore > 0 {
                Task { await gamesVM.submitScore() }
            }
        }) {
            if game.gameType == .solsnake {
                SolSnakeGameView(
                    isOnlineMode: true,
                    entryAmount: gamesVM.solSnakeEntryAmount,
                    txSignature: gamesVM.solSnakeTxSignature,
                    verificationToken: gamesVM.solSnakeVerificationToken,
                    paymentTimestamp: gamesVM.solSnakePaymentTimestamp,
                    walletAddress: authVM.currentUser?.walletAddress ?? ""
                )
                .preferredColorScheme(.dark)
            } else if game.gameType == .warp {
                WarpGameView(isMatchMode: gamesVM.matchData != nil)
                    .preferredColorScheme(.dark)
            } else if game.gameType == .rocketsol {
                RocketSolGameView(isMatchMode: gamesVM.matchData != nil)
                    .preferredColorScheme(.dark)
            } else {
                DriveHardGameView(isMatchMode: gamesVM.matchData != nil)
                    .preferredColorScheme(.dark)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { glowPulse = true }
        }
        .onDisappear { gamesVM.resetMatch() }
    }

    // MARK: - Compact Hero

    private var compactHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(game.accentColor.opacity(glowPulse ? 0.15 : 0.06))
                    .frame(width: 70, height: 70)
                    .blur(radius: 16)

                Circle()
                    .fill(game.accentColor.opacity(0.1))
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle().stroke(game.accentColor.opacity(0.3), lineWidth: 1.5)
                    )

                Image(systemName: game.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(game.accentColor)
                    .shadow(color: game.accentColor.opacity(0.6), radius: 6)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(game.name)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.white)

                Text(game.description)
                    .font(.system(size: 12))
                    .foregroundColor(.lavTextSecondary)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Circle()
                        .fill(game.accentColor)
                        .frame(width: 5, height: 5)
                        .shadow(color: game.accentColor, radius: 2)
                    Text(game.gameType == .solsnake ? "OFFLINE" : "1v1")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.5)
                        .foregroundColor(game.accentColor)
                }
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Play Now (Drive Hard)

    private var playNowButton: some View {
        VStack(spacing: 16) {
            Text("No entry fee — just play!")
                .font(.system(size: 13))
                .foregroundColor(.lavTextSecondary)

            Button {
                showGame = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("PLAY NOW")
                        .font(.system(size: 16, weight: .black))
                        .tracking(1.5)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [game.accentColor, game.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: game.accentColor.opacity(0.5), radius: 16, y: 4)
            }
            .buttonStyle(CardPressStyle())
            .sensoryFeedback(.impact(weight: .heavy), trigger: showGame)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.lavSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Tier Selector

    private var tierSelector: some View {
        VStack(spacing: 14) {
            HStack {
                Text("SELECT ENTRY")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundColor(.lavTextMuted)
                Spacer()
            }

            amountChips

            if let tier = selectedTier {
                tierDetailCard(tier)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.lavSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTier?.id)
    }

    private var amountChips: some View {
        HStack(spacing: 6) {
            ForEach(game.entryTiers) { tier in
                let isSelected = selectedTier?.id == tier.id

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        selectedTier = isSelected ? nil : tier
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text(tier.amount < 0.01 ? "FREE" : String(format: "%.2f", tier.amount))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        if tier.amount >= 0.01 {
                            Text("SOL")
                                .font(.system(size: 7, weight: .heavy))
                                .tracking(1)
                        }
                    }
                    .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [game.accentColor, game.accentColor.opacity(0.85)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .matchedGeometryEffect(id: "tier_select", in: tierNS)
                                    .shadow(color: game.accentColor.opacity(0.5), radius: 12, y: 2)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.03))
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.clear : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isSelected)
            }
        }
    }

    private func tierDetailCard(_ tier: EntryTier) -> some View {
        let winAmount = tier.amount * 2 * 0.9

        return VStack(spacing: 12) {
            // Main info row
            HStack(spacing: 0) {
                // Left - Entry info
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.label.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.5)
                        .foregroundColor(game.accentColor)

                    Text(tier.formattedAmount)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 9))
                        Text(tier.playerCount)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.lavTextMuted)
                }

                Spacer()

                // Right - Win amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text("YOU WIN")
                        .font(.system(size: 8, weight: .black))
                        .tracking(1.5)
                        .foregroundColor(.lavEmerald.opacity(0.7))

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                        Text(String(format: "%.4f", winAmount))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .foregroundColor(.lavEmerald)

                    Text("SOL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.lavEmerald.opacity(0.6))
                }
            }

            // Info line
            HStack(spacing: 16) {
                infoTag(icon: "trophy.fill", text: "Winner takes 90%")
                infoTag(icon: "checkmark.shield.fill", text: "Anti-cheat verified")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(game.accentColor.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(game.accentColor.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func infoTag(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(.lavTextMuted)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            withAnimation { showConfirmation = true }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                Text(selectedTier != nil ? "ENTER GAME" : "SELECT AN ENTRY")
                    .font(.system(size: 15, weight: .black))
                    .tracking(1)
            }
            .foregroundColor(selectedTier != nil ? .black : .white.opacity(0.3))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(ctaBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: selectedTier != nil ? game.accentColor.opacity(0.5) : .clear, radius: 16, y: 4)
        }
        .buttonStyle(CardPressStyle())
        .disabled(selectedTier == nil)
        .animation(.easeInOut(duration: 0.2), value: selectedTier?.id)
        .sensoryFeedback(.impact(weight: .heavy), trigger: gamesVM.isJoining)
    }

    @ViewBuilder
    private var ctaBackground: some View {
        if selectedTier != nil {
            LinearGradient(
                colors: [game.accentColor, game.accentColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.white.opacity(0.04)
        }
    }

    // MARK: - Confirmation Modal

    private func confirmationModal(tier: EntryTier) -> some View {
        let winAmount = tier.amount * 2 * 0.9
        let fee = tier.amount * 2 * 0.1

        return ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showConfirmation = false }
                }

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(game.accentColor.opacity(0.12))
                            .frame(width: 56, height: 56)

                        Image(systemName: game.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(game.accentColor)
                            .shadow(color: game.accentColor.opacity(0.5), radius: 6)
                    }

                    Text("Confirm Entry")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)

                    Text(game.name + " · " + tier.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.lavTextSecondary)
                }
                .padding(.top, 28)
                .padding(.bottom, 20)

                // Breakdown
                VStack(spacing: 0) {
                    confirmRow(label: "Entry", value: tier.formattedAmount, color: .white)
                    Divider().overlay(Color.white.opacity(0.06))
                    confirmRow(label: "Platform fee (10%)", value: String(format: "%.4f SOL", fee), color: .lavTextSecondary)
                    Divider().overlay(Color.white.opacity(0.06))
                    confirmRow(label: "You win", value: String(format: "%.4f SOL", winAmount), color: .lavEmerald, bold: true)
                }
                .padding(.horizontal, 20)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 10))
                    Text("Anti-cheat verified · Fair matchmaking")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.lavTextMuted)
                .padding(.top, 16)

                // Buttons
                VStack(spacing: 10) {
                    Button {
                        withAnimation { showConfirmation = false }
                        Task {
                            if game.gameType == .solsnake {
                                await gamesVM.joinSolSnake(tier: tier)
                                if gamesVM.solSnakePaymentReady {
                                    showGame = true
                                }
                            } else {
                                await gamesVM.joinGame(game: game, tier: tier)
                                if gamesVM.matchData != nil {
                                    showGame = true
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 13))
                            Text("PAY \(tier.formattedAmount) & JOIN")
                                .font(.system(size: 15, weight: .black))
                                .tracking(0.5)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [game.accentColor, game.accentColor.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: game.accentColor.opacity(0.4), radius: 16, y: 4)
                    }
                    .buttonStyle(CardPressStyle())
                    .sensoryFeedback(.impact(weight: .heavy), trigger: gamesVM.isJoining)

                    Button {
                        withAnimation { showConfirmation = false }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.lavTextSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(CardPressStyle())
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.lavSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: game.accentColor.opacity(0.1), radius: 40, y: 10)
            .padding(.horizontal, 28)
            .offset(y: -30)
        }
    }

    private func confirmRow(label: String, value: String, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.lavTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: bold ? .bold : .medium, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
        }
        .padding(.vertical, 13)
    }

    // MARK: - Error Toast

    private func errorToast(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.lavRed)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white)
            Spacer()
            Button { gamesVM.errorMessage = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.lavTextMuted)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.lavSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.lavRed.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Joining Overlay

    private var joiningOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(game.accentColor.opacity(0.15), lineWidth: 3)
                        .frame(width: 52, height: 52)
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(game.accentColor)
                }

                Text(gamesVM.isSubmitting ? "Submitting score..." : "Entering match...")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(gamesVM.isSubmitting ? "Checking results" : "Processing payment & matching")
                    .font(.system(size: 12))
                    .foregroundColor(.lavTextSecondary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.lavSurface.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(game.accentColor.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: game.accentColor.opacity(0.15), radius: 24)
        }
    }
}

#Preview {
    NavigationStack {
        GameDetailView(game: GameInfo.allGames[1])
    }
    .environment(GamesViewModel())
    .environment(AuthViewModel())
    .preferredColorScheme(.dark)
}
