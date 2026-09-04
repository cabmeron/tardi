import Foundation
import CoreLocation
import SwiftData

/// Owns the CLLocationManager and keeps each LocationNode's
/// `isCurrentlyInside` flag up to date via region monitoring.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus

    /// The user's live coordinate, updated while `startUpdatingUserLocation()` is active.
    @Published var currentCoordinate: CLLocationCoordinate2D?

    private var modelContext: ModelContext?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 5
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdatingUserLocation() {
        manager.startUpdatingLocation()
    }

    func stopUpdatingUserLocation() {
        manager.stopUpdatingLocation()
    }

    func startMonitoring(_ node: LocationNode) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: node.latitude, longitude: node.longitude),
            radius: max(node.radius, 25),
            identifier: node.regionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        manager.requestState(for: region)
    }

    func stopMonitoring(_ node: LocationNode) {
        for region in manager.monitoredRegions where region.identifier == node.regionIdentifier {
            manager.stopMonitoring(for: region)
        }
    }

    func resumeMonitoring(for nodes: [LocationNode]) {
        for node in nodes {
            startMonitoring(node)
        }
    }

    private func node(for region: CLRegion, in context: ModelContext) -> LocationNode? {
        let identifier = region.identifier
        if identifier.hasPrefix("node-"),
           let uuid = UUID(uuidString: String(identifier.dropFirst(5))) {
            var descriptor = FetchDescriptor<LocationNode>(
                predicate: #Predicate { $0.id == uuid }
            )
            descriptor.fetchLimit = 1
            if let result = try? context.fetch(descriptor).first {
                return result
            }
        }
        let descriptor = FetchDescriptor<LocationNode>()
        guard let all = try? context.fetch(descriptor) else { return nil }
        return all.first { $0.regionIdentifier == identifier }
    }

    private func updatePresence(isInside: Bool, region: CLRegion) {
        guard let modelContext else { return }
        guard let locationNode = node(for: region, in: modelContext) else { return }
        locationNode.isCurrentlyInside = isInside
        locationNode.lastLocationUpdate = Date()
        try? modelContext.save()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            self.updatePresence(isInside: true, region: region)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            self.updatePresence(isInside: false, region: region)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        Task { @MainActor in
            switch state {
            case .inside:
                self.updatePresence(isInside: true, region: region)
            case .outside:
                self.updatePresence(isInside: false, region: region)
            case .unknown:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.currentCoordinate = coordinate
        }
    }
}
