import SwiftUI
import CoreImage.CIFilterBuiltins

struct FundsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GamesViewModel.self) private var gamesVM
    @Environment(\.dismiss) private var dismiss
    @State private var vm = FundsViewModel()
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.lavBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .staggerIn(appeared: appeared, delay: 0)

                balanceSummary
                    .staggerIn(appeared: appeared, delay: 0.06)

                tabPicker
                    .staggerIn(appeared: appeared, delay: 0.10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if vm.selectedTab == .loadUp {
                            loadUpContent
                                .staggerIn(appeared: appeared, delay: 0.14)
                        } else {
                            cashOutContent
                                .staggerIn(appeared: appeared, delay: 0.14)
                        }

                        if !vm.withdrawals.isEmpty {
                            activitySection
                                .staggerIn(appeared: appeared, delay: 0.20)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.loadData() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.lavSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
            }

            Spacer()

            Text("Funds")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Balance Summary

    private var balanceSummary: some View {
        VStack(spacing: 8) {
            Text("AVAILABLE BALANCE")
                .font(.system(size: 9, weight: .black))
                .tracking(2)
                .foregroundColor(.lavTextMuted)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.4f", gamesVM.walletBalance))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text("SOL")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.lavTextMuted)
            }

            if vm.solPrice > 0 {
                Text(String(format: "$%.2f USD", gamesVM.walletBalance * vm.solPrice))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lavTextSecondary)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(FundsViewModel.FundsTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(vm.selectedTab == tab ? .black : .lavTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            vm.selectedTab == tab
                                ? Capsule().fill(Color.lavEmerald)
                                : Capsule().fill(Color.lavSurface)
                        )
                }
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.lavSurface))
        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Load Up

    private var loadUpContent: some View {
        VStack(spacing: 20) {
            let walletAddress = authVM.currentUser?.walletAddress ?? ""

            // QR Code
            if !walletAddress.isEmpty, let qrImage = generateQRCode(from: walletAddress) {
                VStack(spacing: 16) {
                    Text("Scan to deposit SOL")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.lavTextSecondary)

                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .premiumCard(cornerRadius: 22)
                .padding(.horizontal, 20)
            }

            // Wallet address
            VStack(spacing: 12) {
                Text("YOUR WALLET ADDRESS")
                    .font(.system(size: 9, weight: .black))
                    .tracking(2)
                    .foregroundColor(.lavTextMuted)

                Text(walletAddress.isEmpty ? "Not available" : walletAddress)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.lavTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Button {
                    vm.copyWalletAddress(walletAddress)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: vm.copiedAddress ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .bold))
                        Text(vm.copiedAddress ? "Copied!" : "Copy Address")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(vm.copiedAddress ? .lavEmerald : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(vm.copiedAddress ? Color.lavEmerald.opacity(0.1) : Color.lavSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(vm.copiedAddress ? Color.lavEmerald.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(CardPressStyle())
                .sensoryFeedback(.selection, trigger: vm.copiedAddress)
                .animation(.easeInOut(duration: 0.2), value: vm.copiedAddress)
            }
            .padding(20)
            .premiumCard(cornerRadius: 22)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Cash Out

    private var cashOutContent: some View {
        VStack(spacing: 16) {
            // Destination address
            VStack(alignment: .leading, spacing: 8) {
                Text("DESTINATION ADDRESS")
                    .font(.system(size: 9, weight: .black))
                    .tracking(2)
                    .foregroundColor(.lavTextMuted)

                TextField("Solana wallet address", text: Binding(
                    get: { vm.destinationAddress },
                    set: { vm.destinationAddress = $0 }
                ))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lavSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            // Amount input
            VStack(alignment: .leading, spacing: 8) {
                Text("AMOUNT (SOL)")
                    .font(.system(size: 9, weight: .black))
                    .tracking(2)
                    .foregroundColor(.lavTextMuted)

                TextField("0.0", text: Binding(
                    get: { vm.withdrawAmount },
                    set: { vm.withdrawAmount = $0 }
                ))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .keyboardType(.decimalPad)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lavSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )

                // Preset buttons
                HStack(spacing: 8) {
                    ForEach([0.1, 0.5, 1.0, 2.0], id: \.self) { amount in
                        presetButton(amount)
                    }
                    presetMaxButton
                }
            }

            // Error
            if let error = vm.withdrawError {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lavRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Success
            if vm.withdrawSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.lavEmerald)
                    Text("Withdrawal submitted!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.lavEmerald)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Submit button
            Button {
                Task { await vm.submitWithdraw() }
            } label: {
                HStack(spacing: 8) {
                    if vm.isWithdrawing {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(0.8)
                    }
                    Text(vm.isWithdrawing ? "Processing..." : "Withdraw")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.lavEmerald)
                )
                .shadow(color: .lavEmerald.opacity(0.3), radius: 12, y: 4)
            }
            .buttonStyle(CardPressStyle())
            .disabled(vm.isWithdrawing)
            .opacity(vm.isWithdrawing ? 0.7 : 1)
            .padding(.top, 4)
        }
        .padding(20)
        .premiumCard(cornerRadius: 22)
        .padding(.horizontal, 20)
    }

    private func presetButton(_ amount: Double) -> some View {
        Button {
            vm.setPresetAmount(amount, maxBalance: gamesVM.walletBalance)
        } label: {
            Text("\(amount, specifier: amount == floor(amount) ? "%.0f" : "%.1f")")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.lavTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.lavSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
        }
    }

    private var presetMaxButton: some View {
        Button {
            vm.setPresetAmount(.infinity, maxBalance: gamesVM.walletBalance)
        } label: {
            Text("Max")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.lavEmerald)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.lavEmerald.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.lavEmerald.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Activity

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RECENT ACTIVITY")
                .font(.system(size: 10, weight: .black))
                .tracking(2)
                .foregroundColor(.lavTextMuted)
                .padding(.horizontal, 4)

            VStack(spacing: 2) {
                ForEach(vm.withdrawals.prefix(10)) { w in
                    withdrawalRow(w)
                }
            }
        }
        .padding(20)
        .premiumCard(cornerRadius: 22)
        .padding(.horizontal, 20)
    }

    private func withdrawalRow(_ w: Withdrawal) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(w.status).opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: statusIcon(w.status))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(statusColor(w.status))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Withdrawal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(shortAddress(w.destination))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.lavTextMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "-%.4f", w.amount ?? 0))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.lavRed)

                statusBadge(w.status)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func statusBadge(_ status: String?) -> some View {
        let label = (status ?? "pending").capitalized
        let color = statusColor(status)

        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "completed", "success": return .lavEmerald
        case "pending", "processing": return .lavOrange
        case "failed": return .lavRed
        default: return .lavTextMuted
        }
    }

    private func statusIcon(_ status: String?) -> String {
        switch status?.lowercased() {
        case "completed", "success": return "checkmark"
        case "pending", "processing": return "clock"
        case "failed": return "xmark"
        default: return "arrow.up.right"
        }
    }

    private func shortAddress(_ addr: String?) -> String {
        guard let addr, addr.count > 10 else { return addr ?? "" }
        return String(addr.prefix(6)) + "..." + String(addr.suffix(4))
    }

    // MARK: - QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scale = 200.0 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
