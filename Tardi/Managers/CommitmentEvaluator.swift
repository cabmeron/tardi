import Foundation
import SwiftData

/// Scores habit tasks whose deadline has passed based on the LocationNode's geofence state.
/// If a financial pledge is armed and the deadline is missed, the stake is automatically forfeited.
@MainActor
enum CommitmentEvaluator {
    static func evaluateDueCommitments(in context: ModelContext, now: Date = Date()) {
        let descriptor = FetchDescriptor<HabitTask>(predicate: #Predicate { $0.isActive })
        guard let tasks = try? context.fetch(descriptor) else { return }

        for task in tasks {
            guard let deadline = task.pendingDeadline(asOf: now) else { continue }
            guard let node = task.node else { continue }

            let success = node.isCurrentlyInside
            task.streak = success ? task.streak + 1 : 0
            task.lastEvaluatedDeadline = deadline

            if success {
                // GOAL ACHIEVED: No funds touched, $0 charged!
            } else if task.isPledged && task.pledgeAmount > 0 {
                // DEADLINE MISSED: Charge the vaulted card off-session then and there!
                task.forfeitedCount += 1
                task.totalForfeitedAmount += task.pledgeAmount

                if let custId = BackendClient.shared.currentCustomerId {
                    let cents = Int64(task.pledgeAmount * 100)
                    let title = task.title
                    let tId = task.id
                    Task {
                        _ = try? await BackendClient.shared.forfeitPledge(
                            taskId: tId,
                            customerId: custId,
                            pledgeAmountCents: cents,
                            taskTitle: title,
                            deadlineDate: deadline
                        )
                    }
                }
            }

            let record = CheckInRecord(date: deadline, success: success, task: task)
            context.insert(record)

            NotificationManager.shared.sendTaskResultNotification(for: task, success: success)

            if let next = task.nextDeadline(after: now) {
                NotificationManager.shared.scheduleDeadlineNotification(for: task, at: next)
            }
        }

        try? context.save()
    }
}
