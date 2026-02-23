import SwiftUI
import Observation

@Observable
final class FundsViewModel {
    var selectedTab: FundsTab = .loadUp
    var solPrice: Double = 0
    var isLoadingSolPrice = false

    // Withdraw state
    var destinationAddress = ""
    var withdrawAmount = ""
    var isWithdrawing = false
    var withdrawError: String?
    var withdrawSuccess = false
    var lastTxSignature: String?

    // Activity
    var withdrawals: [Withdrawal] = []
    var isLoadingWithdrawals = false

    // Copy state
    var copiedAddress = false

    private let gameService = GameService.shared

    enum FundsTab: String, CaseIterable {
        case loadUp = "Load Up"
        case cashOut = "Cash Out"
    }

    @MainActor
    func loadData() async {
        async let priceTask: () = loadSolPrice()
        async let withdrawalsTask: () = loadWithdrawals()
        _ = await (priceTask, withdrawalsTask)
    }

    @MainActor
    func loadSolPrice() async {
        isLoadingSolPrice = true
        do {
            solPrice = try await gameService.getSolPrice()
        } catch {
            print("[LAV Funds] Failed to load SOL price: \(error)")
        }
        isLoadingSolPrice = false
    }

    @MainActor
    func loadWithdrawals() async {
        isLoadingWithdrawals = true
        do {
            withdrawals = try await gameService.getWithdrawals()
        } catch {
            print("[LAV Funds] Failed to load withdrawals: \(error)")
        }
        isLoadingWithdrawals = false
    }

    @MainActor
    func submitWithdraw() async {
        guard !destinationAddress.isEmpty else {
            withdrawError = "Enter a destination address."
            return
        }
        guard let amount = Double(withdrawAmount), amount > 0 else {
            withdrawError = "Enter a valid amount."
            return
        }

        isWithdrawing = true
        withdrawError = nil
        withdrawSuccess = false

        do {
            let response = try await gameService.withdraw(
                destination: destinationAddress,
                amount: amount
            )
            if response.success == true {
                withdrawSuccess = true
                lastTxSignature = response.txSignature
                withdrawAmount = ""
                destinationAddress = ""
                await loadWithdrawals()
            } else {
                withdrawError = response.error ?? "Withdrawal failed."
            }
        } catch let error as APIError {
            withdrawError = error.errorDescription
        } catch {
            withdrawError = "Withdrawal failed. Try again."
        }

        isWithdrawing = false
    }

    func setPresetAmount(_ amount: Double, maxBalance: Double) {
        if amount >= maxBalance {
            withdrawAmount = String(format: "%.4f", maxBalance)
        } else {
            withdrawAmount = String(format: "%.1f", amount)
        }
    }

    func copyWalletAddress(_ address: String) {
        UIPasteboard.general.string = address
        copiedAddress = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.copiedAddress = false
        }
    }
}
