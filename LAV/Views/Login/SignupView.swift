import SwiftUI

struct SignupView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var vm = SignupViewModel()
    @State private var appeared = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showPrivateKey = false
    @State private var showSaveConfirm = false
    @State private var logoFloat: CGFloat = 0
    @State private var glowBreath = false
    @State private var shimmerPhase: CGFloat = -1
    @FocusState private var focusedField: Field?

    let onBackToLogin: () -> Void

    enum Field: Hashable {
        case email, username, password, confirmPassword
    }

    private let accent = Color.lavEmerald

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    logoSection
                        .padding(.bottom, 32)

                    stepProgress
                        .padding(.bottom, 32)

                    stepContent
                        .id("stepContent")

                    Spacer().frame(height: 32)

                    footerSection

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
            .onChange(of: vm.step) { _, _ in
                withAnimation { proxy.scrollTo("stepContent", anchor: .top) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.lavBackground
                backgroundGlow
            }
            .ignoresSafeArea()
        }
        .onTapGesture { focusedField = nil }
        .onAppear { startAnimations() }
        .onDisappear { vm.cleanup() }
    }

    // MARK: - Logo

    private var logoSection: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(glowBreath ? 0.2 : 0.08), .clear],
                        center: .center, startRadius: 0, endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .blur(radius: 30)

            Image("LAVLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: accent.opacity(0.3), radius: 20)
        }
        .offset(y: logoFloat)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.05), value: appeared)
    }

    // MARK: - Step Progress

    private var stepProgress: some View {
        let steps: [(id: Int, title: String)] = [
            (1, "Email"), (2, "Profile"), (3, "Wallet"), (4, "Verify"), (5, "Done")
        ]

        return HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, s in
                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(vm.step.rawValue >= s.id ? accent : Color.white.opacity(0.05))
                                .frame(width: 32, height: 32)

                            if vm.step.rawValue > s.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                            } else {
                                Text("\(s.id)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(vm.step.rawValue >= s.id ? .black : .lavTextMuted)
                            }
                        }
                        .shadow(color: vm.step.rawValue == s.id ? accent.opacity(0.3) : .clear, radius: 8)

                        Text(s.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(vm.step.rawValue >= s.id ? accent : .lavTextMuted)
                    }

                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(vm.step.rawValue > s.id ? accent : Color.white.opacity(0.06))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 4)
                            .offset(y: -10)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .animation(.easeOut(duration: 0.3), value: vm.step)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case .email: emailStep
        case .profile: profileStep
        case .wallet: walletStep
        case .verify: verifyStep
        case .done: doneStep
        }
    }

    // MARK: - Step 1: Email

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Create your account")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Enter your email to get started")
                    .font(.system(size: 15))
                    .foregroundColor(.lavTextSecondary)
            }

            inputField(
                icon: "envelope.fill",
                placeholder: "Email address",
                text: Binding(get: { vm.email }, set: { vm.email = $0; vm.emailChanged() }),
                field: .email,
                keyboard: .emailAddress,
                status: emailStatus
            )

            if let error = vm.errorMessage {
                errorBanner(error)
            }

            actionButton(
                title: "Continue",
                enabled: vm.isEmailStepValid && !vm.isLoading,
                loading: vm.isLoading
            ) {
                Task { await vm.continueWithEmail() }
            }
        }
        .transition(.asymmetric(insertion: .offset(x: -30).combined(with: .opacity), removal: .offset(x: -30).combined(with: .opacity)))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focusedField = .email }
        }
    }

    // MARK: - Step 2: Profile

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Create your profile")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Choose a username and password")
                    .font(.system(size: 15))
                    .foregroundColor(.lavTextSecondary)
            }

            // Username
            inputField(
                icon: "at",
                placeholder: "Username",
                text: Binding(get: { vm.username }, set: { vm.username = $0.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }; vm.usernameChanged() }),
                field: .username,
                status: usernameStatus
            )

            // Password
            VStack(alignment: .leading, spacing: 10) {
                passwordField(
                    icon: "lock.fill",
                    placeholder: "Password",
                    text: Binding(get: { vm.password }, set: { vm.password = $0 }),
                    show: $showPassword,
                    field: .password
                )

                if !vm.password.isEmpty {
                    passwordRequirements
                }
            }

            // Confirm
            passwordField(
                icon: "lock.fill",
                placeholder: "Confirm password",
                text: Binding(get: { vm.confirmPassword }, set: { vm.confirmPassword = $0 }),
                show: $showConfirmPassword,
                field: .confirmPassword
            )

            if !vm.confirmPassword.isEmpty && !vm.passwordsMatch {
                Text("Passwords do not match")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lavRed)
                    .padding(.top, -12)
            }

            // TOS
            tosCheckbox

            if let error = vm.errorMessage {
                errorBanner(error)
            }

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        vm.step = .email
                        vm.errorMessage = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.lavTextSecondary)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(BouncyPress())

                actionButton(
                    title: "Create Account",
                    enabled: vm.isProfileStepValid && !vm.isLoading,
                    loading: vm.isLoading,
                    loadingText: "Creating..."
                ) {
                    Task { await vm.createAccount() }
                }
            }
        }
        .transition(.asymmetric(insertion: .offset(x: 30).combined(with: .opacity), removal: .offset(x: -30).combined(with: .opacity)))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focusedField = .username }
        }
    }

    // MARK: - Step 3: Wallet

    private var walletStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Warning
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.lavRed)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Save Your Private Key")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.lavRed)
                    Text("This is the only time you'll see it")
                        .font(.system(size: 13))
                        .foregroundColor(.lavRed.opacity(0.7))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.lavRed.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.lavRed.opacity(0.15), lineWidth: 1)
            )

            // Private key card
            VStack(alignment: .leading, spacing: 12) {
                Text("PRIVATE KEY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.lavTextMuted)

                ZStack {
                    Text(vm.walletPrivateKey ?? "")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(showPrivateKey ? .white : .clear)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .blur(radius: showPrivateKey ? 0 : 8)

                    if !showPrivateKey {
                        Button {
                            showPrivateKey = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 14))
                                Text("Reveal")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                // Copy button
                Button {
                    vm.copyPrivateKey()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: vm.privateKeyCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .medium))
                        Text(vm.privateKeyCopied ? "Copied!" : "Copy Key")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(vm.privateKeyCopied ? .black : .white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(vm.privateKeyCopied ? accent : Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(vm.privateKeyCopied ? .clear : Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(BouncyPress())
                .sensoryFeedback(.success, trigger: vm.privateKeyCopied)
                .animation(.easeOut(duration: 0.2), value: vm.privateKeyCopied)

                // Wallet address
                if let addr = vm.walletPublicKey {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WALLET ADDRESS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.lavTextMuted)
                        Text(addr)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.lavTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.top, 4)
                }
            }

            // Continue
            actionButton(
                title: "I Saved My Key",
                icon: "checkmark.shield.fill",
                enabled: true,
                loading: false
            ) {
                showSaveConfirm = true
            }
        }
        .transition(.asymmetric(insertion: .offset(x: 30).combined(with: .opacity), removal: .offset(x: -30).combined(with: .opacity)))
        .alert("Did you save your key?", isPresented: $showSaveConfirm) {
            Button("Go Back", role: .cancel) { }
            Button("Yes, Continue") {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    vm.continueToVerify()
                }
            }
        } message: {
            Text("This key will never be shown again. Losing it means losing your wallet forever.")
        }
    }

    // MARK: - Step 4: Verify Email

    private var verifyStep: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                if vm.emailVerified {
                    Circle()
                        .fill(accent)
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.black)
                } else {
                    Circle()
                        .stroke(accent.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(glowBreath ? 360 : 0))
                        .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: glowBreath)

                    Circle()
                        .fill(accent.opacity(0.1))
                        .frame(width: 64, height: 64)

                    Image(systemName: "envelope.fill")
                        .font(.system(size: 28))
                        .foregroundColor(accent)
                }
            }

            VStack(spacing: 6) {
                Text(vm.emailVerified ? "Email Verified!" : "Verify Your Email")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                Text(vm.emailVerified ? "Redirecting..." : "We sent a link to \(vm.email)")
                    .font(.system(size: 14))
                    .foregroundColor(.lavTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if !vm.emailVerified {
                // Waiting dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(accent)
                            .frame(width: 6, height: 6)
                            .offset(y: glowBreath ? -4 : 4)
                            .animation(
                                .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15),
                                value: glowBreath
                            )
                    }
                    Text("Waiting for verification...")
                        .font(.system(size: 13))
                        .foregroundColor(.lavTextMuted)
                }

                // Resend
                VStack(spacing: 8) {
                    Text("Didn't get the email?")
                        .font(.system(size: 13))
                        .foregroundColor(.lavTextMuted)

                    Button {
                        Task { await vm.resendEmail() }
                    } label: {
                        Text(vm.resendCooldown > 0 ? "Resend in \(vm.resendCooldown)s" : "Resend Email")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(vm.resendCooldown > 0 ? .lavTextMuted : accent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(accent.opacity(vm.resendCooldown > 0 ? 0.03 : 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(vm.resendCooldown > 0)

                    Text("Check your spam folder too")
                        .font(.system(size: 11))
                        .foregroundColor(.lavTextMuted.opacity(0.5))
                }
            }

            if let error = vm.errorMessage {
                errorBanner(error)
            }
        }
        .multilineTextAlignment(.center)
        .transition(.asymmetric(insertion: .offset(x: 30).combined(with: .opacity), removal: .offset(x: -30).combined(with: .opacity)))
    }

    // MARK: - Step 5: Done

    private var doneStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(accent)
                    .frame(width: 80, height: 80)
                    .shadow(color: accent.opacity(0.4), radius: 20)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
            }

            VStack(spacing: 6) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Welcome to LAV, \(vm.username)")
                    .font(.system(size: 15))
                    .foregroundColor(.lavTextSecondary)
            }

            // Status cards
            HStack(spacing: 8) {
                statusCard(icon: "person.fill", label: "Account")
                statusCard(icon: "wallet.pass.fill", label: "Wallet")
                statusCard(icon: "envelope.fill", label: "Email")
            }

            // What's next
            VStack(alignment: .leading, spacing: 10) {
                Text("WHAT'S NEXT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.lavTextMuted)

                nextStepRow(num: "1", text: "Deposit SOL to your game wallet")
                nextStepRow(num: "2", text: "Play games and earn rewards")
                nextStepRow(num: "3", text: "Withdraw winnings anytime")
            }

            // Start Playing
            actionButton(
                title: "Start Playing",
                icon: "gamecontroller.fill",
                enabled: true,
                loading: false
            ) {
                // Refresh auth and go to main
                Task { await authVM.checkSession() }
            }
        }
        .multilineTextAlignment(.center)
        .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
    }

    // MARK: - Shared Components

    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default,
        status: FieldStatus = .none
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(focusedField == field ? accent : .lavTextMuted)
                    .frame(width: 22)
                    .animation(.easeOut(duration: 0.2), value: focusedField)

                TextField("", text: text, prompt: Text(placeholder).foregroundColor(.lavTextMuted.opacity(0.4)))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .tint(accent)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(keyboard)
                    .focused($focusedField, equals: field)

                statusIndicator(status)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(focusedField == field ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        focusedField == field ? accent.opacity(0.5) : Color.white.opacity(0.06),
                        lineWidth: focusedField == field ? 1.5 : 1
                    )
            )
            .shadow(color: focusedField == field ? accent.opacity(0.1) : .clear, radius: 16, y: 6)
            .animation(.easeOut(duration: 0.25), value: focusedField)
            .sensoryFeedback(.selection, trigger: focusedField == field)
        }
    }

    private func passwordField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        show: Binding<Bool>,
        field: Field
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(focusedField == field ? accent : .lavTextMuted)
                .frame(width: 22)
                .animation(.easeOut(duration: 0.2), value: focusedField)

            Group {
                if show.wrappedValue {
                    TextField("", text: text, prompt: Text(placeholder).foregroundColor(.lavTextMuted.opacity(0.4)))
                } else {
                    SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.lavTextMuted.opacity(0.4)))
                }
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.white)
            .tint(accent)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: field)

            Button { show.wrappedValue.toggle() } label: {
                Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(show.wrappedValue ? accent : .lavTextMuted)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(focusedField == field ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    focusedField == field ? accent.opacity(0.5) : Color.white.opacity(0.06),
                    lineWidth: focusedField == field ? 1.5 : 1
                )
        )
        .shadow(color: focusedField == field ? accent.opacity(0.1) : .clear, radius: 16, y: 6)
        .animation(.easeOut(duration: 0.25), value: focusedField)
    }

    private var passwordRequirements: some View {
        let checks: [(Bool, String)] = [
            (vm.passwordValidation.minLength, "8+ characters"),
            (vm.passwordValidation.hasUpper, "Uppercase (A-Z)"),
            (vm.passwordValidation.hasLower, "Lowercase (a-z)"),
            (vm.passwordValidation.hasNumber, "Number (0-9)"),
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(Array(checks.enumerated()), id: \.offset) { _, check in
                HStack(spacing: 6) {
                    Image(systemName: check.0 ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                        .foregroundColor(check.0 ? accent : .lavTextMuted)
                    Text(check.1)
                        .font(.system(size: 12))
                        .foregroundColor(check.0 ? accent : .lavTextMuted)
                    Spacer()
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: vm.passwordValidation.minLength)
        .animation(.easeOut(duration: 0.15), value: vm.passwordValidation.hasUpper)
        .animation(.easeOut(duration: 0.15), value: vm.passwordValidation.hasLower)
        .animation(.easeOut(duration: 0.15), value: vm.passwordValidation.hasNumber)
    }

    private var tosCheckbox: some View {
        Button {
            vm.tosAccepted.toggle()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(vm.tosAccepted ? accent : Color.white.opacity(0.04))
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(vm.tosAccepted ? accent : Color.white.opacity(0.15), lineWidth: 1.5)
                        )

                    if vm.tosAccepted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: vm.tosAccepted)

                Text("I agree to the **Terms of Service** and **Privacy Policy**")
                    .font(.system(size: 14))
                    .foregroundColor(.lavTextSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .sensoryFeedback(.selection, trigger: vm.tosAccepted)
    }

    private func actionButton(
        title: String,
        icon: String? = nil,
        enabled: Bool,
        loading: Bool,
        loadingText: String = "Loading...",
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if loading {
                    ProgressView().tint(.black)
                    Text(loadingText)
                        .font(.system(size: 17, weight: .bold))
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .bold))
                    }
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .opacity(enabled ? 1 : 0)
                }
            }
            .foregroundColor(enabled ? .black : .white.opacity(0.15))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                ZStack {
                    if enabled {
                        accent
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
                    .stroke(enabled ? .clear : Color.white.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: enabled ? accent.opacity(0.3) : .clear, radius: 16, y: 6)
        }
        .buttonStyle(BouncyPress())
        .disabled(!enabled || loading)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: enabled)
    }

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
    }

    private func statusCard(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(accent)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.15), lineWidth: 1)
        )
    }

    private func nextStepRow(num: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(num)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.1))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.lavTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Status

    enum FieldStatus {
        case none, checking, available, taken
    }

    private var emailStatus: FieldStatus {
        if vm.checkingEmail { return .checking }
        if let a = vm.emailAvailable { return a ? .available : .taken }
        return .none
    }

    private var usernameStatus: FieldStatus {
        if vm.checkingUsername { return .checking }
        if let a = vm.usernameAvailable { return a ? .available : .taken }
        return .none
    }

    @ViewBuilder
    private func statusIndicator(_ status: FieldStatus) -> some View {
        switch status {
        case .none: EmptyView()
        case .checking:
            ProgressView()
                .scaleEffect(0.7)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(accent)
        case .taken:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.lavRed)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 14) {
            Button {
                onBackToLogin()
            } label: {
                HStack(spacing: 6) {
                    Text("Already have an account?")
                        .foregroundColor(.lavTextSecondary)
                    Text("Sign In")
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
        .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)
    }

    // MARK: - Background

    private var backgroundGlow: some View {
        ZStack {
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
        }
        .allowsHitTesting(false)
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { logoFloat = -5 }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glowBreath = true }
        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) { shimmerPhase = 1 }
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
