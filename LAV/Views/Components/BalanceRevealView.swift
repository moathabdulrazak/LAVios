import SwiftUI

struct BalanceRevealView: View {
    let oldBalance: Double
    let newBalance: Double
    let isWin: Bool
    let onDismiss: () -> Void

    @State private var phase = 0
    @State private var backdropOpacity: Double = 0
    @State private var orbScale: CGFloat = 0.15
    @State private var orbOpacity: Double = 0
    @State private var orbBlur: CGFloat = 2
    @State private var pulseRing1Scale: CGFloat = 1
    @State private var pulseRing1Op: Double = 0
    @State private var pulseRing2Scale: CGFloat = 1
    @State private var pulseRing2Op: Double = 0
    @State private var detonateRingScale: CGFloat = 1
    @State private var detonateRingOp: Double = 0
    @State private var contentScale: CGFloat = 2.5
    @State private var contentOpacity: Double = 0
    @State private var displayedBalance: Double = 0
    @State private var numberGlow: Double = 0
    @State private var shakeOffset: CGSize = .zero
    @State private var shockwave1Scale: CGFloat = 1
    @State private var shockwave1Op: Double = 0
    @State private var shockwave2Scale: CGFloat = 1
    @State private var shockwave2Op: Double = 0
    @State private var shockwave3Scale: CGFloat = 1
    @State private var shockwave3Op: Double = 0
    @State private var sparkParticles: [RevealSpark] = []
    @State private var diffPillScale: CGFloat = 0.8
    @State private var diffPillY: CGFloat = 20
    @State private var diffPillOp: Double = 0
    @State private var beamOpacity: Double = 0
    @State private var canDismiss = false
    @State private var tapHintOp: Double = 0
    @State private var impactFired = false

    private var diff: Double { newBalance - oldBalance }
    private var accent: Color { isWin ? .lavEmerald : .lavRed }
    private var secondary: Color { isWin ? Color(hex: "34d399") : Color(hex: "f87171") }

