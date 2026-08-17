import Foundation
import SwiftData

/// Scores commitments whose deadline has passed based on the last geofence state.
@MainActor
enum CommitmentEvaluator {
    static func evaluateDueCommitments(in context: ModelContext, now: Date = Date()) {
        let descriptor = FetchDescriptor<Commitment>(predicate: #Predicate { $0.isActive })
        guard let commitments = try? context.fetch(descriptor) else { return }

        for commitment in commitments {
            guard let deadline = commitment.pendingDeadline(asOf: now) else { continue }

            let success = commitment.isCurrentlyInside
            commitment.streak = success ? commitment.streak + 1 : 0
            commitment.lastEvaluatedDeadline = deadline

            let record = CheckInRecord(date: deadline, success: success, commitment: commitment)
            context.insert(record)

            NotificationManager.shared.sendResultNotification(for: commitment, success: success)

            if let next = commitment.nextDeadline(after: now) {
                NotificationManager.shared.scheduleDeadlineNotification(for: commitment, at: next)
            }
        }

        try? context.save()
    }
}
