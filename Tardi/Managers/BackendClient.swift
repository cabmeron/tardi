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

    struct ForfeitResponse: Codable {
        let success: Bool
        let status: String?
        let amountCents: Int64?
        let paymentIntentId: String?
        let declineCode: String?
        let isLocked: Bool?
        let message: String?
        let error: String?
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

        print("🚀 [BackendClient] Requesting SetupIntent from \(url.absoluteString) (email: \(email ?? "nil"), customerId: \(customerId ?? "nil"))")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "BackendClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
        }

        if let rawJson = String(data: data, encoding: .utf8) {
            print("📥 [BackendClient] HTTP \(http.statusCode) Response: \(rawJson)")
        }

        guard http.statusCode == 200 else {
            throw NSError(domain: "BackendClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Backend returned HTTP \(http.statusCode)"])
        }

        let res = try JSONDecoder().decode(SetupIntentResponse.self, from: data)
        guard res.success, let secret = res.clientSecret, let custId = res.customerId else {
            throw NSError(domain: "BackendClient", code: 2, userInfo: [NSLocalizedDescriptionKey: res.error ?? "Unknown error"])
        }

        self.lastSetupIntentClientSecret = secret
        self.currentCustomerId = custId
        print("✅ [BackendClient] Vault SetupIntent acquired! Customer: \(custId), ClientSecret: \(secret.prefix(15))...")
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

    // MARK: - 3. Execute Forfeiture Charge (Stripe PaymentIntent)

    func forfeitPledge(
        taskId: UUID,
        userId: String = "user_default",
        customerId: String,
        pledgeAmountCents: Int64,
        taskTitle: String,
        deadlineDate: Date,
        storedHmacSeal: String = ""
    ) async throws -> ForfeitResponse {
        let url = baseURL.appendingPathComponent("evaluations/forfeit")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "taskId": taskId.uuidString,
            "userId": userId,
            "customerId": customerId,
            "pledgeAmountCents": pledgeAmountCents,
            "taskTitle": taskTitle,
            "deadlineDate": formatter.string(from: deadlineDate),
            "storedHmacSeal": storedHmacSeal
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("⚡ [BackendClient] Triggering PaymentIntent Forfeiture of $\(Double(pledgeAmountCents)/100.0) for '\(taskTitle)'")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "BackendClient", code: 5, userInfo: [NSLocalizedDescriptionKey: "Forfeiture request failed"])
        }

        let res = try JSONDecoder().decode(ForfeitResponse.self, from: data)
        if res.success {
            print("💳 [BackendClient] Forfeiture PaymentIntent confirmed! ID: \(res.paymentIntentId ?? "none")")
        } else {
            print("⚠️ [BackendClient] Forfeiture declined: \(res.error ?? res.message ?? "Unknown")")
        }
        return res
    }

    // MARK: - 4. Create Pre-Auth PaymentIntent (Manual Capture Hold on Arming)

    struct CreatePaymentIntentResponse: Codable {
        let success: Bool
        let clientSecret: String?
        let customerId: String?
        let paymentIntentId: String?
        let status: String?
        let message: String?
        let error: String?
    }

    struct CancelPaymentIntentResponse: Codable {
        let success: Bool
        let status: String?
        let message: String?
        let error: String?
    }

    func createPreAuthPaymentIntent(
        pledgeAmountCents: Int64,
        taskTitle: String,
        taskId: UUID? = nil,
        customerId: String? = nil,
        email: String? = nil
    ) async throws -> (clientSecret: String, customerId: String, paymentIntentId: String) {
        let url = baseURL.appendingPathComponent("vault/create-payment-intent")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "pledgeAmountCents": pledgeAmountCents,
            "taskTitle": taskTitle
        ]
        if let taskId { body["taskId"] = taskId.uuidString }
        if let customerId { body["customerId"] = customerId }
        if let email { body["email"] = email }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("⚡ [BackendClient] Creating Pre-Auth PaymentIntent for $\(Double(pledgeAmountCents)/100.0) (Manual Capture)")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "BackendClient", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to create PaymentIntent"])
        }

        let res = try JSONDecoder().decode(CreatePaymentIntentResponse.self, from: data)
        guard res.success, let secret = res.clientSecret, let custId = res.customerId, let piId = res.paymentIntentId else {
            throw NSError(domain: "BackendClient", code: 7, userInfo: [NSLocalizedDescriptionKey: res.error ?? "Pre-auth failed"])
        }

        self.currentCustomerId = custId
        print("✅ [BackendClient] Pre-Auth PaymentIntent Created: \(piId). Goal: Cancel upon arrival!")
        return (secret, custId, piId)
    }

    // MARK: - 5. Cancel PaymentIntent (Goal Achieved / Arrived on Time!)

    func cancelPaymentIntent(paymentIntentId: String, taskId: UUID? = nil) async throws -> Bool {
        let url = baseURL.appendingPathComponent("vault/cancel-payment-intent")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["paymentIntentId": paymentIntentId]
        if let taskId { body["taskId"] = taskId.uuidString }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("🎉 [BackendClient] Canceling PaymentIntent \(paymentIntentId) (Goal Met!)")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "BackendClient", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to cancel PaymentIntent"])
        }

        let res = try JSONDecoder().decode(CancelPaymentIntentResponse.self, from: data)
        if res.success {
            print("✅ [BackendClient] PaymentIntent \(paymentIntentId) successfully CANCELED! Funds released.")
        }
        return res.success
    }

    // MARK: - 6. Capture PaymentIntent (Missed Deadline Forfeiture)

    func capturePaymentIntent(paymentIntentId: String, amountCents: Int64? = nil) async throws -> Bool {
        let url = baseURL.appendingPathComponent("vault/capture-payment-intent")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["paymentIntentId": paymentIntentId]
        if let amountCents { body["amountCents"] = amountCents }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("⚠️ [BackendClient] Capturing PaymentIntent \(paymentIntentId) (Deadline Missed)")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "BackendClient", code: 9, userInfo: [NSLocalizedDescriptionKey: "Failed to capture PaymentIntent"])
        }
        return true
    }

    // MARK: - 7. Check Account Status (Lockout Gatekeeper)

    func fetchAccountStatus() async throws -> AccountStatusResponse {
        let url = baseURL.appendingPathComponent("user/account-status")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "BackendClient", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch account status"])
        }
        return try JSONDecoder().decode(AccountStatusResponse.self, from: data)
    }
}
