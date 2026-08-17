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

/// A location node's map marker: a dot wrapped in a "fuse" ring that burns down
/// as the nearest upcoming task deadline approaches.
struct FuseRingDot: View {
    let node: LocationNode
    let now: Date

    var body: some View {
        let isDone = node.isAnyTaskCompletedToday(asOf: now)
        let hasActiveTasks = !node.activeTasks.isEmpty
        let color: Color = isDone ? .green : (node.isCurrentlyInside ? .green : (hasActiveTasks ? Color.accentColor : Color.secondary))
        let progress = node.fuseProgress(asOf: now) ?? 0

        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                .frame(width: 34, height: 34)

            if hasActiveTasks {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
            }

            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.green, in: Circle())
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
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

/// Rich, interactive node marker placed on the lo-fi real map canvas.
/// Displays place name, fuse ring, and an optional toggleable top detail card
/// with scheduled time, live time remaining, ETA, and distance in miles.
struct NodeMarkerView: View {
    let node: LocationNode
    let now: Date
    var userCoordinate: CLLocationCoordinate2D? = nil
    var showDetailCard: Bool = true

    @State private var isPulsing = false

    private var distanceMeters: Double? {
        guard let userCoord = userCoordinate else { return nil }
        let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let targetLoc = CLLocation(latitude: node.latitude, longitude: node.longitude)
        return userLoc.distance(from: targetLoc)
    }

    private var nearestTask: HabitTask? {
        node.nearestUpcomingTask(after: now)
    }

    private var arrivalStatus: ArrivalStatus {
        guard let distance = distanceMeters else { return .onTime }
        let deadline = node.nextDeadline(after: now)
        return node.travelMode.arrivalStatus(distanceMeters: distance, deadline: deadline, now: now)
    }

    private var isCompletedToday: Bool {
        node.isAnyTaskCompletedToday(asOf: now)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Optional toggleable label pill floating above node
            if showDetailCard {
                VStack(spacing: 3) {
                    if isCompletedToday {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.green)
                            Text("Checked In")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                    } else if let task = nearestTask {
                        HStack(spacing: 5) {
                            // Scheduled deadline time
                            Text(task.formattedDeadlineTime)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            // Time remaining countdown badge
                            if let remaining = task.timeRemaining(asOf: now) {
                                Text(task.formattedTimeRemaining(asOf: now))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(remaining < 600 ? .orange : .secondary)
                            }

                            // Streak counter
                            if task.streak > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.orange)
                                    Text("\(task.streak)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }

                        // Real-time travel duration & distance in miles
                        if let distance = distanceMeters, !node.isCurrentlyInside {
                            HStack(spacing: 4) {
                                Image(systemName: node.travelMode.iconName)
                                    .font(.system(size: 9, weight: .bold))
                                Text(node.travelMode.formattedETA(distanceMeters: distance))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                Text("·")
                                    .font(.system(size: 9))
                                Text(TravelMode.formatMiles(distanceMeters: distance))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusBackgroundColor, in: Capsule())
                            .foregroundStyle(statusForegroundColor)
                        }
                    } else {
                        // Clean idle badge for nodes without tasks
                        HStack(spacing: 4) {
                            if let distance = distanceMeters {
                                HStack(spacing: 3) {
                                    Image(systemName: node.travelMode.iconName)
                                        .font(.system(size: 9))
                                    Text(TravelMode.formatMiles(distanceMeters: distance))
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                }
                                .foregroundStyle(.secondary)
                            } else {
                                Text("Node Ready")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.secondary.opacity(0.18), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            // Center Node with Fuse Ring & Presence Pulse
            ZStack {
                if node.isCurrentlyInside {
                    Circle()
                        .stroke(Color.green.opacity(0.35), lineWidth: 2)
                        .frame(width: isPulsing ? 48 : 32, height: isPulsing ? 48 : 32)
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

    private var statusBackgroundColor: Color {
        switch arrivalStatus {
        case .onTime:
            return Color.accentColor.opacity(0.15)
        case .approachingDeadline:
            return Color.orange.opacity(0.2)
        case .late:
            return Color.red.opacity(0.2)
        }
    }

    private var statusForegroundColor: Color {
        switch arrivalStatus {
        case .onTime:
            return Color.accentColor
        case .approachingDeadline:
            return Color.orange
        case .late:
            return Color.red
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
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
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
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
