import SwiftUI

struct MatchResultView: View {
    let result: MatchResult
    let game: GameInfo
    let onDismiss: () -> Void

    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 24) {
                resultIcon
                    .scaleEffect(animate ? 1 : 0.5)
                    .opacity(animate ? 1 : 0)

                resultText
                    .offset(y: animate ? 0 : 20)
                    .opacity(animate ? 1 : 0)

                if case .win(let payout) = result {
                    payoutBadge(amount: payout)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)
                }

                VStack(spacing: 12) {
                    if result != .waiting {
                        Button {
                            onDismiss()
                        } label: {
                            Text("Play Again")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    LinearGradient(
                                        colors: [game.accentColor, game.accentColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: game.accentColor.opacity(0.3), radius: 12, y: 4)
                        }
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Text(result == .waiting ? "Close" : "Back to Games")
                            .font(.subheadline)
                            .foregroundColor(.lavTextMuted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .padding(.top, 8)
            }
            .padding(32)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "0f1014").opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(resultBorderColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: resultBorderColor.opacity(0.15), radius: 30)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }

    // MARK: - Result Components

    @ViewBuilder
    private var resultIcon: some View {
        switch result {
        case .win:
            ZStack {
                Circle()
                    .fill(Color.lavEmerald.opacity(0.12))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.lavEmerald, .lavCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

        case .loss:
            ZStack {
                Circle()
                    .fill(Color.lavRed.opacity(0.12))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.lavRed)
            }

        case .waiting:
            ZStack {
                Circle()
                    .fill(Color.lavOrange.opacity(0.12))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: "clock.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.lavOrange)
            }
        }
    }

    @ViewBuilder
    private var resultText: some View {
        switch result {
        case .win:
            VStack(spacing: 6) {
                Text("Victory!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.lavEmerald)
                Text("You outplayed your opponent")
                    .font(.subheadline)
                    .foregroundColor(.lavTextMuted)
            }
        case .loss:
            VStack(spacing: 6) {
                Text("Defeat")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.lavRed)
                Text("Better luck next time")
                    .font(.subheadline)
                    .foregroundColor(.lavTextMuted)
            }
        case .waiting:
            VStack(spacing: 6) {
                Text("Waiting")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.lavOrange)
                Text("Your opponent hasn't played yet")
                    .font(.subheadline)
                    .foregroundColor(.lavTextMuted)
            }
        }
    }

    private func payoutBadge(amount: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.lavEmerald)
            Text(String(format: "%.4f SOL", amount))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.lavEmerald)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.lavEmerald.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.lavEmerald.opacity(0.2), lineWidth: 1)
        )
    }

    private var resultBorderColor: Color {
        switch result {
        case .win: return .lavEmerald
        case .loss: return .lavRed
        case .waiting: return .lavOrange
        }
    }
}
