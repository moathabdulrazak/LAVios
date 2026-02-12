import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var showSplash = true
    @State private var splashFade: Double = 1
    @State private var showSignup = false

    // Splash animation states
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var textOffset: CGFloat = 30
    @State private var textOpacity: Double = 0
    @State private var tagOpacity: Double = 0
    @State private var flashOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0

    var body: some View {
        ZStack {
            Group {
                if authVM.isAuthenticated {
                    MainTabView()
                        .transition(.opacity)
                } else if !authVM.isCheckingSession {
                    if showSignup {
                        SignupView {
                            withAnimation(.easeInOut(duration: 0.3)) { showSignup = false }
                        }
                        .transition(.opacity)
                    } else {
                        LoginView(onSignUp: {
                            withAnimation(.easeInOut(duration: 0.3)) { showSignup = true }
                        })
                        .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: authVM.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authVM.isCheckingSession)

            if showSplash {
                splashScreen
                    .opacity(splashFade)
            }
        }
        .task { await runSplashSequence() }
    }

    // MARK: - Splash

    private var splashScreen: some View {
        ZStack {
            Color.lavBackground.ignoresSafeArea()

            // Neon flash overlay
            Color.lavEmerald.opacity(flashOpacity)
                .ignoresSafeArea()
                .blendMode(.screen)

            // Center glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.lavEmerald.opacity(0.4), Color.lavEmerald.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: glowRadius)
                .opacity(logoOpacity)

            // Expanding ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.lavEmerald.opacity(0.6), Color.lavCyan.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .frame(width: 120, height: 120)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            VStack(spacing: 24) {
                // Logo
                ZStack {
                    Image("LAVLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .lavEmerald.opacity(0.6), radius: 30)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // Title
                VStack(spacing: 8) {
                    Text("LAV")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .tracking(14)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.lavEmerald],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("PLAY  \u{2022}  WIN  \u{2022}  EARN")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(4)
                        .foregroundColor(.lavEmerald)
                        .opacity(tagOpacity)
                }
                .offset(y: textOffset)
                .opacity(textOpacity)
            }
        }
    }

    // MARK: - Sequence

    @MainActor
    private func runSplashSequence() async {
        Task { await authVM.checkSession() }
 
        // Beat 1: Logo punches in with flash
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.15)) {
            flashOpacity = 0.15
        }
        withAnimation(.easeOut(duration: 0.4)) {
            glowRadius = 40
        }

        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeOut(duration: 0.3)) { flashOpacity = 0 }

        // Beat 2: Ring bursts outward
        withAnimation(.easeOut(duration: 0.6)) {
            ringScale = 4.0
            ringOpacity = 0.8
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            ringOpacity = 0
        }

        // Beat 3: Text slides up
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            textOffset = 0
            textOpacity = 1.0
        }

        try? await Task.sleep(for: .milliseconds(180))
        withAnimation(.easeOut(duration: 0.25)) { tagOpacity = 1.0 }

        // Hold
        try? await Task.sleep(for: .milliseconds(700))

        // Exit
        withAnimation(.easeIn(duration: 0.25)) { splashFade = 0 }
        try? await Task.sleep(for: .milliseconds(300))
        showSplash = false
    }
}

#Preview("Login") {
    LoginView(onSignUp: {})
        .environment({
            let vm = AuthViewModel()
            vm.isCheckingSession = false
            return vm
        }())
        .preferredColorScheme(.dark)
}

#Preview("Main") {
    MainTabView()
        .environment({
            let vm = AuthViewModel()
            vm.isCheckingSession = false
            vm.isAuthenticated = true
            return vm
        }())
        .environment(GamesViewModel())
        .preferredColorScheme(.dark)
}
