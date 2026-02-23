import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case earnings = "Results"
    case play = "Play"
    case funds = "Funds"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .play: return "gamecontroller.fill"
        case .earnings: return "trophy.fill"
        case .funds: return "wallet.pass.fill"
        }
    }

    var color: Color {
        switch self {
        case .play: return .lavEmerald
        case .earnings: return .lavCyan
        case .funds: return .lavYellow
        }
    }
}

struct MainTabView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GamesViewModel.self) private var gamesVM
    @State private var selectedTab: AppTab = .play
    @State private var showProfile = false
    @State private var appeared = false
    @State private var playPulse = false
    @State private var balancePop = false
    @State private var lastBalance: Double = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.lavBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .staggerIn(appeared: appeared, delay: 0)

                TabView(selection: $selectedTab) {
                    EarningsView()
                        .tag(AppTab.earnings)
                    GamesView()
                        .tag(AppTab.play)
                    FundsView()
                        .tag(AppTab.funds)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .bottom)
            }

            // Tab bar
            tabBar
                .staggerIn(appeared: appeared, delay: 0.12)

            // Balance reveal overlay
            if gamesVM.showBalanceReveal {
                BalanceRevealView(
                    oldBalance: gamesVM.balanceRevealOldBalance,
                    newBalance: gamesVM.balanceRevealNewBalance,
                    isWin: gamesVM.balanceRevealIsWin
                ) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        gamesVM.showBalanceReveal = false
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sensoryFeedback(.selection, trigger: showProfile)
        .onChange(of: gamesVM.walletBalance) { old, new in
            guard old != 0, old != new else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                balancePop = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.2)) { balancePop = false }
            }
        }
        .task { await gamesVM.loadEarnings() }
        .onAppear {
            gamesVM.startBalanceRefresh(
                walletAddress: authVM.currentUser?.walletAddress,
                userId: authVM.currentUser?.id
            )
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { playPulse = true }
        }
        .onDisappear {
            gamesVM.stopBalanceRefresh()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            // Avatar + Name
            Button { showProfile = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.lavSurface)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.lavEmerald.opacity(0.5), .lavCyan.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )

                        Text(String((authVM.currentUser?.username ?? "U").prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(authVM.currentUser?.username ?? "Player")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Wallet pill — taps to Funds tab
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                    selectedTab = .funds
                }
            } label: {
                HStack(spacing: 6) {
                    Text(gamesVM.isLoadingBalance && gamesVM.walletBalance == 0 ? "-.--" : String(format: "%.3f", gamesVM.walletBalance))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: gamesVM.walletBalance))

                    Text("SOL")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1)
                        .foregroundColor(.lavTextMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.lavSurface)
                        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
                )
                .scaleEffect(balancePop ? 1.08 : 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        VStack(spacing: 0) {
            // Fade gradient so content doesn't overlap
            LinearGradient(
                colors: [.clear, Color.lavBackground.opacity(0.9), Color.lavBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 0) {
                sideTab(.earnings)
                Spacer()
                centerPlayButton
                Spacer()
                sideTab(.funds)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
            .background(Color.lavBackground)
        }
    }

    private func sideTab(_ tab: AppTab) -> some View {
        let selected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if selected {
                        Circle()
                            .fill(tab.color.opacity(0.12))
                            .frame(width: 44, height: 44)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(selected ? tab.color : .lavTextMuted)
                }
                .frame(width: 44, height: 44)

                Text(tab.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(selected ? tab.color : .lavTextMuted)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var centerPlayButton: some View {
        let selected = selectedTab == .play

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                selectedTab = .play
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    // Subtle glow behind
                    Circle()
                        .fill(Color.lavEmerald.opacity(selected ? (playPulse ? 0.12 : 0.06) : 0))
                        .frame(width: 56, height: 56)
                        .blur(radius: 10)

                    // Main circle
                    Circle()
                        .fill(
                            selected
                                ? LinearGradient(
                                    colors: [.lavEmerald, Color(hex: "00cc6a")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.lavSurface, Color.lavSurface],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(
                                    selected
                                        ? Color.lavEmerald.opacity(0.6)
                                        : Color.white.opacity(0.1),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(
                            color: selected ? .lavEmerald.opacity(0.4) : .clear,
                            radius: 12, y: 2
                        )

                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(selected ? .black : .lavTextMuted)
                }
                .frame(width: 50, height: 50)

                Text("PLAY")
                    .font(.system(size: 9, weight: .black))
                    .tracking(2)
                    .foregroundColor(selected ? .lavEmerald : .lavTextMuted)
            }
        }
        .buttonStyle(PlayButtonStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: selected)
    }
}

struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Profile Sheet

struct ProfileSheet: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GamesViewModel.self) private var gamesVM
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.lavBackground.ignoresSafeArea()

            // Subtle glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.lavEmerald.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(y: -120)
                .blur(radius: 40)

            VStack(spacing: 0) {
                // Avatar + Name
                profileHeader
                    .staggerIn(appeared: appeared, delay: 0)

                Spacer().frame(height: 24)

                // Stats row
                statsRow
                    .staggerIn(appeared: appeared, delay: 0.06)

                Spacer().frame(height: 16)

                // Info cards
                VStack(spacing: 8) {
                    walletCard
                        .staggerIn(appeared: appeared, delay: 0.1)

                    emailCard
                        .staggerIn(appeared: appeared, delay: 0.13)
                }

                Spacer()

                // Sign out
                signOutButton
                    .staggerIn(appeared: appeared, delay: 0.16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        let initial = String((authVM.currentUser?.username ?? "U").prefix(1)).uppercased()

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.lavEmerald.opacity(0.3), .lavCyan.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))

                Text(initial)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: .lavEmerald.opacity(0.2), radius: 16)

            VStack(spacing: 4) {
                Text(authVM.currentUser?.username ?? "Player")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)

                Text("Active Player")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lavEmerald)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: String(format: "%.3f", gamesVM.walletBalance),
                label: "Balance",
                color: .lavEmerald
            )
            Spacer()
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 32)
            Spacer()
            statItem(
                value: "\(gamesVM.earnings?.totalGames ?? 0)",
                label: "Games",
                color: .lavCyan
            )
            Spacer()
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 32)
            Spacer()
            statItem(
                value: "\(gamesVM.earnings?.wins ?? 0)",
                label: "Wins",
                color: .lavPurple
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lavSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.lavTextMuted)
        }
    }

    // MARK: - Wallet Card

    private var walletCard: some View {
        let wallet = authVM.currentUser?.walletAddress
        let shortWallet = wallet.map { String($0.prefix(6)) + "..." + String($0.suffix(4)) } ?? "Not connected"

        return Button {
            if let wallet = wallet {
                UIPasteboard.general.string = wallet
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "9945FF").opacity(0.2), Color(hex: "14F195").opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)

                    Text("◎")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "14F195"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Wallet Address")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(shortWallet)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.lavTextSecondary)
                }

                Spacer()

                // Copy button
                ZStack {
                    if copied {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.lavEmerald)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.lavTextMuted)
                    }
                }
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .animation(.easeInOut(duration: 0.2), value: copied)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.lavSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: copied)
    }

    // MARK: - Email Card

    private var emailCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.lavCyan.opacity(0.1))
                    .frame(width: 38, height: 38)

                Image(systemName: "envelope.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.lavCyan)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Email")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(authVM.currentUser?.email ?? "Not set")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lavTextSecondary)
            }

            Spacer()

            if authVM.currentUser?.emailVerified == true {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("Verified")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.lavEmerald)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.lavEmerald.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lavSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button { [authVM] in
            dismiss()
            Task { @MainActor in authVM.logout() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13))
                Text("Sign Out")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.lavRed.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.lavRed.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.lavRed.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(CardPressStyle())
        .padding(.bottom, 8)
    }
}
