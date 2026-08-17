import CoreLocation
import CoreGraphics

/// Pure geometry for projecting real coordinates onto the radar's
/// bearing/distance display, and back off of it again — decoupled from any
/// particular view so both rendering and tap/drag handling share one
/// implementation.
enum RadarGeometry {
    /// Square-root-scaled forward projection: real coordinate -> screen
    /// point. The square root gives better separation between nearby points
    /// while still compressing far-away ones toward the edge instead of
    /// letting them fly off-screen.
    static func point(
        for coordinate: CLLocationCoordinate2D,
        from userCoordinate: CLLocationCoordinate2D,
        center: CGPoint,
        maxRadius: CGFloat,
        maxDistanceMeters: Double
    ) -> CGPoint {
        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = userLocation.distance(from: targetLocation)
        let bearingRadians = bearing(from: userCoordinate, to: coordinate) * .pi / 180

        let clamped = min(distance, maxDistanceMeters)
        let normalized = maxDistanceMeters > 0 ? sqrt(clamped / maxDistanceMeters) : 0
        let radius = CGFloat(normalized) * maxRadius

        let dx = sin(bearingRadians) * Double(radius)
        let dy = -cos(bearingRadians) * Double(radius) // screen y grows downward; north is up
        return CGPoint(x: center.x + dx, y: center.y + dy)
    }

    /// Inverse of `point(for:from:center:maxRadius:maxDistanceMeters:)`:
    /// screen point -> real coordinate, given the same projection
    /// parameters. This is what makes tapping the radar meaningful.
    static func coordinate(
        atScreenPoint point: CGPoint,
        userCoordinate: CLLocationCoordinate2D,
        center: CGPoint,
        maxRadius: CGFloat,
        maxDistanceMeters: Double
    ) -> CLLocationCoordinate2D {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let radiusPx = sqrt(dx * dx + dy * dy)

        let normalized = maxRadius > 0 ? min(radiusPx / Double(maxRadius), 1) : 0
        let distanceMeters = normalized * normalized * maxDistanceMeters // inverse of the sqrt scale above

        // atan2(dx, -dy) is the inverse of dx = sin(bearing)*r, dy = -cos(bearing)*r.
        let bearingDegrees = (atan2(dx, -dy) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)

        return destination(from: userCoordinate, distanceMeters: distanceMeters, bearingDegrees: bearingDegrees)
    }

    /// Initial compass bearing from `start` to `end`, in degrees clockwise
    /// from north (0..<360).
    static func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        let deltaLon = lon2 - lon1

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// The coordinate reached by travelling `distanceMeters` from `start` on
    /// initial bearing `bearingDegrees` (clockwise from north).
    static func destination(
        from start: CLLocationCoordinate2D,
        distanceMeters: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let earthRadius = 6_371_000.0
        let bearing = bearingDegrees * .pi / 180
        let angularDistance = distanceMeters / earthRadius

        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing))
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}
