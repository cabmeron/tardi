import Foundation
import SwiftData
import CoreLocation

/// A scheduled task, habit, or arrival commitment attached to a LocationNode.
/// Multiple tasks can be assigned to the same node to reuse locations.
/// Supports financial pledge stakes where money is charged if the deadline is missed.
@Model
final class HabitTask {
    var id: UUID
    var title: String

    // Schedule (weekdays: 1 = Sunday ... 7 = Saturday; empty means oneTimeDate)
    var weekdays: [Int]
    var deadlineHour: Int
    var deadlineMinute: Int
    var oneTimeDate: Date?

    var streak: Int
    var isActive: Bool
    var lastEvaluatedDeadline: Date?
    var createdAt: Date

    // Financial Pledge Stake
    var pledgeAmount: Double
    var isPledged: Bool
    var activePaymentIntentId: String?
    var forfeitedCount: Int
    var totalForfeitedAmount: Double

    var node: LocationNode?

    @Relationship(deleteRule: .cascade, inverse: \CheckInRecord.task)
    var history: [CheckInRecord] = []

    init(
        title: String,
        weekdays: [Int],
        deadlineHour: Int,
        deadlineMinute: Int,
        oneTimeDate: Date? = nil,
        pledgeAmount: Double = 0.0,
        activePaymentIntentId: String? = nil,
        node: LocationNode? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.weekdays = weekdays
        self.deadlineHour = deadlineHour
        self.deadlineMinute = deadlineMinute
        self.oneTimeDate = oneTimeDate
        self.streak = 0
        self.isActive = true
        self.lastEvaluatedDeadline = nil
        self.createdAt = Date()
        self.pledgeAmount = pledgeAmount
        self.isPledged = pledgeAmount > 0
        self.activePaymentIntentId = activePaymentIntentId
        self.forfeitedCount = 0
        self.totalForfeitedAmount = 0.0
        self.node = node
    }

    var isRecurring: Bool { !weekdays.isEmpty }

    var formattedPledgeAmount: String {
        guard pledgeAmount > 0 else { return "No Stake" }
        return String(format: "$%.0f", pledgeAmount)
    }

    var daylightPhaseDescription: String {
        switch deadlineHour {
        case 5..<9:   return "Dawn"
        case 9..<12:  return "Morning"
        case 12..<15: return "Midday"
        case 15..<18: return "Afternoon"
        case 18..<21: return "Dusk"
        default:      return "Night"
        }
    }

    var formattedDeadlineTime: String {
        daylightPhaseDescription
    }

    var scheduleSummary: String {
        let phase = daylightPhaseDescription
        if isRecurring {
            let symbols = Calendar.current.shortWeekdaySymbols
            let names = weekdays.sorted().compactMap { weekday -> String? in
                guard weekday >= 1, weekday <= symbols.count else { return nil }
                return symbols[weekday - 1]
            }
            if weekdays.count == 7 {
                return "Daily · \(phase)"
            } else if weekdays == [2, 3, 4, 5, 6] {
                return "Weekdays · \(phase)"
            } else {
                return "\(names.joined(separator: ", ")) · \(phase)"
            }
        } else if let date = oneTimeDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: date)) · \(phase)"
        }
        return phase
    }

    /// The most recent deadline at or before `referenceDate` that hasn't been scored yet
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

    /// The next upcoming deadline strictly after `referenceDate`
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

    /// Calculates the burning countdown progress (1.0 = full cord at start, burns down to 0.0 at deadline).
    /// Uses a responsive urgency curve so that whether a task is 8 hours away or 30 minutes away,
    /// the burning ember and cord length accurately reflect relative urgency.
    func fuseProgress(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Double? {
        if isCompletedForToday(asOf: referenceDate) {
            return 1.0
        }
        guard let deadline = nextDeadline(after: referenceDate, calendar: calendar) else { return nil }
        let remaining = deadline.timeIntervalSince(referenceDate)
        guard remaining > 0 else { return 0.0 }

        // Dynamic urgency scale over a 12-hour active burn window
        let maxWindow: TimeInterval = 12 * 3600
        if remaining >= maxWindow {
            return 0.95
        }
        let ratio = remaining / maxWindow
        let progress = pow(ratio, 0.75)
        return min(max(progress, 0.04), 0.96)
    }

    func isCompletedForToday(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let last = lastEvaluatedDeadline else { return false }
        if isRecurring {
            return calendar.isDate(last, inSameDayAs: referenceDate)
        } else {
            return true
        }
    }

    func timeRemaining(asOf referenceDate: Date = Date()) -> TimeInterval? {
        guard let deadline = nextDeadline(after: referenceDate) else { return nil }
        return max(deadline.timeIntervalSince(referenceDate), 0)
    }

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

    @MainActor
    func checkInEarly(now: Date = Date(), in context: ModelContext) {
        guard let deadline = nextDeadline(after: now) else { return }
        streak += 1
        lastEvaluatedDeadline = deadline

        let record = CheckInRecord(date: now, success: true, task: self)
        context.insert(record)
        try? context.save()

        NotificationManager.shared.sendTaskResultNotification(for: self, success: true)
        NotificationManager.shared.cancelPendingNotifications(for: self)
    }
}
