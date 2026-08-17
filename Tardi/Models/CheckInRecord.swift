import Foundation
import SwiftData

/// A single scored occurrence of a habit task's deadline.
@Model
final class CheckInRecord {
    var id: UUID
    var date: Date
    var success: Bool
    var task: HabitTask?

    init(date: Date, success: Bool, task: HabitTask?) {
        self.id = UUID()
        self.date = date
        self.success = success
        self.task = task
    }
}
