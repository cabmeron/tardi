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

    /// Exact deadline time formatted with user's locale short time, e.g. "10:15 AM" or "5:37 PM"
    var formattedDeadlineTime: String {
        var components = DateComponents()
        components.hour = deadlineHour
        components.minute = deadlineMinute
        if let date = Calendar.current.date(from: components) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        let period = deadlineHour >= 12 ? "PM" : "AM"
        let hour12 = deadlineHour == 0 ? 12 : (deadlineHour > 12 ? deadlineHour - 12 : deadlineHour)
        return String(format: "%d:%02d %@", hour12, deadlineMinute, period)
    }

    /// Complete schedule summary displaying exact day/date and exact time (e.g. "Tue, Sep 1 at 5:37 PM" or "Daily at 10:15 AM")
    var scheduleSummary: String {
        let time = formattedDeadlineTime
        if isRecurring {
            let symbols = Calendar.current.shortWeekdaySymbols
            let names = weekdays.sorted().compactMap { weekday -> String? in
                guard weekday >= 1, weekday <= symbols.count else { return nil }
                return symbols[weekday - 1]
            }
            if weekdays.count == 7 {
                return "Daily at \(time)"
            } else if weekdays == [2, 3, 4, 5, 6] {
                return "Weekdays at \(time)"
            } else if weekdays == [1, 7] {
                return "Weekends at \(time)"
            } else if names.count == 1 {
                return "Every \(names[0]) at \(time)"
            } else {
                return "\(names.joined(separator: ", ")) at \(time)"
            }
        } else if let date = oneTimeDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return "\(formatter.string(from: date)) at \(time)"
        }
        return "At \(time)"
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

    /// The active relevant deadline for this task:
    /// Prioritizes any uncompleted pending/overdue deadline for today, then the next upcoming future deadline.
    func currentOrUpcomingDeadline(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        if !isCompletedForToday(asOf: referenceDate, calendar: calendar) {
            if let pending = pendingDeadline(asOf: referenceDate, calendar: calendar) {
                return pending
            }
        }
        return nextDeadline(after: referenceDate, calendar: calendar)
    }

    /// True if the deadline has passed without a successful check-in (evaluated as forfeited or elapsed)
    func isMissed(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        if isCompletedForToday(asOf: referenceDate, calendar: calendar) {
            return false
        }
        // 1. One-time task whose scheduled deadline is in the past
        if !isRecurring {
            guard let oneTimeDate,
                  let deadline = calendar.date(bySettingHour: deadlineHour, minute: deadlineMinute, second: 0, of: oneTimeDate) else {
                return false
            }
            return referenceDate >= deadline
        }
        // 2. Evaluated today as unsuccessful (streak reset, lastEvaluatedDeadline set to today's deadline)
        if let last = lastEvaluatedDeadline, calendar.isDate(last, inSameDayAs: referenceDate), streak == 0 {
            return true
        }
        // 3. Recurring task: if today was a scheduled day and today's deadline has already elapsed
        let weekday = calendar.component(.weekday, from: referenceDate)
        if weekdays.contains(weekday) {
            guard let todayDeadline = calendar.date(bySettingHour: deadlineHour, minute: deadlineMinute, second: 0, of: referenceDate) else {
                return false
            }
            if referenceDate >= todayDeadline {
                return true
            }
        }
        return false
    }

    /// Total amount of money missed/forfeited for this task (includes recorded forfeitures and current missed deadline stake)
    func amountMissed(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Double {
        if totalForfeitedAmount > 0 {
            return totalForfeitedAmount
        }
        if isMissed(asOf: referenceDate, calendar: calendar) {
            return pledgeAmount
        }
        return 0.0
    }

    /// True if the task is actively counting down to a future deadline (not completed, not missed, and within 24h)
    func isArmed(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isActive else { return false }
        if isCompletedForToday(asOf: referenceDate, calendar: calendar) { return false }
        if isMissed(asOf: referenceDate, calendar: calendar) { return false }
        guard let deadline = nextDeadline(after: referenceDate, calendar: calendar) else { return false }
        guard deadline > referenceDate else { return false }
        let remaining = deadline.timeIntervalSince(referenceDate)
        return remaining <= 24 * 3600
    }

    /// Calculates the burning countdown progress (1.0 = full cord at start, burns down to 0.0 at deadline).
    /// Uses an adaptive urgency curve so that whether a task is 5 minutes, 30 minutes, or 8 hours away,
    /// the remaining countdown cord length is clearly visible and accurately reflects urgency.
    func fuseProgress(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Double? {
        if isCompletedForToday(asOf: referenceDate) {
            return 1.0
        }
        if isMissed(asOf: referenceDate, calendar: calendar) {
            return nil
        }
        guard let deadline = nextDeadline(after: referenceDate, calendar: calendar) else { return nil }
        let remaining = deadline.timeIntervalSince(referenceDate)
        guard remaining > 0 else { return nil }

        // Determine effective countdown horizon:
        let createdSpan = deadline.timeIntervalSince(createdAt)
        let effectiveWindow: TimeInterval

        if !isRecurring && createdSpan >= 60 && createdSpan <= 12 * 3600 {
            // Task was explicitly set for a specific duration (e.g. 5m, 15m, 1h, 4h)
            effectiveWindow = createdSpan
        } else if remaining <= 3600 {
            // Final hour sprint: scale across 60 minutes so short deadlines show prominently
            effectiveWindow = 3600
        } else if remaining <= 4 * 3600 {
            // Near term: scale across 4 hours
            effectiveWindow = 4 * 3600
        } else {
            // Long term: scale across 12 hours
            effectiveWindow = 12 * 3600
        }

        let ratio = max(min(remaining / effectiveWindow, 1.0), 0.0)
        // Gentle power curve ensuring clean visual weight even in the final minutes
        let progress = pow(ratio, 0.70)
        return min(max(progress, 0.08), 0.98)
    }

    func isCompletedForToday(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        // 1. If check-in history records exist, check for a successful check-in today
        if !history.isEmpty {
            return history.contains { $0.success && calendar.isDate($0.date, inSameDayAs: referenceDate) }
        }
        // 2. Fallback: must have an evaluated deadline today AND a positive streak (successful disarm)
        guard let last = lastEvaluatedDeadline else { return false }
        if streak > 0 {
            return calendar.isDate(last, inSameDayAs: referenceDate)
        }
        return false
    }

    func timeRemaining(asOf referenceDate: Date = Date()) -> TimeInterval? {
        guard let deadline = currentOrUpcomingDeadline(asOf: referenceDate) else { return nil }
        return max(deadline.timeIntervalSince(referenceDate), 0)
    }

    func formattedTimeRemaining(asOf referenceDate: Date = Date()) -> String {
        if isCompletedForToday(asOf: referenceDate) {
            return "Done"
        }
        guard let deadline = currentOrUpcomingDeadline(asOf: referenceDate) else { return "Passed" }
        let remaining = deadline.timeIntervalSince(referenceDate)
        if remaining <= 0 {
            return "Armed"
        }
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
    func checkInEarly(now: Date = Date(), isLocationVerified: Bool = true, distanceMeters: Double? = nil, in context: ModelContext) {
        let deadline = currentOrUpcomingDeadline(asOf: now) ?? nextDeadline(after: now) ?? now
        streak += 1
        lastEvaluatedDeadline = deadline

        let record = CheckInRecord(date: now, success: true, isLocationVerified: isLocationVerified, distanceMeters: distanceMeters, task: self)
        history.append(record)
        context.insert(record)
        try? context.save()

        NotificationManager.shared.sendTaskResultNotification(for: self, success: true)
        NotificationManager.shared.cancelPendingNotifications(for: self)
    }
}
