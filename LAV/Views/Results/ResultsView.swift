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

                    if !gamesVM.earningsHistory.isEmpty {
                        gameHistoryList
                            .staggerIn(appeared: appeared, delay: 0.12)
                    } else {
                        emptyState
                            .staggerIn(appeared: appeared, delay: 0.12)
                    }

                    Spacer(minLength: 120)
                }
            }
            .refreshable { await gamesVM.loadEarnings() }
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

    // MARK: - Game History List

    private var gameHistoryList: some View {
        VStack(spacing: 2) {
            ForEach(gamesVM.earningsHistory) { game in
                gameRow(game)
            }
        }
        .padding(16)
        .premiumCard(cornerRadius: 22)
        .padding(.horizontal, 20)
    }

    private func gameRow(_ game: EarningsGame) -> some View {
        let isWin = game.result == "win"
        let amount = game.amount ?? 0

        return HStack(spacing: 12) {
            // Result icon
            Circle()
                .fill((isWin ? Color.lavEmerald : Color.lavRed).opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: isWin ? "checkmark" : "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isWin ? .lavEmerald : .lavRed)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(gameDisplayName(game.gameType ?? ""))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Text(isWin ? "Won" : "Lost")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isWin ? .lavEmerald : .lavRed)

                    if let entry = game.entryAmount, entry > 0 {
                        Text(String(format: "%.2f SOL entry", entry))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.lavTextMuted)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%@%.4f", amount >= 0 ? "+" : "", amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(amount >= 0 ? .lavEmerald : .lavRed)

                Text(relativeTime(game.createdAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.lavTextMuted)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func gameDisplayName(_ type: String) -> String {
        switch type {
        case "drivehard": return "Drive Hard"
        case "solsnake": return "SolSnake"
        case "rocketsol": return "Rocket Sol"
        case "warp": return "Warp"
        case "dropfusion": return "Drop Fusion"
        case "bountyboard": return "Bounty Board"
        default: return type.capitalized
        }
    }

    private func relativeTime(_ dateStr: String?) -> String {
        guard let dateStr else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
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
        }
        .frame(maxWidth: .infinity)
    }
}
