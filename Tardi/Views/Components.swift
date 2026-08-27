import SwiftUI
import CoreLocation
import UIKit

/// A plain, flat rounded card used to group related controls.
struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

/// Compact "in / out" status dot used in the node detail sheet.
struct PresenceDot: View {
    let isInside: Bool

    var body: some View {
        Circle()
            .fill(isInside ? Color.green : Color.red)
            .frame(width: 10, height: 10)
    }
}

/// A location node's map marker: a clean lined circle when unassigned,
/// or a physical burning fuse ring indicator when a task is armed.
struct FuseRingDot: View {
    let node: LocationNode
    let now: Date

    var body: some View {
        let isDone = node.isAnyTaskCompletedToday(asOf: now)
        let isArmed = !node.activeTasks.isEmpty && !isDone
        let progress = node.fuseProgress(asOf: now) ?? 0

        ZStack {
            if isArmed {
                // 1. Burnt ash track (braided dashed circle)
                Circle()
                    .stroke(Color.secondary.opacity(0.18), style: StrokeStyle(lineWidth: 2.5, dash: [2, 2]))
                    .frame(width: 34, height: 34)

                // 2. Monochrome physical fuse cord
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.primary.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // 3. Burning Ember Head
                if progress > 0.02 && progress < 0.98 {
                    let angleDeg = -90.0 + (progress * 360.0)
                    let rad = angleDeg * .pi / 180.0
                    let r: CGFloat = 17.0
                    let x = CGFloat(Darwin.cos(rad)) * r
                    let y = CGFloat(Darwin.sin(rad)) * r

                    Circle()
                        .fill(Color.orange)
                        .frame(width: 4.5, height: 4.5)
                        .shadow(color: Color.orange, radius: 2)
                        .overlay(Circle().fill(Color.white).frame(width: 2, height: 2))
                        .offset(x: x, y: y)
                }

                // Center core dot
                Circle()
                    .fill(Color.primary)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            } else {
                // Default State: Clean lined circle with center dot (no checks, no failures)
                Circle()
                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 28, height: 28)

                Circle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            }
        }
        .contentShape(Circle())
    }
}

/// Floating transport mode selector with smooth capsule highlight and haptics
struct TravelModePickerBar: View {
    @Binding var selectedMode: TravelMode
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TravelMode.allCases) { mode in
                    let isSelected = selectedMode == mode
                    Button {
                        haptic.impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            selectedMode = mode
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            isSelected ? Color.accentColor : Color(.tertiarySystemFill).opacity(0.7),
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

// MARK: - Map Node Markers

/// A high-visibility interactive location marker for the real map.
/// Displays a clean lined circle if idle/unassigned, or a physical burning fuse indicator when armed.
struct NodeMarkerView: View {
    let node: LocationNode
    let now: Date
    let userCoordinate: CLLocationCoordinate2D?
    let showDetailCard: Bool

    @State private var isPulsing = false

    private var distanceMeters: Double? {
        guard let userCoordinate else { return nil }
        let userLoc = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let nodeLoc = CLLocation(latitude: node.latitude, longitude: node.longitude)
        return userLoc.distance(from: nodeLoc)
    }

    private var isDone: Bool {
        node.isAnyTaskCompletedToday(asOf: now)
    }

    private var isArmed: Bool {
        !node.activeTasks.isEmpty && !isDone
    }

    var body: some View {
        VStack(spacing: 3) {
            // Optional minimal travel ETA pill (only travel duration from where you are to node)
            if showDetailCard, isArmed, let distance = distanceMeters, !node.isCurrentlyInside {
                HStack(spacing: 3) {
                    Image(systemName: node.travelMode.iconName)
                        .font(.system(size: 9, weight: .bold))
                    Text(node.travelMode.formattedETA(distanceMeters: distance))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.secondary.opacity(0.18), lineWidth: 0.5))
                .foregroundStyle(.primary)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            }

            // Center Node with Fuse Ring & Presence Pulse
            ZStack {
                if node.isCurrentlyInside {
                    Circle()
                        .stroke(Color.primary.opacity(0.25), lineWidth: 2)
                        .frame(width: isPulsing ? 44 : 30, height: isPulsing ? 44 : 30)
                        .scaleEffect(isPulsing ? 1.2 : 0.9)
                        .opacity(isPulsing ? 0 : 0.8)
                }

                FuseRingDot(node: node, now: now)
            }
            .frame(width: 36, height: 36)

            // Location title
            Text(node.name)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .onAppear {
            if node.isCurrentlyInside {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
    }
}

/// Marker rendered when placing a draft location on the real map.
struct DraftNodeMarkerView: View {
    let draft: DraftLocation

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("\(Int(draft.radius))m")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor, in: Capsule())
            .shadow(color: Color.accentColor.opacity(0.4), radius: 6, y: 2)

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: pulse ? 44 : 28, height: pulse ? 44 : 28)

                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 28, height: 28)

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            }
            .frame(width: 36, height: 36)

            Text(draft.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// User's live location marker on the lo-fi map with a gentle ambient radar halo.
struct UserPresenceMarker: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: pulse ? 44 : 22, height: pulse ? 44 : 22)

            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2.5))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
