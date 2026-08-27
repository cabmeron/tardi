import SwiftUI
import Combine

/// Manages the state and tokenization lifecycle of the user's payment vault
@MainActor
final class PaymentSheetManager: ObservableObject {
    static let shared = PaymentSheetManager()

    static let publishableKey = "pk_test_51U70crFqnsvKjM8mrYGWGwvuz1lDThA9R7dQPyPYfiFb4sqoz86FH2uPgqivUsuA9MZVU7OxqPqRQPrfoHghfpqa00LxKf0K8l"

    @Published var isVaultArmed: Bool = false
    @Published var cardBrand: String = "Visa"
    @Published var cardLast4: String = "4242"
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String? = nil

    private let backend = BackendClient.shared
    private let haptics = UINotificationFeedbackGenerator()

    var cardSummary: String {
        if isVaultArmed {
            return "\(cardBrand) •••• \(cardLast4)"
        } else {
            return "No Card on File"
        }
    }

    /// Arms the vault by requesting a SetupIntent from the Go backend
    func armVault(email: String = "user@tardi.app", cardBrand: String = "Visa", last4: String = "4242") async -> Bool {
        isProcessing = true
        errorMessage = nil

        do {
            // 1. Call Go backend to generate SetupIntent
            let (clientSecret, customerId) = try await backend.createSetupIntent(email: email)
            print("💳 SetupIntent generated from Go backend: \(clientSecret) for customer \(customerId)")

            // 2. Mark vault as armed
            self.isVaultArmed = true
            self.cardBrand = cardBrand
            self.cardLast4 = last4
            self.isProcessing = false
            self.haptics.notificationOccurred(.success)
            return true
        } catch {
            self.isProcessing = false
            self.errorMessage = "Failed to arm vault: \(error.localizedDescription)"
            self.haptics.notificationOccurred(.error)
            return false
        }
    }

    /// Disarms the vault
    func disarmVault() {
        self.isVaultArmed = false
        self.cardLast4 = ""
        self.haptics.notificationOccurred(.warning)
    }
}
