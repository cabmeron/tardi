import Foundation
import CoreLocation

/// A node location currently being placed on the map before saving.
struct DraftLocation: Equatable {
    var coordinate: CLLocationCoordinate2D
    var radius: Double = 100
    var name: String = "Custom Location"

    static func == (lhs: DraftLocation, rhs: DraftLocation) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.radius == rhs.radius
            && lhs.name == rhs.name
    }
}
