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
                // GOAL ACHIEVED: Cancel the pre-authorized PaymentIntent hold!
                if let piId = task.activePaymentIntentId {
                    let tId = task.id
                    Task {
                        _ = try? await BackendClient.shared.cancelPaymentIntent(paymentIntentId: piId, taskId: tId)
                    }
                    task.activePaymentIntentId = nil
                }
            } else if task.isPledged && task.pledgeAmount > 0 {
                // DEADLINE MISSED: Capture or Forfeit the PaymentIntent!
                task.forfeitedCount += 1
                task.totalForfeitedAmount += task.pledgeAmount

                if let piId = task.activePaymentIntentId {
                    let cents = Int64(task.pledgeAmount * 100)
                    Task {
                        _ = try? await BackendClient.shared.capturePaymentIntent(paymentIntentId: piId, amountCents: cents)
                    }
                    task.activePaymentIntentId = nil
                } else if let custId = BackendClient.shared.currentCustomerId {
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
