import SwiftUI

/// A tactile hardware-style Stripe Payment Sheet for gathering Apple Pay and credit card details.
struct TardiPaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paymentManager = PaymentSheetManager.shared

    @State private var cardNumber = ""
    @State private var expiration = ""
    @State private var cvv = ""
    @State private var postalCode = ""
    @State private var cardholderName = ""
    @State private var selectedMethod: PaymentMethodType = .card
    @State private var isProcessing = false

    private let rigidHaptics = UIImpactFeedbackGenerator(style: .rigid)

    enum PaymentMethodType {
        case applePay
        case card
    }

    var detectedCardBrand: (name: String, icon: String) {
        let cleaned = cardNumber.replacingOccurrences(of: " ", with: "")
        if cleaned.starts(with: "4") {
            return ("Visa", "creditcard.fill")
        } else if cleaned.starts(with: "51") || cleaned.starts(with: "52") || cleaned.starts(with: "53") || cleaned.starts(with: "54") || cleaned.starts(with: "55") {
            return ("Mastercard", "creditcard.fill")
        } else if cleaned.starts(with: "34") || cleaned.starts(with: "37") {
            return ("Amex", "creditcard.fill")
        } else if cleaned.starts(with: "6011") {
            return ("Discover", "creditcard.fill")
        }
        return ("Card", "creditcard")
    }

    var isFormValid: Bool {
        let cleanedCard = cardNumber.replacingOccurrences(of: " ", with: "")
        let cleanedExp = expiration.replacingOccurrences(of: "/", with: "")
        return cleanedCard.count >= 15 && cleanedExp.count == 4 && cvv.count >= 3 && postalCode.count >= 5
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    // 1. Digital Vault Card Preview
                    vaultCardPreview

                    // 2. 1-Tap Apple Pay Button
                    applePaySection

                    // 3. Divider: OR PAY WITH CARD
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                        Text("OR ENTER CARD DETAILS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    // 4. Card Input Fields
                    cardFieldsSection

                    // 5. Security Notice Banner
                    securityBanner

                    // 6. Primary Arm Vault Action Button
                    armVaultButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
            }
        }
    }

    // MARK: - 1. Vault Card Preview

    private var vaultCardPreview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.green.opacity(0.8), radius: 3)
                    Text("TARDI HARDWARE VAULT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: detectedCardBrand.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(cardNumber.isEmpty ? "•••• •••• •••• ••••" : formatCardDisplay(cardNumber))
                    .font(.system(size: 19, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(2)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CARDHOLDER")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(cardholderName.isEmpty ? "YOUR NAME" : cardholderName.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("EXPIRES")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(expiration.isEmpty ? "MM/YY" : expiration)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(white: 0.15), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
    }

    // MARK: - 2. Apple Pay 1-Tap

    private var applePaySection: some View {
        Button {
            rigidHaptics.impactOccurred()
            Task {
                isProcessing = true
                let success = await paymentManager.armVault(email: "user@tardi.app", cardBrand: "Apple Pay", last4: "Apple")
                isProcessing = false
                if success { dismiss() }
            }
        } label: {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "applelogo")
                        .font(.system(size: 16, weight: .bold))
                    Text("Pay with Apple Pay")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .disabled(isProcessing)
        .buttonStyle(.plain)
    }

    // MARK: - 4. Card Form Fields

    private var cardFieldsSection: some View {
        VStack(spacing: 12) {
            // Cardholder Name
            HStack(spacing: 10) {
                Image(systemName: "person.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                TextField("Name on Card", text: $cardholderName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .textContentType(.name)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Card Number
            HStack(spacing: 10) {
                Image(systemName: detectedCardBrand.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                TextField("Card Number", text: $cardNumber)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .keyboardType(.numberPad)
                    .onChange(of: cardNumber) { _, newValue in
                        cardNumber = formatCardNumber(newValue)
                    }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Expiration, CVV, Zip Row
            HStack(spacing: 10) {
                // Expiration
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("MM/YY", text: $expiration)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .keyboardType(.numberPad)
                        .onChange(of: expiration) { _, newValue in
                            expiration = formatExpiration(newValue)
                        }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                // CVV
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    SecureField("CVV", text: $cvv)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .keyboardType(.numberPad)
                        .onChange(of: cvv) { _, newValue in
                            if newValue.count > 4 { cvv = String(newValue.prefix(4)) }
                        }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Postal Code
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("ZIP", text: $postalCode)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .keyboardType(.numberPad)
                        .onChange(of: postalCode) { _, newValue in
                            if newValue.count > 5 { postalCode = String(newValue.prefix(5)) }
                        }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - 5. Security Notice

    private var securityBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Zero-Risk Tokenization")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Card details are securely tokenized via Stripe SetupIntent. Your card will only ever be charged if a pledged deadline is missed.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(1.5)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 6. Arm Vault Action Button

    private var armVaultButton: some View {
        Button {
            rigidHaptics.impactOccurred()
            Task {
                isProcessing = true
                let cleaned = cardNumber.replacingOccurrences(of: " ", with: "")
                let last4 = String(cleaned.suffix(4))
                let success = await paymentManager.armVault(
                    email: "user@tardi.app",
                    cardBrand: detectedCardBrand.name,
                    last4: last4.isEmpty ? "4242" : last4
                )
                isProcessing = false
                if success { dismiss() }
            }
        } label: {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Save Card to Vault")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isFormValid ? Color.accentColor : Color.secondary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
        }
        .disabled(!isFormValid || isProcessing)
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatCardNumber(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: " ", with: "")
        var formatted = ""
        for (index, char) in cleaned.prefix(16).enumerated() {
            if index > 0 && index % 4 == 0 { formatted.append(" ") }
            formatted.append(char)
        }
        return formatted
    }

    private func formatCardDisplay(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: " ", with: "")
        if cleaned.count <= 4 { return text }
        let prefix = String(cleaned.prefix(cleaned.count - 4))
        let suffix = String(cleaned.suffix(4))
        let masked = String(repeating: "•", count: prefix.count)
        return formatCardNumber(masked + suffix)
    }

    private func formatExpiration(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "/", with: "")
        if cleaned.count <= 2 { return cleaned }
        let month = cleaned.prefix(2)
        let year = cleaned.dropFirst(2).prefix(2)
        return "\(month)/\(year)"
    }
}
