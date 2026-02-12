import SwiftUI

struct EarningsPanel: View {
    let earnings: EarningsStats?
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Your Earnings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.lavTextMuted)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(20)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            if let earnings {
                ScrollView {
                    VStack(spacing: 12) {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            statCard(
                                title: "Total Earned",
                                value: String(format: "%.4f SOL", earnings.totalEarnings ?? 0),
                                icon: "dollarsign.circle.fill",
                                color: .lavEmerald
                            )
                            statCard(
                                title: "Games Played",
                                value: "\(earnings.totalGames ?? 0)",
                                icon: "gamecontroller.fill",
                                color: .lavPurple
                            )
                            statCard(
                                title: "Win Rate",
                                value: String(format: "%.1f%%", (earnings.winRate ?? 0) * 100),
                                icon: "chart.line.uptrend.xyaxis",
                                color: .lavCyan
                            )
                            statCard(
                                title: "Tier",
                                value: earnings.tier?.capitalized ?? "Bronze",
                                icon: "star.fill",
                                color: .lavOrange
                            )
                        }
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.lavEmerald)
                    Text("Loading stats...")
                        .font(.caption)
                        .foregroundColor(.lavTextMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "0f1014").opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 30)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.lavTextMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}
