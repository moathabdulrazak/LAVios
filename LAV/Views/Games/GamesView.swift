import SwiftUI

struct GamesView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GamesViewModel.self) private var gamesVM
    @State private var navigateToGame: GameInfo?
    @State private var appeared = false
    @State private var glowPulse = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lavBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                            .staggerIn(appeared: appeared, delay: 0)

                        gamesGrid

                        Spacer(minLength: 120)
                    }
                }
                .refreshable {
                    await gamesVM.loadEarnings()
                    await gamesVM.loadWalletBalance(walletAddress: authVM.currentUser?.walletAddress, userId: authVM.currentUser?.id)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $navigateToGame) { game in
                GameDetailView(game: game)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glowPulse = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Play & Earn")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                Text("Choose your game. Stack your SOL.")
                    .font(.system(size: 13))
                    .foregroundColor(.lavTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: - Grid

    private var gamesGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(gamesVM.games.enumerated()), id: \.element.id) { index, game in
                GameCard(game: game, glowPulse: glowPulse) {
                    navigateToGame = game
                }
                .staggerIn(appeared: appeared, delay: 0.04 + Double(index) * 0.04)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Game Card

struct GameCard: View {
    let game: GameInfo
    let glowPulse: Bool
    let onTap: () -> Void

    private var lowestEntry: String {
        guard let first = game.entryTiers.first else { return "" }
        return first.amount < 0.01 ? "FREE" : "\(first.formattedAmount)"
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                // Background
                cardBackground

                // Watermark icon - bottom right, big
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: game.icon)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(game.accentColor.opacity(0.08))
                            .rotationEffect(.degrees(-12))
                            .offset(x: 8, y: 8)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 0) {
                    // Mode badge
                    modeBadge

                    Spacer()

                    // Game name
                    Text(game.name)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer().frame(height: 4)

                    // Description
                    Text(game.description)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 10)

                    // Entry price
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                        Text(lowestEntry)
                            .font(.system(size: 10, weight: .black))
                            .tracking(0.5)
                    }
                    .foregroundColor(game.accentColor)
                }
                .padding(14)
            }
            .frame(height: 172)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(CardPressStyle())
    }

    private var modeBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(game.accentColor)
                .frame(width: 4, height: 4)
                .shadow(color: game.accentColor, radius: 2)
            Text(game.gameType == .solsnake ? "MULTI" : "1v1")
                .font(.system(size: 8, weight: .black))
                .tracking(1)
        }
        .foregroundColor(game.accentColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(game.accentColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var cardBackground: some View {
        ZStack {
            // Base
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.lavSurface)

            // Accent gradient wash
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            game.accentColor.opacity(0.14),
                            game.accentColor.opacity(0.04),
                            .clear,
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )

            // Top accent edge
            VStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [game.accentColor.opacity(0.25), game.accentColor.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 2.5)
                Spacer()
            }

            // Border
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [game.accentColor.opacity(0.2), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: game.accentColor.opacity(glowPulse ? 0.12 : 0.04), radius: 16, y: 4)
    }
}

#Preview {
    GamesView()
        .environment({
            let vm = AuthViewModel()
            vm.isCheckingSession = false
            vm.isAuthenticated = true
            return vm
        }())
        .environment(GamesViewModel())
        .preferredColorScheme(.dark)
}
