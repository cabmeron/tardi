import SwiftUI

/// An interactive testing and configuration view for the Go backend connection and SetupIntent generation.
struct VaultArmingView: View {
    @StateObject private var client = BackendClient.shared

    @State private var isLoading = false
    @State private var statusMessage: String = "Ready to test Go backend"
    @State private var returnedClientSecret: String = ""
    @State private var returnedCustomerId: String = ""
    @State private var isSuccess = false

    private let haptic = UINotificationFeedbackGenerator()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 0. Primary Live Stripe Vault Card Presenter
                    StripeVaultCardPresenter()

                    // 1. Backend Server Status Indicator
                    HStack(spacing: 12) {
                        Circle()
                            .fill(client.isBackendHealthy ? Color.green : Color.orange)
                            .frame(width: 12, height: 12)
                            .shadow(color: (client.isBackendHealthy ? Color.green : Color.orange).opacity(0.8), radius: 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.isBackendHealthy ? "GO BACKEND ONLINE" : "CHECKING SERVER...")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)

                            Text("http://localhost:8080/api/v1")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            Task { await client.checkHealth() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // 2. SetupIntent Test Action Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("STRIPE VAULT SETUPINTENT TEST")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        Text("Tests the roundtrip API request to the Go backend to create a Stripe Customer and generate an authorized SetupIntent client secret.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Button(action: testSetupIntent) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "creditcard.and.123")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Test Generate SetupIntent")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                        }
                        .disabled(isLoading)
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // 3. Roundtrip Result Card
                    if !returnedClientSecret.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("SETUPINTENT RECEIVED (200 OK)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.green)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("CUSTOMER ID")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text(returnedCustomerId)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("CLIENT SECRET (TOKENIZED)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text(returnedClientSecret)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                            }

                            Text("Status: \(statusMessage)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.green.opacity(0.3), lineWidth: 1))
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stripe Vault Test")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await client.checkHealth()
            }
        }
    }

    private func testSetupIntent() {
        isLoading = true
        haptic.notificationOccurred(.warning)

        Task {
            do {
                let (secret, custId) = try await client.createSetupIntent(email: "demo@tardi.app")
                await MainActor.run {
                    self.returnedClientSecret = secret
                    self.returnedCustomerId = custId
                    self.statusMessage = "Successfully generated SetupIntent from Go service!"
                    self.isSuccess = true
                    self.isLoading = false
                    self.haptic.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    self.isLoading = false
                    self.haptic.notificationOccurred(.error)
                }
            }
        }
    }
}
