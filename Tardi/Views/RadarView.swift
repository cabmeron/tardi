import SwiftUI
import CoreLocation

/// A commitment being placed: its real coordinate, geofence radius, and a
/// display name (resolved via reverse-geocoding if it didn't come from a
/// search result).
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

/// A hand-drawn, text-free stand-in for a map: you're always the dot at the
/// center, and every commitment is a colored dot placed by real bearing and
/// distance from you (green while inside its geofence, red while not). Tap
/// anywhere empty to start placing a new one — its geofence radius is a
/// dashed ring right next to its dot, resized by dragging the small handle
/// on its edge. There's no basemap, no street/POI labels, no numbers.
struct RadarView: View {
    let userCoordinate: CLLocationCoordinate2D?
    let commitments: [Commitment]
    @Binding var draft: DraftLocation?
    var onSelectCommitment: (Commitment) -> Void = { _ in }
    var onTapEmptySpace: (CLLocationCoordinate2D) -> Void = { _ in }

    /// Distance, in meters, that reaches the outer edge of the radar. Chosen
    /// to comfortably fit a typical day's worth of places (home, gym, work)
    /// without every commitment collapsing to a single edge point.
    private let maxDistanceMeters: Double = 3000
    private let ringCount = 3

    /// The draft's radius ring is drawn at a fixed pixel scale, not the
    /// radar's geographic one — a real 25-1000m geofence would be an
    /// invisible speck against a multi-kilometer radar, so this range is
    /// purely about making the handle usable, not to-scale accuracy.
    private let radiusMetersRange: ClosedRange<Double> = 25...1000
    private let handlePxRange: ClosedRange<CGFloat> = 28...100

    @State private var pulse = false
    @State private var dragStartRadius: Double?
    @State private var isDraggingHandle = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let maxRadius = min(geometry.size.width, geometry.size.height) / 2 - 32

                ZStack {
                    rings(maxRadius: maxRadius)

                    if let userCoordinate {
                        ForEach(commitments) { commitment in
                            let coordinate = CLLocationCoordinate2D(latitude: commitment.latitude, longitude: commitment.longitude)
                            FuseRingDot(commitment: commitment, now: context.date)
                                .position(RadarGeometry.point(for: coordinate, from: userCoordinate, center: center, maxRadius: maxRadius, maxDistanceMeters: maxDistanceMeters))
                                .onTapGesture { onSelectCommitment(commitment) }
                        }

                        if let currentDraft = draft {
                            draftLayer(current: currentDraft, userCoordinate: userCoordinate, center: center, maxRadius: maxRadius)
                        }
                    }

                    youDot
                        .position(center)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            guard let userCoordinate else { return }
                            let coordinate = RadarGeometry.coordinate(
                                atScreenPoint: value.location,
                                userCoordinate: userCoordinate,
                                center: center,
                                maxRadius: maxRadius,
                                maxDistanceMeters: maxDistanceMeters
                            )
                            onTapEmptySpace(coordinate)
                        }
                )
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Draft placement

    @ViewBuilder
    private func draftLayer(current: DraftLocation, userCoordinate: CLLocationCoordinate2D, center: CGPoint, maxRadius: CGFloat) -> some View {
        let dotPosition = RadarGeometry.point(for: current.coordinate, from: userCoordinate, center: center, maxRadius: maxRadius, maxDistanceMeters: maxDistanceMeters)
        let handleOffsetPx = handleOffset(forRadius: current.radius)

        Circle()
            .stroke(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .frame(width: handleOffsetPx * 2, height: handleOffsetPx * 2)
            .position(dotPosition)

        Circle()
            .fill(Color.accentColor)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            .position(dotPosition)

        if isDraggingHandle {
            Text("\(Int(current.radius)) m")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
                .position(x: dotPosition.x, y: dotPosition.y - handleOffsetPx - 20)
        }

        Circle()
            .fill(.white)
            .frame(width: 24, height: 24)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .position(x: dotPosition.x + handleOffsetPx, y: dotPosition.y)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingHandle = true
                        if dragStartRadius == nil { dragStartRadius = current.radius }
                        guard let startRadius = dragStartRadius else { return }
                        let newOffset = handleOffset(forRadius: startRadius) + value.translation.width
                        draft?.radius = radius(forHandleOffset: newOffset)
                    }
                    .onEnded { _ in
                        dragStartRadius = nil
                        isDraggingHandle = false
                    }
            )
    }

    private func handleOffset(forRadius radius: Double) -> CGFloat {
        let t = (radius - radiusMetersRange.lowerBound) / (radiusMetersRange.upperBound - radiusMetersRange.lowerBound)
        return handlePxRange.lowerBound + CGFloat(t) * (handlePxRange.upperBound - handlePxRange.lowerBound)
    }

    private func radius(forHandleOffset offset: CGFloat) -> Double {
        let clamped = min(max(offset, handlePxRange.lowerBound), handlePxRange.upperBound)
        let t = (clamped - handlePxRange.lowerBound) / (handlePxRange.upperBound - handlePxRange.lowerBound)
        return radiusMetersRange.lowerBound + Double(t) * (radiusMetersRange.upperBound - radiusMetersRange.lowerBound)
    }

    // MARK: - Drawing

    private func rings(maxRadius: CGFloat) -> some View {
        ForEach(1...ringCount, id: \.self) { step in
            let diameter = maxRadius * 2 * CGFloat(step) / CGFloat(ringCount)
            Circle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                .frame(width: diameter, height: diameter)
        }
    }

    private var youDot: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.25))
                .frame(width: pulse ? 46 : 24, height: pulse ? 46 : 24)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
        }
    }
}
