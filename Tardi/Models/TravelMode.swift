import Foundation
import CoreLocation

/// Modes of transportation available for calculating estimated travel time (ETA)
/// and departure recommendations to habit nodes.
enum TravelMode: String, CaseIterable, Identifiable {
    case walking = "Walk"
    case skateboard = "Skate"
    case scooter = "Scooter"
    case bicycle = "Bike"
    case bus = "Bus"
    case train = "Train"
    case car = "Car"

    var id: String { rawValue }

    /// SF Symbol icon representing the transport mode
    var iconName: String {
        switch self {
        case .walking: return "figure.walk"
        case .skateboard: return "figure.skateboarding"
        case .scooter: return "scooter"
        case .bicycle: return "bicycle"
        case .bus: return "bus.fill"
        case .train: return "tram.fill"
        case .car: return "car.fill"
        }
    }

    /// Calibrated average urban speed in meters per second (m/s)
    var averageSpeedMps: Double {
        switch self {
        case .walking: return 1.39       // ~5.0 km/h (brisk walk)
        case .skateboard: return 3.33    // ~12.0 km/h (skateboarding / longboarding)
        case .bicycle: return 4.72       // ~17.0 km/h (city cycling)
        case .scooter: return 5.56       // ~20.0 km/h (electric scooter)
        case .bus: return 6.39           // ~23.0 km/h (bus including stops & traffic)
        case .car: return 9.72           // ~35.0 km/h (city driving & signals)
        case .train: return 13.89        // ~50.0 km/h (metro / light rail / commuter)
        }
    }

    /// Estimated travel duration in seconds given direct Euclidean/great-circle distance in meters
    func estimatedTravelTime(distanceMeters: Double) -> TimeInterval {
        let routeMultiplier: Double = (self == .train) ? 1.12 : 1.28
        let actualDistance = distanceMeters * routeMultiplier

        let startPenalty: TimeInterval
        switch self {
        case .walking: startPenalty = 0
        case .skateboard, .bicycle, .scooter: startPenalty = 30
        case .car: startPenalty = 90
        case .bus: startPenalty = 180
        case .train: startPenalty = 240
        }

        return (actualDistance / averageSpeedMps) + startPenalty
    }

    /// Concise, glanceable ETA string (e.g. "4m", "18m", "1h 12m")
    func formattedETA(distanceMeters: Double) -> String {
        let seconds = estimatedTravelTime(distanceMeters: distanceMeters)
        let minutes = Int(ceil(seconds / 60))

        if minutes < 1 {
            return "<1m"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remMinutes = minutes % 60
            return remMinutes > 0 ? "\(hours)h \(remMinutes)m" : "\(hours)h"
        }
    }

    /// Checks whether the user will arrive at the commitment before its deadline
    func arrivalStatus(
        distanceMeters: Double,
        commitment: Commitment,
        now: Date = Date()
    ) -> ArrivalStatus {
        guard let deadline = commitment.nextDeadline(after: now) else {
            return .onTime
        }

        let travelSeconds = estimatedTravelTime(distanceMeters: distanceMeters)
        let arrivalDate = now.addingTimeInterval(travelSeconds)

        if arrivalDate <= deadline {
            let marginMinutes = (deadline.timeIntervalSince(arrivalDate)) / 60
            return marginMinutes > 15 ? .onTime : .approachingDeadline
        } else {
            let lateMinutes = Int(ceil((arrivalDate.timeIntervalSince(deadline)) / 60))
            return .late(minutes: lateMinutes)
        }
    }
}

/// Status indicating whether the user can make the deadline based on live ETA
enum ArrivalStatus {
    case onTime
    case approachingDeadline
    case late(minutes: Int)
}
