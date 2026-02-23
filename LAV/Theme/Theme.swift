import SwiftUI

// MARK: - LAV Color Theme

extension Color {
    // Backgrounds - true black for OLED punch
    static let lavBackground = Color(hex: "050507")
    static let lavSurface = Color(hex: "0a0b10")
    static let lavSurfaceLight = Color(hex: "111219")

    // Legacy aliases
    static let lavCardBackground = Color(hex: "0a0b10")
    static let lavCardBorder = Color(hex: "1a1b23")
    static let lavInputBackground = Color(hex: "0e0f15")

    // Neon accent colors - cranked up for max pop
    static let lavEmerald = Color(hex: "00ff88")
    static let lavEmeraldDark = Color(hex: "00cc6a")
    static let lavPurple = Color(hex: "bf5af2")
    static let lavOrange = Color(hex: "ff6b2c")
    static let lavCyan = Color(hex: "00e5ff")
    static let lavRed = Color(hex: "ff3b5c")
    static let lavYellow = Color(hex: "ffd60a")
    static let lavPink = Color(hex: "ff2d87")

    // Text hierarchy
    static let lavTextPrimary = Color.white
    static let lavTextSecondary = Color(hex: "8b8fa3")
    static let lavTextMuted = Color(hex: "4a4d63")

    // Gradients
    static let lavGradientStart = Color(hex: "00ff88")
    static let lavGradientEnd = Color(hex: "00cc6a")

    // Game-specific - all neon
    static let lavSnakeGreen = Color(hex: "00ff88")
    static let lavRocketOrange = Color(hex: "ff6b2c")
    static let lavDriveBlue = Color(hex: "4d8bff")
    static let lavWarpPurple = Color(hex: "bf5af2")
    static let lavDropCyan = Color(hex: "00e5ff")
    static let lavBountyYellow = Color(hex: "ffd60a")
}

// MARK: - Hex Color Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradient Presets

extension LinearGradient {
    static let lavEmeraldGradient = LinearGradient(
        colors: [Color.lavEmerald, Color.lavEmeraldDark],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let lavCardGradient = LinearGradient(
        colors: [Color.lavCardBackground, Color.lavCardBackground.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Stagger Animation

struct StaggerIn: ViewModifier {
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 28)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.78).delay(delay),
                value: appeared
            )
    }
}

// MARK: - Shimmer

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.06),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.06),
                        .clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: phase * 400)
                .mask(content)
                .onAppear {
                    withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            )
    }
}

// MARK: - Animated Border

struct AnimatedBorderModifier: ViewModifier {
    let colors: [Color]
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.clear, lineWidth: 0)
                    .overlay(
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: colors + [colors.first ?? .clear],
                                    center: .center
                                )
                            )
                            .scaleEffect(2.5)
                            .rotationEffect(.degrees(rotation))
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(lineWidth: lineWidth)
                    )
                    .onAppear {
                        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            )
    }
}

// MARK: - View Extensions

extension View {
    func staggerIn(appeared: Bool, delay: Double = 0) -> some View {
        modifier(StaggerIn(appeared: appeared, delay: delay))
    }

    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }

    func animatedBorder(
        colors: [Color] = [.lavEmerald, .lavCyan, .lavPurple, .lavPink],
        cornerRadius: CGFloat = 20,
        lineWidth: CGFloat = 1.5
    ) -> some View {
        modifier(AnimatedBorderModifier(colors: colors, cornerRadius: cornerRadius, lineWidth: lineWidth))
    }

    func surfaceCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.lavSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
    }

    func premiumCard(cornerRadius: CGFloat = 24) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.lavSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
    }

    func glassCard(
        cornerRadius: CGFloat = 16,
        borderColor: Color = .lavCardBorder,
        borderWidth: CGFloat = 1
    ) -> some View {
        self
            .background(Color.lavCardBackground.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor.opacity(0.3), lineWidth: borderWidth)
            )
    }

    func glow(_ color: Color, radius: CGFloat = 20) -> some View {
        self
            .shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
    }
}

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0
        ))
    }
}

extension View {
    func shake(trigger: Int) -> some View {
        self.modifier(ShakeEffect(animatableData: CGFloat(trigger)))
    }
}

// MARK: - Button Styles

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
