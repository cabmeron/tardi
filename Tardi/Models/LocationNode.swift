import Foundation
import SwiftData
import CoreLocation

/// A physical location node on the map (e.g. Gym, Office, Library, Home).
/// Can exist with or without scheduled tasks, allowing nodes to be reused
/// across multiple habits and schedules.
@Model
final class LocationNode {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double // meters
    var travelModeRawValue: String = TravelMode.bicycle.rawValue
    var isCurrentlyInside: Bool = false
    var lastLocationUpdate: Date?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitTask.node)
    var tasks: [HabitTask] = []

    var travelMode: TravelMode {
        get { TravelMode(rawValue: travelModeRawValue) ?? .bicycle }
        set { travelModeRawValue = newValue.rawValue }
    }

    init(
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 100,
        travelMode: TravelMode = .bicycle
    ) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.travelModeRawValue = travelMode.rawValue
        self.isCurrentlyInside = false
        self.lastLocationUpdate = nil
        self.createdAt = Date()
    }

    var regionIdentifier: String { "node-\(id.uuidString)" }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Returns all active tasks configured at this node
    var activeTasks: [HabitTask] {
        tasks.filter(\.isActive)
    }

    /// The single nearest upcoming task whose deadline is closest in the future
    func nearestUpcomingTask(after referenceDate: Date = Date()) -> HabitTask? {
        let active = activeTasks
        var candidateTask: HabitTask?
        var earliestDeadline: Date?

        for task in active {
            guard let deadline = task.nextDeadline(after: referenceDate) else { continue }
            if earliestDeadline == nil || deadline < earliestDeadline! {
                earliestDeadline = deadline
                candidateTask = task
            }
        }
        return candidateTask
    }

    /// Next deadline timestamp across all active tasks
    func nextDeadline(after referenceDate: Date = Date()) -> Date? {
        nearestUpcomingTask(after: referenceDate)?.nextDeadline(after: referenceDate)
    }

    /// Fuse countdown progress for the nearest upcoming task (1 = full, 0 = deadline now)
    func fuseProgress(asOf referenceDate: Date = Date()) -> Double? {
        guard let nearest = nearestUpcomingTask(after: referenceDate) else {
            return isAnyTaskCompletedToday(asOf: referenceDate) ? 1.0 : nil
        }
        return nearest.fuseProgress(asOf: referenceDate)
    }

    /// True if at least one task at this node has been completed today
    func isAnyTaskCompletedToday(asOf referenceDate: Date = Date()) -> Bool {
        tasks.contains { $0.isCompletedForToday(asOf: referenceDate) }
    }

    /// Latest recommended departure time for the nearest upcoming task
    func latestDepartureTime(from userCoordinate: CLLocationCoordinate2D?, asOf referenceDate: Date = Date()) -> Date? {
        guard let deadline = nextDeadline(after: referenceDate) else { return nil }
        guard let userCoord = userCoordinate else { return deadline }

        let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let targetLoc = CLLocation(latitude: latitude, longitude: longitude)
        let distance = userLoc.distance(from: targetLoc)
        let travelSeconds = travelMode.estimatedTravelTime(distanceMeters: distance)

        return deadline.addingTimeInterval(-travelSeconds)
    }

    /// Seconds until recommended departure for the nearest upcoming task
    func timeUntilDeparture(from userCoordinate: CLLocationCoordinate2D?, asOf referenceDate: Date = Date()) -> TimeInterval? {
        guard let leaveTime = latestDepartureTime(from: userCoordinate, asOf: referenceDate) else { return nil }
        return leaveTime.timeIntervalSince(referenceDate)
    }
}
