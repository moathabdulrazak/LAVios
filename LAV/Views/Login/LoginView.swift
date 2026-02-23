import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM
    var onSignUp: (() -> Void)? = nil
    @State private var step: LoginStep = .username
    @State private var showPassword = false
    @State private var appeared = false
    @State private var cardAppeared = false
    @State private var borderRotation: Double = 0
    @State private var logoFloat: CGFloat = 0
    @State private var shimmerPhase: CGFloat = -1
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var pulseRing: Bool = false
    @State private var glowBreath: Bool = false
    @State private var shakeCount: Int = 0
    @FocusState private var focusedField: LoginField?

    enum LoginStep { case username, password }
    enum LoginField: Hashable { case identifier, password }

    private let accent = Color.lavEmerald

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            logoSection
                .padding(.bottom, 36)

            mainCard

            Spacer().frame(height: 36)

            footerSection

            Spacer().frame(height: 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.lavBackground
                backgroundLayers
            }
            .ignoresSafeArea()
        }
        .onTapGesture { focusedField = nil }
        .sensoryFeedback(.selection, trigger: step)
        .sensoryFeedback(.error, trigger: shakeCount)
        .onChange(of: authVM.errorMessage) { _, newVal in
            if newVal != nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    shakeCount += 1
                }
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Logo

    private var logoSection: some View {
        ZStack {
            // Large breathing glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(glowBreath ? 0.25 : 0.1), accent.opacity(0.03), .clear],
                        center: .center, startRadius: 0, endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .blur(radius: 40)

            // Second pulse ring (outer)
            Circle()
                .stroke(accent.opacity(0.04), lineWidth: 1)
                .frame(width: 160, height: 160)
                .scaleEffect(pulseRing ? 1.5 : 1)
                .opacity(pulseRing ? 0 : 0.4)

            // First pulse ring
            Circle()
                .stroke(accent.opacity(0.06), lineWidth: 1)
                .frame(width: 140, height: 140)
                .scaleEffect(pulseRing ? 1.3 : 0.9)
                .opacity(pulseRing ? 0 : 0.5)

            // Rotating gradient ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [accent.opacity(0.4), .clear, accent.opacity(0.2), .clear, accent.opacity(0.4)],
                        center: .center,
                        angle: .degrees(borderRotation)
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 112, height: 112)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            // Static inner ring
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .frame(width: 98, height: 98)

            // Logo
            Image("LAVLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: accent.opacity(0.35), radius: 28)
                .shadow(color: accent.opacity(0.15), radius: 50)
        }
        .offset(y: logoFloat)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -24)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.05), value: appeared)
    }

    // MARK: - Form Content

    private var mainCard: some View {
        VStack(spacing: 0) {
            ZStack {
                if step == .username {
                    usernameStep
                        .transition(.asymmetric(
                            insertion: .offset(x: -30).combined(with: .opacity),
                            removal: .offset(x: -30).combined(with: .opacity)
                        ))
                } else {
                    passwordStep
                        .transition(.asymmetric(
                            insertion: .offset(x: 30).combined(with: .opacity),
                            removal: .offset(x: 30).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: step)

            stepIndicator
                .padding(.top, 32)
        }
        .frame(maxWidth: .infinity)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 30)
        .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.15), value: cardAppeared)
    }

    // MARK: - Step 1: Username

    private var usernameStep: some View {
        @Bindable var authVM = authVM
        let ready = !authVM.identifier.isEmpty

        return VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sign in")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Enter your username to continue")
                    .font(.system(size: 15))
                    .foregroundColor(.lavTextSecondary)
            }

            // Field
            VStack(alignment: .leading, spacing: 10) {
                Text("USERNAME OR EMAIL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(focusedField == .identifier ? accent : .lavTextMuted)
                    .animation(.easeOut(duration: 0.2), value: focusedField)

                HStack(spacing: 14) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(focusedField == .identifier ? accent : .lavTextMuted)
                        .frame(width: 22)
                        .scaleEffect(focusedField == .identifier ? 1.1 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: focusedField)

                    TextField("", text: $authVM.identifier, prompt: Text("Username").foregroundColor(.lavTextMuted.opacity(0.4)))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .tint(accent)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .identifier)
                        .submitLabel(.next)
                        .onSubmit { goToPassword() }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(focusedField == .identifier ? 0.08 : 0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            focusedField == .identifier ? accent.opacity(0.5) : Color.white.opacity(0.06),
                            lineWidth: focusedField == .identifier ? 1.5 : 1
                        )
                )
                .shadow(color: focusedField == .identifier ? accent.opacity(0.1) : .clear, radius: 16, y: 6)
                .animation(.easeOut(duration: 0.25), value: focusedField)
                .sensoryFeedback(.selection, trigger: focusedField == .identifier)
            }

            if let error = authVM.errorMessage {
                errorBanner(error)
            }

            // Continue button
            Button { goToPassword() } label: {
                HStack(spacing: 10) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .offset(x: ready ? 0 : -4)
                        .opacity(ready ? 1 : 0)
                }
                .foregroundColor(ready ? .black : .white.opacity(0.15))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    ZStack {
                        if ready {
                            accent
                            // Shimmer on ready button
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.12), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .offset(x: shimmerPhase * 200)
                        } else {
                            Color.white.opacity(0.03)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ready ? .clear : Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: ready ? accent.opacity(0.3) : .clear, radius: 16, y: 6)
            }
            .buttonStyle(BouncyPress())
            .disabled(!ready)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: ready)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if step == .username { focusedField = .identifier }
            }
        }
    }

    // MARK: - Step 2: Password

    private var passwordStep: some View {
        @Bindable var authVM = authVM
        let valid = authVM.isFormValid && !authVM.isLoading && !authVM.isLockedOut

        return VStack(alignment: .leading, spacing: 24) {
            // Back
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    step = .username
                    authVM.errorMessage = nil
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.lavTextSecondary)
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                HStack(spacing: 0) {
                    Text(authVM.identifier)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(accent)
                        .lineLimit(1)
                }
            }

            // Field
            VStack(alignment: .leading, spacing: 10) {
                Text("PASSWORD")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(focusedField == .password ? accent : .lavTextMuted)
                    .animation(.easeOut(duration: 0.2), value: focusedField)

                HStack(spacing: 14) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(focusedField == .password ? accent : .lavTextMuted)
                        .frame(width: 22)
                        .scaleEffect(focusedField == .password ? 1.1 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: focusedField)

                    Group {
                        if showPassword {
                            TextField("", text: $authVM.password, prompt: Text("Enter password").foregroundColor(.lavTextMuted.opacity(0.4)))
                        } else {
                            SecureField("", text: $authVM.password, prompt: Text("Enter password").foregroundColor(.lavTextMuted.opacity(0.4)))
                        }
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .tint(accent)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { [authVM] in Task { await authVM.login() } }

                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(showPassword ? accent : .lavTextMuted)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .sensoryFeedback(.selection, trigger: showPassword)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(focusedField == .password ? 0.08 : 0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            focusedField == .password ? accent.opacity(0.5) : Color.white.opacity(0.06),
                            lineWidth: focusedField == .password ? 1.5 : 1
                        )
                )
                .shadow(color: focusedField == .password ? accent.opacity(0.1) : .clear, radius: 16, y: 6)
                .animation(.easeOut(duration: 0.25), value: focusedField)
                .sensoryFeedback(.selection, trigger: focusedField == .password)
            }

            if let error = authVM.errorMessage {
                errorBanner(error)
            }

            // Sign In button
            Button { [authVM] in
                focusedField = nil
                Task { await authVM.login() }
            } label: {
                ZStack {
                    if authVM.isLoading {
                        ProgressView().tint(.black)
                    } else if authVM.isLockedOut {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill").font(.system(size: 13))
                            Text(authVM.lockoutDisplay).monospacedDigit()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    } else {
                        HStack(spacing: 10) {
                            Text("Sign In")
                                .font(.system(size: 17, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(valid ? .black : .white.opacity(0.15))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    ZStack {
                        if valid {
                            LinearGradient(
                                colors: [accent, Color.lavEmeraldDark],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.15), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .offset(x: shimmerPhase * 200)
                        } else {
                            Color.white.opacity(0.03)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(valid ? .clear : Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: valid ? accent.opacity(0.35) : .clear, radius: 18, y: 6)
            }
            .buttonStyle(BouncyPress())
            .disabled(authVM.isLoading || authVM.isLockedOut || !authVM.isFormValid)
            .sensoryFeedback(.impact(weight: .heavy), trigger: authVM.isAuthenticated)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: valid)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusedField = .password
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(step == .username ? accent : Color.white.opacity(0.08))
                .frame(width: step == .username ? 28 : 8, height: 5)

            RoundedRectangle(cornerRadius: 3)
                .fill(step == .password ? accent : Color.white.opacity(0.08))
                .frame(width: step == .password ? 28 : 8, height: 5)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step)
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
            Text(error)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(.lavRed)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lavRed.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.lavRed.opacity(0.1), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .shake(trigger: shakeCount)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 16) {
            Button {
                onSignUp?()
            } label: {
                HStack(spacing: 6) {
                    Text("New to LAV?")
                        .foregroundColor(.lavTextSecondary)
                    Text("Create Account")
                        .foregroundColor(accent)
                        .fontWeight(.bold)
                }
                .font(.system(size: 15))
            }

            HStack(spacing: 24) {
                Link("Terms", destination: URL(string: "https://lav.bot/terms")!)
                Link("Privacy", destination: URL(string: "https://lav.bot/privacy")!)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color.white.opacity(0.12))
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.35), value: appeared)
    }

    // MARK: - Navigation

    private func goToPassword() {
        guard !authVM.identifier.isEmpty else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            step = .password
        }
    }

    // MARK: - Background

    private var backgroundLayers: some View {
        ZStack {
            // Large top emerald
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(glowBreath ? 0.15 : 0.08), accent.opacity(0.02), .clear],
                        center: .center, startRadius: 0, endRadius: 300
                    )
                )
                .frame(width: 600, height: 500)
                .offset(x: -40, y: -320)
                .blur(radius: 100)

            // Right side cyan tint
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.lavCyan.opacity(0.04), .clear],
                        center: .center, startRadius: 0, endRadius: 120
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: 140, y: -100)
                .blur(radius: 70)

            // Bottom purple
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.lavPurple.opacity(0.06), .clear],
                        center: .center, startRadius: 0, endRadius: 160
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 60, y: 350)
                .blur(radius: 80)

            // Subtle floating particles
            particleField
        }
        .allowsHitTesting(false)
    }

    private var particleField: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let dots: [(x: Double, y: Double, r: Double, s: Double, a: Double)] = [
                    (0.1, 0.12, 1.4, 0.6, 0.06), (0.88, 0.08, 1.8, 0.5, 0.05),
                    (0.35, 0.55, 1.0, 0.8, 0.04), (0.92, 0.42, 1.6, 0.55, 0.06),
                    (0.05, 0.38, 0.8, 0.7, 0.03), (0.7, 0.22, 1.2, 0.45, 0.05),
                    (0.52, 0.06, 1.5, 0.5, 0.04), (0.2, 0.7, 1.0, 0.65, 0.03),
                ]
                for d in dots {
                    let fy = sin(t * d.s + d.x * 10) * 10
                    let fx = cos(t * d.s * 0.7 + d.y * 8) * 7
                    let pulse = 0.5 + 0.5 * sin(t * d.s * 1.3 + d.r)
                    let x = d.x * size.width + fx
                    let y = d.y * size.height + fy
                    let r = d.r * (0.7 + 0.5 * pulse)
                    let alpha = d.a * (0.4 + 0.6 * pulse)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        withAnimation(.easeOut(duration: 0.65).delay(0.1)) { cardAppeared = true }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.5).delay(0.25)) {
            ringScale = 1
            ringOpacity = 1
        }
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { logoFloat = -6 }
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { borderRotation = 360 }
        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) { shimmerPhase = 1 }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glowBreath = true }
        withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) { pulseRing = true }
    }
}

// MARK: - Button Style

private struct BouncyPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environment({
            let vm = AuthViewModel()
            vm.isCheckingSession = false
            return vm
        }())
        .preferredColorScheme(.dark)
}