    var body: some View {
        ZStack {
            // Dark backdrop with blur
            Color.black.opacity(backdropOpacity)
                .ignoresSafeArea()

            // Spotlight beams (detonate onward)
            if phase >= 2 {
                ZStack {
                    ForEach([-18.0, 0.0, 18.0], id: \.self) { angle in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.08), accent.opacity(0.02), .clear],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 140, height: UIScreen.main.bounds.height * 1.2)
                            .blur(radius: 15)
                            .rotationEffect(.degrees(angle))
                    }
                }
                .opacity(beamOpacity)
            }

            // Pulse rings during charge
            if phase >= 1 && phase <= 2 {
                Circle()
                    .stroke(accent.opacity(0.6), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseRing1Scale)
                    .opacity(pulseRing1Op)
                Circle()
                    .stroke(accent.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseRing2Scale)
                    .opacity(pulseRing2Op)
            }

            // Detonate ring
            Circle()
                .stroke(accent, lineWidth: max(3 - detonateRingScale * 0.25, 1))
                .frame(width: 60, height: 60)
                .scaleEffect(detonateRingScale)
                .opacity(detonateRingOp)

            // Center orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.5), accent.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(orbScale)
                .opacity(orbOpacity)
                .blur(radius: orbBlur)

            // Shockwave rings (impact)
            Circle()
                .stroke(accent, lineWidth: max(2 - shockwave1Scale * 0.15, 0.5))
                .frame(width: 50, height: 50)
                .scaleEffect(shockwave1Scale)
                .opacity(shockwave1Op)
            Circle()
                .stroke(secondary, lineWidth: max(2 - shockwave2Scale * 0.15, 0.5))
                .frame(width: 50, height: 50)
                .scaleEffect(shockwave2Scale)
                .opacity(shockwave2Op)
            Circle()
                .stroke(accent.opacity(0.7), lineWidth: max(2 - shockwave3Scale * 0.15, 0.5))
                .frame(width: 50, height: 50)
                .scaleEffect(shockwave3Scale)
                .opacity(shockwave3Op)

            // Spark particles (impact)
            ForEach(sparkParticles.indices, id: \.self) { i in
                Circle()
                    .fill(sparkParticles[i].color)
                    .frame(width: sparkParticles[i].size, height: sparkParticles[i].size)
                    .offset(x: sparkParticles[i].x, y: sparkParticles[i].y)
                    .opacity(sparkParticles[i].opacity)
            }

            // Main content
            VStack(spacing: 18) {
                Text(isWin ? "VICTORY" : "DEFEAT")
                    .font(.system(size: 14, weight: .black))
                    .tracking(6)
                    .foregroundColor(accent)

                // Balance number with glow
                ZStack {
                    // Glow behind number
                    Text(String(format: "%.4f", displayedBalance))
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(accent)
                        .blur(radius: 30)
                        .opacity(numberGlow * 0.5)
                        .scaleEffect(1.5)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.4f", displayedBalance))
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .shadow(color: accent.opacity(0.6), radius: 30)
                            .shadow(color: accent.opacity(0.3), radius: 60)
                        Text("SOL")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.lavTextMuted)
                    }
                }

                // Diff pill
                HStack(spacing: 5) {
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text(String(format: "%@%.4f SOL", diff >= 0 ? "+" : "", diff))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundColor(accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(accent.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(accent.opacity(0.25), lineWidth: 1.5))
                .scaleEffect(diffPillScale)
                .offset(y: diffPillY)
                .opacity(diffPillOp)
            }
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
            .offset(x: shakeOffset.width, y: shakeOffset.height)

            // Tap to dismiss
            VStack {
                Spacer()
                Text("Tap to continue")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lavTextMuted)
                    .padding(.bottom, 60)
                    .opacity(tapHintOp)
            }
        }
        .onTapGesture {
            guard canDismiss else { return }
            onDismiss()
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: impactFired)
        .onAppear { runSequence() }
    }

    // MARK: - Animation Sequence

    private func runSequence() {
        displayedBalance = oldBalance

        // Phase 0: Blackout (0 → 350ms)
        withAnimation(.easeOut(duration: 0.4)) {
            backdropOpacity = 0.93
        }
        withAnimation(.easeOut(duration: 0.35)) {
            orbScale = 1.0
            orbOpacity = 1.0
        }

        // Phase 1: Charge (350ms → 600ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            phase = 1
            // Pulse ring 1
            pulseRing1Op = 0.7
            withAnimation(.easeOut(duration: 0.5)) {
                pulseRing1Scale = 4
                pulseRing1Op = 0
            }
            // Pulse ring 2 (staggered)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                pulseRing2Op = 0.5
                withAnimation(.easeOut(duration: 0.5)) {
                    pulseRing2Scale = 4
                    pulseRing2Op = 0
                }
            }
        }

        // Phase 2: Detonate (600ms → 1000ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            phase = 2

            // Orb explodes outward
            withAnimation(.easeOut(duration: 0.4)) {
                orbScale = 12
                orbOpacity = 0
                orbBlur = 20
            }

            // Content scales in dramatically
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)) {
                contentScale = 1.0
                contentOpacity = 1.0
            }

            // Detonate ring expands
            detonateRingOp = 1
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.6)) {
                detonateRingScale = 11
                detonateRingOp = 0
            }

            // Spotlight beams appear
            withAnimation(.easeOut(duration: 0.4)) {
                beamOpacity = 1
            }
        }

        // Phase 3: Counting (1000ms → 2400ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            phase = 3
            numberGlow = 1
            animateBalance(from: oldBalance, to: newBalance, duration: 1.4)
        }

        // Phase 4: Impact (2400ms → 3000ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            phase = 4
            impactFired = true
            runImpact()
        }

        // Phase 5: Hold (3000ms → 4400ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            phase = 5

            // Diff pill bounces in
            withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.6)) {
                diffPillScale = 1.0
                diffPillY = 0
                diffPillOp = 1.0
            }

            // Settle beams and glow
            withAnimation(.easeOut(duration: 0.5)) {
                beamOpacity = 0.2
                numberGlow = 0.4
            }

            // Tap hint
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.5)) {
                    tapHintOp = 0.35
                }
            }
        }

        // Phase 6: Enable dismiss (4400ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
            phase = 6
            canDismiss = true
        }
    }

    // MARK: - Balance Counter

    private func animateBalance(from start: Double, to end: Double, duration: Double) {
        let steps = 50
        for i in 0...steps {
            let fraction = Double(i) / Double(steps)
            // Exponential ease-out matching web: 1 - 2^(-10 * progress)
            let eased = 1 - pow(2, -10 * fraction)
            let value = start + (end - start) * eased
            let delay = duration * fraction

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                displayedBalance = value
            }
        }
    }

    // MARK: - Impact

    private func runImpact() {
        // Screen shake with decay
        let shakeDuration = 0.5
        let shakeSteps = 25
        for i in 0...shakeSteps {
            let delay = shakeDuration * Double(i) / Double(shakeSteps)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let decay = 1 - (Double(i) / Double(shakeSteps))
                let intensity = 12 * decay
                shakeOffset = CGSize(
                    width: (Double.random(in: 0...1) - 0.5) * intensity,
                    height: (Double.random(in: 0...1) - 0.5) * intensity
                )
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration) {
            shakeOffset = .zero
        }

        // 3 staggered shockwave rings
        shockwave1Op = 0.7
        withAnimation(.easeOut(duration: 0.9)) {
            shockwave1Scale = 12
            shockwave1Op = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            shockwave2Op = 0.7
            withAnimation(.easeOut(duration: 0.9)) {
                shockwave2Scale = 12
                shockwave2Op = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            shockwave3Op = 0.7
            withAnimation(.easeOut(duration: 0.9)) {
                shockwave3Scale = 12
                shockwave3Op = 0
            }
        }

        // 28 spark particles burst
        spawnSparks()
    }

    private func spawnSparks() {
        sparkParticles = (0..<28).map { i in
            let baseAngle = (Double(i) / 28.0) * 360
            let angle = (baseAngle + Double.random(in: -15...15)) * .pi / 180
            let distance = CGFloat.random(in: 120...320)
            let useSecondary = i % 3 == 0
            return RevealSpark(
                x: cos(angle) * distance,
                y: sin(angle) * distance,
                size: CGFloat.random(in: 2...7),
                color: useSecondary ? secondary : accent,
                opacity: 1.0
            )
        }

        withAnimation(.easeOut(duration: 0.9)) {
            sparkParticles = sparkParticles.map {
                var p = $0
                p.opacity = 0
                return p
            }
        }
    }
}

private struct RevealSpark {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}
