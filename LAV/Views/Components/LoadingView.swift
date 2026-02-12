import SwiftUI

struct LoadingView: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.lavBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    // Glow
                    Circle()
                        .fill(Color.lavEmerald.opacity(0.1))
                        .frame(width: 100, height: 100)
                        .blur(radius: 30)

                    // Spinning ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.lavEmerald, .lavCyan, .lavEmerald.opacity(0)],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(rotation))

                    // Logo
                    Text("L")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.lavEmerald, .lavCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
