import Foundation
import UserNotifications

/// Handles scheduling and delivery of local notifications for habit tasks and deadlines.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleDeadlineNotification(for task: HabitTask, at deadline: Date) {
        let nodeName = task.node?.name ?? "your destination"
        let content = UNMutableNotificationContent()
        content.title = "Habit Deadline: \(task.title)"
        content.body = "You must be at \(nodeName) right now to keep your streak!"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: deadline
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: task, at: deadline),
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelPendingNotifications(for task: HabitTask) {
        center.getPendingNotificationRequests { requests in
            let prefix = "task-\(task.id.uuidString)"
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    func sendTaskResultNotification(for task: HabitTask, success: Bool) {
        let nodeName = task.node?.name ?? "your destination"
        let content = UNMutableNotificationContent()
        if success {
            content.title = "Check-in Passed! 🔥"
            content.body = "You were at \(nodeName) for \(task.title). Streak: \(task.streak)!"
        } else {
            if task.isPledged && task.pledgeAmount > 0 {
                content.title = "🚨 $\(Int(task.pledgeAmount)).00 Charged: Missed Check-in"
                content.body = "You were not at \(nodeName) for \(task.title). Your $\(Int(task.pledgeAmount)) stake was forfeited."
            } else {
                content.title = "Check-in Missed 🚨"
                content.body = "You were not at \(nodeName) for \(task.title). Streak reset to 0."
            }
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private func notificationIdentifier(for task: HabitTask, at date: Date) -> String {
        "task-\(task.id.uuidString)-\(date.timeIntervalSince1970)"
    }
}
