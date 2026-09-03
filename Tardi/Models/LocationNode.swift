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

    /// All tasks configured at this node sorted newest first by creation timestamp
    var tasksNewestFirst: [HabitTask] {
        tasks.sorted { $0.createdAt > $1.createdAt }
    }

    /// Returns all active tasks configured at this node sorted newest first
    var activeTasks: [HabitTask] {
        tasks.filter(\.isActive).sorted { $0.createdAt > $1.createdAt }
    }

    /// The single nearest active or upcoming task for this node.
    /// Prioritizes live upcoming tasks in the future (soonest deadline first),
    /// then future scheduled tasks for upcoming days.
    func nearestUpcomingTask(after referenceDate: Date = Date()) -> HabitTask? {
        let active = activeTasks
        guard !active.isEmpty else { return nil }

        // 1. Live uncompleted tasks with an upcoming deadline strictly in the future (soonest first)
        let liveUpcoming = active
            .filter { !$0.isCompletedForToday(asOf: referenceDate) && !$0.isMissed(asOf: referenceDate) }
            .compactMap { task -> (HabitTask, Date)? in
                guard let deadline = task.nextDeadline(after: referenceDate), deadline > referenceDate else { return nil }
                return (task, deadline)
            }
        if let soonestLive = liveUpcoming.min(by: { $0.1 < $1.1 })?.0 {
            return soonestLive
        }

        // 2. Otherwise find the earliest future upcoming deadline (all today's completed or missed)
        var candidateTask: HabitTask?
        var earliestDeadline: Date?

        for task in active {
            guard let deadline = task.nextDeadline(after: referenceDate), deadline > referenceDate else { continue }
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
        nearestUpcomingTask(after: referenceDate)?.fuseProgress(asOf: referenceDate)
    }

    /// True if at least one task at this node has been completed today
    func isAnyTaskCompletedToday(asOf referenceDate: Date = Date()) -> Bool {
        tasks.contains { $0.isCompletedForToday(asOf: referenceDate) }
    }

    /// True if there is at least one active task at this node that is actively armed (counting down to a future deadline)
    func hasArmedTask(asOf referenceDate: Date = Date()) -> Bool {
        activeTasks.contains { $0.isArmed(asOf: referenceDate) }
    }

    /// True if all active tasks scheduled for today at this node have been completed
    func isAllTasksCompletedToday(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        let todayTasks = activeTasks.filter { task in
            if task.isRecurring {
                let weekday = calendar.component(.weekday, from: referenceDate)
                return task.weekdays.contains(weekday)
            } else if let oneTimeDate = task.oneTimeDate {
                return calendar.isDate(oneTimeDate, inSameDayAs: referenceDate)
            }
            return false
        }
        if !todayTasks.isEmpty {
            return todayTasks.allSatisfy { $0.isCompletedForToday(asOf: referenceDate, calendar: calendar) }
        }
        return isAnyTaskCompletedToday(asOf: referenceDate)
    }

    /// True if any active task at this node was missed today and there are no live armed tasks
    func hasMissedTask(asOf referenceDate: Date = Date()) -> Bool {
        guard !hasArmedTask(asOf: referenceDate) else { return false }
        if isAllTasksCompletedToday(asOf: referenceDate) { return false }
        return activeTasks.contains { $0.isMissed(asOf: referenceDate) }
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
