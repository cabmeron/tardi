import SwiftUI
import MapKit
import CoreLocation

/// An interactive, lo-fi real map canvas that strips away commercial POI clutter
/// and road labels, focusing purely on real geographic terrain, custom timed
/// habit nodes, geofence boundaries, and smooth high-performance animated routes.
struct LofiMapView: View {
    @Binding var position: MapCameraPosition
    let userCoordinate: CLLocationCoordinate2D?
    let commitments: [Commitment]
    @Binding var draft: DraftLocation?
    var onSelectCommitment: (Commitment) -> Void
    var onTapCoordinate: (CLLocationCoordinate2D) -> Void

    @State private var showTravelLines = true
    @State private var showNodeCards = true

    var body: some View {
        MapReader { proxy in
            ZStack(alignment: .trailing) {
                Map(position: $position) {
                    // 1. Geofence radius circles for commitments
                    ForEach(commitments) { commitment in
                        let center = CLLocationCoordinate2D(
                            latitude: commitment.latitude,
                            longitude: commitment.longitude
                        )
                        let isDone = commitment.isCompletedForToday(asOf: Date())
                        MapCircle(center: center, radius: commitment.radius)
                            .foregroundStyle(
                                (isDone ? Color.green : (commitment.isCurrentlyInside ? Color.green : Color.accentColor))
                                    .opacity(0.12)
                            )
                            .mapOverlayLevel(level: .aboveLabels)
                    }

                    // 2. Draft geofence circle
                    if let draft {
                        MapCircle(center: draft.coordinate, radius: draft.radius)
                            .foregroundStyle(Color.accentColor.opacity(0.18))
                            .mapOverlayLevel(level: .aboveLabels)
                    }

                    // 3. Live user location marker
                    if let userCoordinate {
                        Annotation("You", coordinate: userCoordinate) {
                            UserPresenceMarker()
                        }
                        .annotationTitles(.hidden)
                    }

                    // 4. Active commitment nodes with live fuse rings, time badges, countdowns & per-node ETAs
                    ForEach(commitments) { commitment in
                        let coordinate = CLLocationCoordinate2D(
                            latitude: commitment.latitude,
                            longitude: commitment.longitude
                        )
                        Annotation(commitment.locationName, coordinate: coordinate) {
                            NodeMarkerView(
                                commitment: commitment,
                                now: Date(),
                                userCoordinate: userCoordinate,
                                showDetailCard: showNodeCards
                            )
                            .onTapGesture {
                                onSelectCommitment(commitment)
                            }
                        }
                        .annotationTitles(.hidden)
                    }

                    // 5. Draft pin placement
                    if let draft {
                        Annotation("Draft", coordinate: draft.coordinate) {
                            DraftNodeMarkerView(draft: draft)
                        }
                        .annotationTitles(.hidden)
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
                .mapControlVisibility(.hidden)
                .onTapGesture(coordinateSpace: .local) { screenPoint in
                    if let coordinate = proxy.convert(screenPoint, from: .local) {
                        onTapCoordinate(coordinate)
                    }
                }
                // High-performance, buttery-smooth vector route layer rendered via Canvas
                .overlay {
                    if let userCoordinate, showTravelLines {
                        TimelineView(.animation) { timeline in
                            Canvas { context, _ in
                                guard let userPoint = proxy.convert(userCoordinate, to: .local) else { return }
                                let time = timeline.date.timeIntervalSinceReferenceDate
                                let now = timeline.date

                                for commitment in commitments where commitment.isActive && !commitment.isCompletedForToday(asOf: now) {
                                    let targetCoord = CLLocationCoordinate2D(
                                        latitude: commitment.latitude,
                                        longitude: commitment.longitude
                                    )
                                    guard let targetPoint = proxy.convert(targetCoord, to: .local) else { continue }

                                    let dx = targetPoint.x - userPoint.x
                                    let dy = targetPoint.y - userPoint.y
                                    let screenDist = sqrt(dx * dx + dy * dy)
                                    guard screenDist > 4 else { continue }

                                    let isInside = commitment.isCurrentlyInside
                                    let baseColor = isInside ? Color.green : Color.accentColor

                                    var linePath = Path()
                                    linePath.move(to: userPoint)
                                    linePath.addLine(to: targetPoint)

                                    // Subtle underlying static track
                                    context.stroke(
                                        linePath,
                                        with: .color(baseColor.opacity(0.18)),
                                        lineWidth: isInside ? 1.6 : 1.2
                                    )

                                    // Dynamic dash length adapted to on-screen zoom distance
                                    let dashLen: CGFloat = max(min(screenDist * 0.035, 7.0), 3.5)
                                    let gapLen: CGFloat = dashLen * 1.3
                                    let cycle = dashLen + gapLen
                                    let phase = CGFloat(time * 28).truncatingRemainder(dividingBy: cycle)

                                    // Crisp, continuous flowing dash animation
                                    context.stroke(
                                        linePath,
                                        with: .color(baseColor.opacity(isInside ? 0.85 : 0.7)),
                                        style: StrokeStyle(
                                            lineWidth: isInside ? 2.0 : 1.5,
                                            lineCap: .round,
                                            lineJoin: .round,
                                            dash: [dashLen, gapLen],
                                            dashPhase: -phase
                                        )
                                    )
                                }
                            }
                            .allowsHitTesting(false)
                        }
                    }
                }

                // Floating Controls Overlay (Recenter, Fit Bounds, Line Toggle, Node Card Toggle)
                mapControlsOverlay
                    .padding(.trailing, 16)
                    .padding(.bottom, draft != nil ? 180 : 36)
            }
        }
    }

    // MARK: - Floating Map Controls

    private var mapControlsOverlay: some View {
        VStack(spacing: 10) {
            // Recenter on User
            Button(action: centerOnUser) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(userCoordinate != nil ? Color.accentColor : Color.secondary)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(userCoordinate == nil)

            // Fit All Active Nodes
            if !commitments.isEmpty {
                Button(action: fitAllNodes) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }

            // Toggle Radial Travel Lines
            if !commitments.isEmpty && userCoordinate != nil {
                Button(action: { showTravelLines.toggle() }) {
                    Image(systemName: showTravelLines ? "rays" : "circle.dotted")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(showTravelLines ? Color.accentColor : .secondary)
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }

            // Toggle Node Detail Cards (Time & Distance vs Minimal Node Only)
            if !commitments.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showNodeCards.toggle()
                    }
                }) {
                    Image(systemName: showNodeCards ? "text.badge.minus" : "text.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(showNodeCards ? Color.accentColor : .secondary)
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Camera Helpers

    private func centerOnUser() {
        guard let userCoordinate else { return }
        withAnimation(.easeInOut(duration: 0.8)) {
            position = .region(
                MKCoordinateRegion(
                    center: userCoordinate,
                    latitudinalMeters: 1200,
                    longitudinalMeters: 1200
                )
            )
        }
    }

    private func fitAllNodes() {
        var coordinates = commitments.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        if let userCoordinate {
            coordinates.append(userCoordinate)
        }
        guard !coordinates.isEmpty else { return }

        let minLat = coordinates.map(\.latitude).min() ?? 0
        let maxLat = coordinates.map(\.latitude).max() ?? 0
        let minLon = coordinates.map(\.longitude).min() ?? 0
        let maxLon = coordinates.map(\.longitude).max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.015),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.015)
        )

        withAnimation(.easeInOut(duration: 0.8)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}
