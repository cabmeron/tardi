import SwiftUI
import SwiftData
#if canImport(StripePaymentSheet)
import StripePaymentSheet
#elseif canImport(Stripe)
import Stripe
#endif

@main
struct TardiApp: App {
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer

    init() {
        // Stripe Publishable Key Initialization
        let stripePublishableKey = "pk_test_51U70crFqnsvKjM8mrYGWGwvuz1lDThA9R7dQPyPYfiFb4sqoz86FH2uPgqivUsuA9MZVU7OxqPqRQPrfoHghfpqa00LxKf0K8l"
        #if canImport(StripePaymentSheet)
        StripeAPI.defaultPublishableKey = stripePublishableKey
        #elseif canImport(Stripe)
        StripeAPI.defaultPublishableKey = stripePublishableKey
        #endif

        let schema = Schema([LocationNode.self, HabitTask.self, CheckInRecord.self])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            print("ModelContainer creation error: \(error). Cleaning up incompatible legacy store...")
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let defaultStore = appSupport.appendingPathComponent("default.store")
                let shmStore = appSupport.appendingPathComponent("default.store-shm")
                let walStore = appSupport.appendingPathComponent("default.store-wal")
                try? FileManager.default.removeItem(at: defaultStore)
                try? FileManager.default.removeItem(at: shmStore)
                try? FileManager.default.removeItem(at: walStore)
            }
            do {
                container = try ModelContainer(for: schema)
            } catch {
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try! ModelContainer(for: schema, configurations: [memoryConfig])
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RadarHomeView()
                .onAppear {
                    LocationManager.shared.configure(modelContext: container.mainContext)
                    NotificationManager.shared.requestAuthorization()
                    LocationManager.shared.requestAlwaysAuthorization()

                    let descriptor = FetchDescriptor<LocationNode>()
                    if let all = try? container.mainContext.fetch(descriptor) {
                        LocationManager.shared.resumeMonitoring(for: all)
                    }

                    CommitmentEvaluator.evaluateDueCommitments(in: container.mainContext)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                CommitmentEvaluator.evaluateDueCommitments(in: container.mainContext)
            }
        }
    }
}
