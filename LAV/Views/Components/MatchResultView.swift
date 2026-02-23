import SwiftUI

struct MatchResultView: View {
    let result: MatchResult
    let game: GameInfo
    let onDismiss: () -> Void

    @State private var animate = false
    @State private var trophyPulse = false
    @State private var hapticFired = false
    @State private var payoutDisplay: Double = 0
    @State private var glowScale: CGFloat = 0.5
    @State private var confettiParticles: [ConfettiParticle] = []

    var body: some View {
        ZStack {
            // Background radial glow
            radialGlow
                .ignoresSafeArea()

            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {}

            // Confetti overlay for wins
            if case .win = result {
                confettiOverlay
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 24) {
                resultIcon
                    .scaleEffect(animate ? 1 : 0.5)
                    .opacity(animate ? 1 : 0)

                resultText
                    .offset(y: animate ? 0 : 20)
                    .opacity(animate ? 1 : 0)

                if case .win(let payout) = result {
                    animatedPayoutBadge(target: payout)
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
                        .buttonStyle(CardPressStyle())
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
        .sensoryFeedback(.success, trigger: hapticFired && result.isWin)
        .sensoryFeedback(.error, trigger: hapticFired && result.isLoss)
        .sensoryFeedback(.warning, trigger: hapticFired && result.isWaiting)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animate = true
            }
            hapticFired = true

            // Radial glow animation
            withAnimation(.easeOut(duration: 0.8)) {
                glowScale = 1.0
            }

            if case .win(let payout) = result {
                // Trophy pulse
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    trophyPulse = true
                }
                // Animated payout counter
                animatePayoutCounter(to: payout)
                // Spawn confetti
                spawnConfetti()
            }
        }
    }

    // MARK: - Radial Glow Background

    private var radialGlow: some View {
        let glowColor: Color = {
            switch result {
            case .win: return .lavYellow
            case .loss: return .lavRed
            case .waiting: return .lavPurple
            }
        }()

        return Circle()
            .fill(
                RadialGradient(
                    colors: [glowColor.opacity(0.25), glowColor.opacity(0.08), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 300
                )
            )
            .frame(width: 600, height: 600)
            .scaleEffect(glowScale)
            .blur(radius: 60)
    }

    // MARK: - Confetti

    private var confettiOverlay: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in confettiParticles {
                    let elapsed = now - particle.startTime
                    guard elapsed > 0 else { continue }
                    let t = elapsed / particle.duration
                    guard t <= 1.0 else { continue }

                    let x = particle.startX * size.width + sin(elapsed * particle.wobbleSpeed) * 20
                    let y = -20 + (size.height + 40) * t * particle.speedFactor
                    let rotation = Angle.degrees(elapsed * particle.rotationSpeed)
                    let opacity = t < 0.8 ? 1.0 : (1.0 - t) / 0.2

                    var ctx = context
                    ctx.opacity = opacity * 0.9
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: rotation)
                    ctx.fill(
                        Path(CGRect(x: -particle.size / 2, y: -particle.size / 2, width: particle.size, height: particle.size * 0.6)),
                        with: .color(particle.color)
                    )
                }
            }
        }
    }

    private func spawnConfetti() {
        let colors: [Color] = [.lavEmerald, .lavCyan, .lavYellow, .lavPurple, .lavPink, .white]
        let now = Date().timeIntervalSinceReferenceDate

        confettiParticles = (0..<40).map { i in
            ConfettiParticle(
                startX: Double.random(in: 0.05...0.95),
                startTime: now + Double(i) * 0.04,
                duration: Double.random(in: 2.5...4.0),
                speedFactor: Double.random(in: 0.7...1.3),
                wobbleSpeed: Double.random(in: 1.5...4.0),
                rotationSpeed: Double.random(in: 60...300),
                size: CGFloat.random(in: 6...12),
                color: colors[i % colors.count]
            )
        }
    }

    // MARK: - Animated Payout

    private func animatePayoutCounter(to target: Double) {
        let steps = 30
        let totalDuration = 1.4
        for i in 0...steps {
            let fraction = Double(i) / Double(steps)
            // Ease-out cubic
            let eased = 1 - pow(1 - fraction, 3)
            let value = target * eased
            let delay = totalDuration * fraction

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + delay) {
                payoutDisplay = value
            }
        }
    }

    private func animatedPayoutBadge(target: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.lavEmerald)
            Text(String(format: "%.4f SOL", payoutDisplay))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.lavEmerald)
                .contentTransition(.numericText(value: payoutDisplay))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.lavEmerald.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.lavEmerald.opacity(0.2), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.05), value: payoutDisplay)
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
                    .scaleEffect(trophyPulse ? 1.3 : 1)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.lavEmerald, .lavCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .lavEmerald.opacity(trophyPulse ? 0.8 : 0.2), radius: trophyPulse ? 20 : 8)
                    .scaleEffect(trophyPulse ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: trophyPulse)
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

    private var resultBorderColor: Color {
        switch result {
        case .win: return .lavEmerald
        case .loss: return .lavRed
        case .waiting: return .lavOrange
        }
    }
}

// MARK: - Confetti Particle

private struct ConfettiParticle {
    let startX: Double
    let startTime: TimeInterval
    let duration: Double
    let speedFactor: Double
    let wobbleSpeed: Double
    let rotationSpeed: Double
    let size: CGFloat
    let color: Color
}

extension MatchResult {
    var isWin: Bool {
        if case .win = self { return true }
        return false
    }
    var isLoss: Bool { self == .loss }
    var isWaiting: Bool { self == .waiting }
}
