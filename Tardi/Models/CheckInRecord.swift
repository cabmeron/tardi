import Foundation
import SwiftData

/// A single scored occurrence of a habit task's deadline.
@Model
final class CheckInRecord {
    var id: UUID
    var date: Date
    var success: Bool
    var isLocationVerified: Bool = false
    var distanceMeters: Double? = nil
    var task: HabitTask?

    init(date: Date, success: Bool, isLocationVerified: Bool = false, distanceMeters: Double? = nil, task: HabitTask?) {
        self.id = UUID()
        self.date = date
        self.success = success
        self.isLocationVerified = isLocationVerified
        self.distanceMeters = distanceMeters
        self.task = task
    }
}
