import Foundation
import UserNotifications

/// Schedules local notifications for upcoming deadlines and reports results.
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleDeadlineNotification(for commitment: Commitment, at deadline: Date) {
        let content = UNMutableNotificationContent()
        content.title = commitment.locationName
        content.body = "Check-in deadline! Are you here?"
        content.sound = .default
        content.userInfo = ["commitmentID": commitment.id.uuidString]

        let interval = deadline.timeIntervalSinceNow
        guard interval > 0 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "deadline-\(commitment.id.uuidString)-\(Int(deadline.timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendResultNotification(for commitment: Commitment, success: Bool) {
        let content = UNMutableNotificationContent()
        content.title = success ? "✅ Checked in on time" : "❌ Missed check-in"
        content.body = success
            ? "You were at \(commitment.locationName). Current streak: \(commitment.streak)."
            : "You weren't at \(commitment.locationName) by the deadline. Streak reset."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "result-\(commitment.id.uuidString)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelPendingNotifications(for commitment: Commitment) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.contains(commitment.id.uuidString) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
