import SwiftUI

/// A tactile hardware-style card presenter for the Stripe PaymentSheet and Vault status.
struct StripeVaultCardPresenter: View {
    @StateObject private var paymentManager = PaymentSheetManager.shared
    @State private var showingPaymentSheet = false
    var onVaultArmed: (() -> Void)? = nil

    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Telemetry & Status LED
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(paymentManager.isVaultArmed ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: (paymentManager.isVaultArmed ? Color.green : Color.orange).opacity(0.8), radius: 3)

                    Text(paymentManager.isVaultArmed ? "VAULT ARMED" : "VAULT DISARMED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(paymentManager.isVaultArmed ? Color.green : Color.orange)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11))
                    Text("STRIPE ENCRYPTED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }

            Divider()

            if paymentManager.isVaultArmed {
                // Armed Vault State
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(paymentManager.cardSummary)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)

                            Text("Ready for habit stakes · Charged only on missed deadlines")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Button {
                            rigidHaptic.impactOccurred()
                            showingPaymentSheet = true
                        } label: {
                            Text("Update Card")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            rigidHaptic.impactOccurred()
                            paymentManager.disarmVault()
                        } label: {
                            Text("Disarm")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            } else {
                // Disarmed State: Call to Action Button
                VStack(alignment: .leading, spacing: 10) {
                    Text("Link Apple Pay or a credit card to activate financial accountability on your habit contracts.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)

                    Button {
                        rigidHaptic.impactOccurred()
                        showingPaymentSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Arm Vault with Apple Pay / Card")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = paymentManager.errorMessage {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(paymentManager.isVaultArmed ? Color.green.opacity(0.3) : Color(.separator).opacity(0.4), lineWidth: 1)
        )
        .sheet(isPresented: $showingPaymentSheet) {
            TardiPaymentSheet()
        }
    }
}
