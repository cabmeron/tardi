import Foundation

/// Network client connecting the Tardi iOS App to the Go backend (`tardi-backend`).
/// Handles SetupIntent generation, cryptographic HMAC task sealing, and forfeiture calls.
@MainActor
final class BackendClient: ObservableObject {
    static let shared = BackendClient()

    @Published var isBackendHealthy = false
    @Published var lastSetupIntentClientSecret: String?
    @Published var currentCustomerId: String?

    // Local Go server URL (uses localhost for Simulator, or custom remote URL)
    var baseURL: URL = URL(string: "http://localhost:8080/api/v1")!

    private let session = URLSession.shared

    // MARK: - Models

    struct SetupIntentResponse: Codable {
        let success: Bool
        let clientSecret: String?
        let customerId: String?
        let message: String?
        let error: String?
    }

    struct SealTaskResponse: Codable {
        let success: Bool
        let taskId: String?
        let pledgeAmountCents: Int64?
        let hmacSeal: String?
        let status: String?
        let message: String?
        let error: String?
    }

    struct AccountStatusResponse: Codable {
        let isLocked: Bool
        let outstandingAmountCents: Int64
        let failedTaskTitle: String?
        let message: String?
    }

    // MARK: - Health Check

    func checkHealth() async -> Bool {
        guard let url = URL(string: "http://localhost:8080/health") else { return false }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let healthy = json?["status"] as? String == "healthy"
            self.isBackendHealthy = healthy
            return healthy
        } catch {
            self.isBackendHealthy = false
            return false
        }
    }

    // MARK: - 1. Create SetupIntent (Apple Pay / Card Vault)

    func createSetupIntent(customerId: String? = nil, email: String? = nil) async throws -> (clientSecret: String, customerId: String) {
        let url = baseURL.appendingPathComponent("vault/setup-intent")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [:]
        if let customerId { body["customerId"] = customerId }
        if let email { body["email"] = email }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "BackendClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate SetupIntent from backend"])
        }

        let res = try JSONDecoder().decode(SetupIntentResponse.self, from: data)
        guard res.success, let secret = res.clientSecret, let custId = res.customerId else {
            throw NSError(domain: "BackendClient", code: 2, userInfo: [NSLocalizedDescriptionKey: res.error ?? "Unknown error"])
        }

        self.lastSetupIntentClientSecret = secret
        self.currentCustomerId = custId
        return (secret, custId)
    }

    // MARK: - 2. Cryptographically Seal Task (HMAC)

    func sealTask(taskId: UUID, userId: String = "user_default", pledgeAmountCents: Int64, taskTitle: String, locationName: String) async throws -> String {
        let url = baseURL.appendingPathComponent("tasks/seal")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "taskId": taskId.uuidString,
            "userId": userId,
            "pledgeAmountCents": pledgeAmountCents,
            "taskTitle": taskTitle,
            "locationName": locationName
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "BackendClient", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to seal task on backend"])
        }

        let res = try JSONDecoder().decode(SealTaskResponse.self, from: data)
        guard res.success, let seal = res.hmacSeal else {
            throw NSError(domain: "BackendClient", code: 4, userInfo: [NSLocalizedDescriptionKey: res.error ?? "HMAC seal failed"])
        }

        return seal
    }

    // MARK: - 3. Check Account Status (Lockout Gatekeeper)

    func fetchAccountStatus() async throws -> AccountStatusResponse {
        let url = baseURL.appendingPathComponent("user/account-status")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "BackendClient", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch account status"])
        }
        return try JSONDecoder().decode(AccountStatusResponse.self, from: data)
    }
}
