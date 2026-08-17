import Foundation
import SwiftData
import CoreLocation

/// A commitment to be at a specific location by a specific time, either once
/// or on a recurring weekly schedule, tied to a chosen mode of transportation.
@Model
final class Commitment {
    var id: UUID

    // Location
    var locationName: String
    var latitude: Double
    var longitude: Double
    var radius: Double // meters

    // Schedule. `weekdays` uses Calendar's weekday numbering (1 = Sunday ... 7 = Saturday).
    // An empty array means this is a one-time commitment tied to `oneTimeDate`.
    var weekdays: [Int]
    var deadlineHour: Int
    var deadlineMinute: Int
    var oneTimeDate: Date?

    // Transportation
    var travelModeRawValue: String = TravelMode.bicycle.rawValue

    // State
    var streak: Int
    var isActive: Bool
    var isCurrentlyInside: Bool
    var lastLocationUpdate: Date?
    var lastEvaluatedDeadline: Date?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CheckInRecord.commitment)
    var history: [CheckInRecord] = []

    var travelMode: TravelMode {
        get { TravelMode(rawValue: travelModeRawValue) ?? .bicycle }
        set { travelModeRawValue = newValue.rawValue }
    }

    init(
        locationName: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        weekdays: [Int],
        deadlineHour: Int,
        deadlineMinute: Int,
        oneTimeDate: Date? = nil,
        travelMode: TravelMode = .bicycle
    ) {
        self.id = UUID()
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.weekdays = weekdays
        self.deadlineHour = deadlineHour
        self.deadlineMinute = deadlineMinute
        self.oneTimeDate = oneTimeDate
        self.travelModeRawValue = travelMode.rawValue
        self.streak = 0
        self.isActive = true
        self.isCurrentlyInside = false
        self.lastLocationUpdate = nil
        self.lastEvaluatedDeadline = nil
        self.createdAt = Date()
    }

    /// Stable identifier used for the CoreLocation region
    var regionIdentifier: String { "commitment-\(id.uuidString)" }

    var isRecurring: Bool { !weekdays.isEmpty }

    /// The most recent deadline at or before `referenceDate` that hasn't been scored yet.
    func pendingDeadline(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        if isRecurring {
            for daysAgo in 0..<8 {
                guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate) else { continue }
                let weekday = calendar.component(.weekday, from: day)
                guard weekdays.contains(weekday) else { continue }
                guard let deadline = calendar.date(bySettingHour: deadlineHour, minute: deadlineMinute, second: 0, of: day) else { continue }
                if deadline > referenceDate { continue }
                if let last = lastEvaluatedDeadline, last >= deadline { continue }
                return deadline
            }
            return nil
        } else {
            guard let oneTimeDate else { return nil }
            guard let deadline = calendar.date(bySettingHour: deadlineHour, minute: deadlineMinute, second: 0, of: oneTimeDate) else { return nil }
            if deadline > referenceDate { return nil }
            if let last = lastEvaluatedDeadline, last >= deadline { return nil }
            return deadline
        }
    }

    /// The next upcoming deadline strictly after `referenceDate`.
    func nextDeadline(after referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        if isRecurring {
            for daysAhead in 0..<8 {
                guard let day = calendar.date(byAdding: .day, value: daysAhead, to: referenceDate) else { continue }
                let weekday = calendar.component(.weekday, from: day)
                guard weekdays.contains(weekday) else { continue }
                guard let deadline = calendar.date(bySettingHour: deadlineHour, minute: deadlineMinute, second: 0, of: day) else { continue }
                if deadline > referenceDate { return deadline }
            }
            return nil
        } else {
            guard let oneTimeDate else { return nil }
            guard let deadline = calendar.date(bySettingHour: deadlineHour, minute: deadlineMinute, second: 0, of: oneTimeDate) else { return nil }
            return deadline > referenceDate ? deadline : nil
        }
    }

    /// Checks if this commitment has already been checked in or completed for the current day/cycle
    func isCompletedForToday(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let last = lastEvaluatedDeadline else { return false }
        if isRecurring {
            return calendar.isDate(last, inSameDayAs: referenceDate)
        } else {
            return true
        }
    }

    /// Performs an early check-in when user arrives at destination before the deadline
    func checkInEarly(now: Date = Date(), in context: ModelContext) {
        guard let deadline = nextDeadline(after: now) else { return }
        streak += 1
        lastEvaluatedDeadline = deadline

        let record = CheckInRecord(date: now, success: true, commitment: self)
        context.insert(record)
        try? context.save()

        NotificationManager.shared.sendResultNotification(for: self, success: true)
        NotificationManager.shared.cancelPendingNotifications(for: self)
    }

    /// How much of the countdown to the next deadline is left (1 = full, 0 = deadline now).
    func fuseProgress(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Double? {
        if isCompletedForToday(asOf: referenceDate) {
            return 1.0
        }
        guard let deadline = nextDeadline(after: referenceDate, calendar: calendar) else { return nil }
        let window: TimeInterval = 24 * 60 * 60
        let remaining = deadline.timeIntervalSince(referenceDate)
        return min(max(remaining / window, 0), 1)
    }

    /// Whether this commitment is scheduled for the given date (defaults to today).
    func isScheduled(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        if isRecurring {
            let weekday = calendar.component(.weekday, from: date)
            return weekdays.contains(weekday)
        } else if let oneTimeDate {
            return calendar.isDate(oneTimeDate, inSameDayAs: date)
        }
        return false
    }

    var deadlineMinutesFromMidnight: Int {
        deadlineHour * 60 + deadlineMinute
    }

    var formattedDeadlineTime: String {
        var components = DateComponents()
        components.hour = deadlineHour
        components.minute = deadlineMinute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Exact time remaining in seconds until the next deadline
    func timeRemaining(asOf referenceDate: Date = Date()) -> TimeInterval? {
        guard let deadline = nextDeadline(after: referenceDate) else { return nil }
        return max(deadline.timeIntervalSince(referenceDate), 0)
    }

    /// Concise time remaining label (e.g. "2h 15m", "42m", "5m")
    func formattedTimeRemaining(asOf referenceDate: Date = Date()) -> String {
        if isCompletedForToday(asOf: referenceDate) {
            return "Done"
        }
        guard let remaining = timeRemaining(asOf: referenceDate) else { return "Passed" }
        let totalSeconds = Int(remaining)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }

    /// Formats distance meters into readable miles or feet (e.g. "1.4 mi", "0.3 mi", "350 ft")
    static func formatMiles(distanceMeters: Double) -> String {
        let miles = distanceMeters / 1609.344
        if miles < 0.1 {
            let feet = Int(distanceMeters * 3.28084)
            return "\(feet) ft"
        } else {
            return String(format: "%.1f mi", miles)
        }
    }

    /// Latest recommended departure time to arrive before the next deadline
    func latestDepartureTime(from userCoordinate: CLLocationCoordinate2D?, asOf referenceDate: Date = Date()) -> Date? {
        guard let deadline = nextDeadline(after: referenceDate) else { return nil }
        guard let userCoord = userCoordinate else { return deadline }

        let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let targetLoc = CLLocation(latitude: latitude, longitude: longitude)
        let distance = userLoc.distance(from: targetLoc)
        let travelSeconds = travelMode.estimatedTravelTime(distanceMeters: distance)

        return deadline.addingTimeInterval(-travelSeconds)
    }

    /// Seconds until the recommended departure time
    func timeUntilDeparture(from userCoordinate: CLLocationCoordinate2D?, asOf referenceDate: Date = Date()) -> TimeInterval? {
        guard let leaveTime = latestDepartureTime(from: userCoordinate, asOf: referenceDate) else { return nil }
        return leaveTime.timeIntervalSince(referenceDate)
    }
}
