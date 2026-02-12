import SwiftUI

struct ResultsView: View {
    @Environment(GamesViewModel.self) private var gamesVM
    @State private var appeared = false
    @State private var floatOffset: CGFloat = 0
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            Color.lavBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                        .staggerIn(appeared: appeared, delay: 0)

                    if let earnings = gamesVM.earnings {
                        quickStatsBar(earnings)
                            .staggerIn(appeared: appeared, delay: 0.06)
                    }

                    emptyState
                        .staggerIn(appeared: appeared, delay: 0.12)

                    Spacer(minLength: 120)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { floatOffset = -8 }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glowPulse = true }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Results")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                Text("Your match history")
                    .font(.system(size: 13))
                    .foregroundColor(.lavTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Quick Stats

    private func quickStatsBar(_ e: EarningsStats) -> some View {
        HStack(spacing: 0) {
            quickStat(value: "\(e.wins ?? 0)", label: "Wins", color: .lavEmerald)
            Spacer()
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 28)
            Spacer()
            quickStat(value: "\(e.losses ?? 0)", label: "Losses", color: .lavRed)
            Spacer()
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 28)
            Spacer()
            quickStat(value: String(format: "%.0f%%", e.winRate ?? 0), label: "Rate", color: .lavCyan)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .premiumCard(cornerRadius: 18)
        .padding(.horizontal, 20)
    }

    private func quickStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
                .shadow(color: color.opacity(0.3), radius: 3)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.lavTextMuted)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 30)

            ZStack {
                Circle()
                    .fill(Color.lavCyan.opacity(glowPulse ? 0.08 : 0.02))
                    .frame(width: 130, height: 130)
                    .blur(radius: 30)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.lavCyan.opacity(0.6), .lavPurple.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .lavCyan.opacity(0.4), radius: 10)
                    .offset(y: floatOffset)
            }

            VStack(spacing: 8) {
                Text("No match history yet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("Your completed matches will appear here.\nJoin a game to get started!")
                    .font(.system(size: 13))
                    .foregroundColor(.lavTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            comingSoonBadge
        }
        .frame(maxWidth: .infinity)
    }

    private var comingSoonBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.lavCyan)
                .frame(width: 5, height: 5)
                .shadow(color: .lavCyan.opacity(glowPulse ? 0.8 : 0.2), radius: 3)
            Text("COMING SOON")
                .font(.system(size: 10, weight: .black))
                .tracking(2)
        }
        .foregroundColor(.lavCyan)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.lavCyan.opacity(0.06))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.lavCyan.opacity(glowPulse ? 0.25 : 0.08), lineWidth: 1))
        .shadow(color: .lavCyan.opacity(glowPulse ? 0.15 : 0), radius: 8)
    }
}
