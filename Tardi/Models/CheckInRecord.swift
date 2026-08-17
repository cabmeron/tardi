import Foundation
import SwiftData

/// A single scored occurrence of a commitment's deadline: either the user
/// was inside the geofence, or they weren't.
@Model
final class CheckInRecord {
    var id: UUID
    var date: Date
    var success: Bool
    var commitment: Commitment?

    init(date: Date, success: Bool, commitment: Commitment?) {
        self.id = UUID()
        self.date = date
        self.success = success
        self.commitment = commitment
    }
}
