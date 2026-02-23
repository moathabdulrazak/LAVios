import SwiftUI

struct BalanceRevealView: View {
    let oldBalance: Double
    let newBalance: Double
    let isWin: Bool
    let onDismiss: () -> Void

    @State private var phase: RevealPhase = .blackout
    @State private var orbScale: CGFloat = 0
    @State private var orbOpacity: Double = 0
    @State private var pulseRing1: CGFloat = 0.5
    @State private var pulseRing2: CGFloat = 0.3
    @State private var displayedBalance: Double = 0
    @State private var shakeAmount: CGFloat = 0
    @State private var sparkParticles: [SparkParticle] = []
    @State private var backdropOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var diffPillOpacity: Double = 0
    @State private var canDismiss = false

    private var diff: Double { newBalance - oldBalance }
    private var accentColor: Color { isWin ? .lavEmerald : .lavRed }

    private enum RevealPhase {
        case blackout, charge, detonate, counting, impact, hold, exit
    }

    var body: some View {
        ZStack {
            // Dark backdrop
            Color.black.opacity(backdropOpacity)
                .ignoresSafeArea()

            // Pulse rings
            Circle()
                .stroke(accentColor.opacity(0.15), lineWidth: 2)
                .frame(width: 200, height: 200)
                .scaleEffect(pulseRing1)
                .opacity(phase == .charge || phase == .detonate ? 0.8 : 0)

            Circle()
                .stroke(accentColor.opacity(0.1), lineWidth: 1.5)
                .frame(width: 200, height: 200)
                .scaleEffect(pulseRing2)
                .opacity(phase == .charge || phase == .detonate ? 0.6 : 0)

            // Center orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentColor, accentColor.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(orbScale)
                .opacity(orbOpacity)
                .blur(radius: 20)

            // Spark particles
            ForEach(sparkParticles.indices, id: \.self) { i in
                Circle()
                    .fill(sparkParticles[i].color)
                    .frame(width: sparkParticles[i].size, height: sparkParticles[i].size)
                    .offset(x: sparkParticles[i].x, y: sparkParticles[i].y)
                    .opacity(sparkParticles[i].opacity)
            }

            // Content
            VStack(spacing: 16) {
                Text(isWin ? "VICTORY" : "DEFEAT")
                    .font(.system(size: 12, weight: .black))
                    .tracking(4)
                    .foregroundColor(accentColor.opacity(0.7))
                    .opacity(contentOpacity)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.4f", displayedBalance))
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: displayedBalance))
                    Text("SOL")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.lavTextMuted)
                }
                .opacity(contentOpacity)
                .modifier(ShakeEffect(animatableData: shakeAmount))

                // Diff pill
                HStack(spacing: 4) {
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(String(format: "%@%.4f SOL", diff >= 0 ? "+" : "", diff))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundColor(accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(accentColor.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(accentColor.opacity(0.2), lineWidth: 1))
                .opacity(diffPillOpacity)
            }

            // Tap to dismiss hint
            if canDismiss {
                VStack {
                    Spacer()
                    Text("Tap to continue")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.lavTextMuted)
                        .padding(.bottom, 60)
                }
                .transition(.opacity)
            }
        }
        .onTapGesture {
            guard canDismiss else { return }
            onDismiss()
        }
        .onAppear { startSequence() }
    }

    // MARK: - Animation Sequence

    private func startSequence() {
        displayedBalance = oldBalance

        // Phase 1: Blackout (350ms)
        withAnimation(.easeIn(duration: 0.35)) {
            backdropOpacity = 0.92
        }

        // Phase 2: Charge (starts at 350ms, 600ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            phase = .charge
            withAnimation(.easeOut(duration: 0.6)) {
                orbScale = 0.6
                orbOpacity = 0.8
            }
            withAnimation(.easeOut(duration: 0.8)) {
                pulseRing1 = 1.5
                pulseRing2 = 2.0
            }
        }

        // Phase 3: Detonate (starts at 950ms, 400ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            phase = .detonate
            withAnimation(.easeOut(duration: 0.4)) {
                orbScale = 2.5
                orbOpacity = 0.3
                contentOpacity = 1.0
            }
        }

        // Phase 4: Counting (starts at 1350ms, 1400ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            phase = .counting
            animateBalance(from: oldBalance, to: newBalance, duration: 1.4)
        }

        // Phase 5: Impact (starts at 2750ms, 600ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.75) {
            phase = .impact
            spawnSparks()
            withAnimation(.easeOut(duration: 0.1)) {
                shakeAmount = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                    shakeAmount = 0
                }
            }
        }

        // Phase 6: Hold (starts at 3350ms, 1400ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.35) {
            phase = .hold
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                diffPillOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5)) {
                orbScale = 0.8
                orbOpacity = 0.15
            }
        }

        // Phase 7: Enable dismiss (starts at 4750ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.75) {
            phase = .exit
            withAnimation(.easeIn(duration: 0.3)) {
                canDismiss = true
            }
        }
    }

    private func animateBalance(from start: Double, to end: Double, duration: Double) {
        let steps = 40
        for i in 0...steps {
            let fraction = Double(i) / Double(steps)
            // Ease-out cubic
            let eased = 1 - pow(1 - fraction, 3)
            let value = start + (end - start) * eased
            let delay = duration * fraction

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                displayedBalance = value
            }
        }
    }

    private func spawnSparks() {
        sparkParticles = (0..<20).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 30...120)
            return SparkParticle(
                x: cos(angle) * distance,
                y: sin(angle) * distance,
                size: CGFloat.random(in: 2...5),
                color: [Color.lavEmerald, .lavCyan, .white, .lavYellow].randomElement()!,
                opacity: 1.0
            )
        }

        // Fade out sparks
        withAnimation(.easeOut(duration: 0.8)) {
            sparkParticles = sparkParticles.map {
                var p = $0
                p.opacity = 0
                return p
            }
        }
    }
}

private struct SparkParticle {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}
