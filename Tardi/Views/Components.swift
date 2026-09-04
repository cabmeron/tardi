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

/// Evaluated snapshot of a node's state to prevent duplicate queries between parent and child components
struct NodeUrgencySnapshot {
    let isArmed: Bool
    let isDone: Bool
    let isMissed: Bool
    let remaining: TimeInterval
    let progress: Double
    let totalMissed: Double
    let nearestTask: HabitTask?
}

/// A location node's map marker: a clean lined circle when unassigned,
/// or a dynamic burning fuse countdown ring displaying relative urgency when a task is armed.
struct FuseRingDot: View {
    let node: LocationNode
    let snapshot: NodeUrgencySnapshot

    var body: some View {
        let isArmed = snapshot.isArmed
        let isDone = snapshot.isDone
        let isMissed = snapshot.isMissed
        let remaining = snapshot.remaining
        let progress = isArmed ? snapshot.progress : 0

        // Relative urgency thresholds
        let isCritical = remaining > 0 && remaining <= 1800 // < 30m: Critical urgency
        let isHighUrgency = remaining > 0 && remaining <= 7200 // < 2h: High urgency

        ZStack {
            if isArmed && progress > 0 {
                // 1. Etched calibration track
                Circle()
                    .stroke(Color.black.opacity(0.18), style: StrokeStyle(lineWidth: 2.5, dash: [2, 2]))
                    .frame(width: 34, height: 34)

                // 2. International Safety Orange Fuse Cord (Remaining countdown cord)
                Circle()
                    .trim(from: 0, to: CGFloat(max(progress, 0.05)))
                    .stroke(
                        Color(red: 1.0, green: 0.42, blue: 0.06),
                        style: StrokeStyle(lineWidth: 3.0, lineCap: .round)
                    )
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color(red: 1.0, green: 0.40, blue: 0.05).opacity(0.6), radius: 2)
                    .animation(.linear(duration: 1), value: progress)

                // 3. Dynamic Burning Ember Head (ALWAYS visible at the tip when armed!)
                let clampedProgress = min(max(progress, 0.05), 0.98)
                let angleDeg = -90.0 + (clampedProgress * 360.0)
                let rad = angleDeg * .pi / 180.0
                let r: CGFloat = 17.0
                let x = CGFloat(Darwin.cos(rad)) * r
                let y = CGFloat(Darwin.sin(rad)) * r

                ZStack {
                    // Outer heat aura / urgency glow
                    Circle()
                        .fill(isCritical ? Color(red: 1.0, green: 0.35, blue: 0.0) : (isHighUrgency ? Color.orange : Color(red: 1.0, green: 0.75, blue: 0.2)))
                        .frame(width: isCritical ? 11 : 8, height: isCritical ? 11 : 8)
                        .blur(radius: isCritical ? 2.5 : 1.5)
                        .opacity(0.85)

                    // Sizzling ember core
                    Circle()
                        .fill(Color(red: 1.0, green: 0.42, blue: 0.06))
                        .frame(width: 5, height: 5)
                        .shadow(color: Color.orange, radius: 3)

                    // White-hot center spark
                    Circle()
                        .fill(Color.white)
                        .frame(width: 2.5, height: 2.5)
                }
                .offset(x: x, y: y)

                // Slate aluminum center core dot with crisp white border
                Circle()
                    .fill(Color(red: 0.10, green: 0.12, blue: 0.14))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            } else if isDone {
                // Cleared State: Clean green secured indicator
                Circle()
                    .stroke(Color.green.opacity(0.4), lineWidth: 1.8)
                    .frame(width: 30, height: 30)

                Circle()
                    .fill(Color(red: 0.10, green: 0.12, blue: 0.14))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.green.opacity(0.85), lineWidth: 1.5))
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 6.5, weight: .black))
                            .foregroundStyle(Color.green)
                    )
            } else if isMissed {
                // Missed / Forfeited State: Burnt-out cold track with subtle red indicator
                Circle()
                    .stroke(Color.red.opacity(0.35), style: StrokeStyle(lineWidth: 1.8, dash: [3, 2]))
                    .frame(width: 32, height: 32)

                Circle()
                    .fill(Color(red: 0.12, green: 0.13, blue: 0.15))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.red.opacity(0.8), lineWidth: 1.5))
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 6.5, weight: .black))
                            .foregroundStyle(Color.red)
                    )
            } else {
                // Default State: Solid black ring and solid black center dot
                Circle()
                    .stroke(Color.black, lineWidth: 2)
                    .frame(width: 28, height: 28)

                Circle()
                    .fill(Color.black)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            }
        }
        .contentShape(Circle())
    }
}

/// Floating transport mode selector with smooth capsule highlight and haptics
struct TravelModePickerBar: View {
    @Binding var selectedMode: TravelMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TravelMode.allCases) { mode in
                    modeButton(for: mode)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func modeButton(for mode: TravelMode) -> some View {
        let isSelected = selectedMode == mode
        Button {
            HapticManager.triggerLight()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 11, weight: .bold))
                Text(mode.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected ? Color.black : Color(.secondarySystemGroupedBackground),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}


/// Dynamic map marker displaying node presence, burning fuse countdown, and state pills
struct NodeMarkerView: View {
    let node: LocationNode
    let now: Date
    let userCoordinate: CLLocationCoordinate2D?
    let showDetailCard: Bool

    @State private var isPulsing = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let currentNow = timeline.date
            let isArmed = node.hasArmedTask(asOf: currentNow)
            let isDone = node.isAllTasksCompletedToday(asOf: currentNow) || node.isAnyTaskCompletedToday(asOf: currentNow)
            let nearest = isArmed ? node.nearestUpcomingTask(after: currentNow) : nil
            let remaining = nearest?.timeRemaining(asOf: currentNow) ?? 0
            let progress = isArmed ? (node.fuseProgress(asOf: currentNow) ?? 0) : 0
            let totalMissed = !isDone ? node.tasks.reduce(0.0) { $0 + $1.amountMissed(asOf: currentNow) } : 0.0
            let isMissed = !isDone && totalMissed > 0 && node.hasMissedTask(asOf: currentNow)

            let snapshot = NodeUrgencySnapshot(
                isArmed: isArmed,
                isDone: isDone,
                isMissed: isMissed,
                remaining: remaining,
                progress: progress,
                totalMissed: totalMissed,
                nearestTask: nearest
            )

            VStack(spacing: 3) {
                // Urgency & Travel ETA Pill
                if showDetailCard {
                    if snapshot.isArmed {
                        HStack(spacing: 4) {
                            if let nearest = snapshot.nearestTask, nearest.isPledged && nearest.pledgeAmount > 0 {
                                Text("$\(Int(nearest.pledgeAmount))")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundStyle(snapshot.remaining <= 1800 ? Color.red : Color.orange)
                            }

                            // Urgency Flame Icon
                            Image(systemName: snapshot.remaining <= 1800 ? "flame.fill" : (snapshot.remaining <= 7200 ? "flame" : "timer"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(snapshot.remaining <= 1800 ? Color.red : (snapshot.remaining <= 7200 ? Color.orange : Color.primary))

                            // Relative countdown / phase text
                            Text(snapshot.nearestTask?.formattedTimeRemaining(asOf: currentNow) ?? "Armed")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(
                                snapshot.remaining <= 1800 ? Color.red.opacity(0.5) : (snapshot.remaining <= 7200 ? Color.orange.opacity(0.4) : Color.secondary.opacity(0.18)),
                                lineWidth: snapshot.remaining <= 1800 ? 1.2 : 0.6
                            )
                        )
                        .foregroundStyle(.primary)
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                    } else if snapshot.isDone {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.16), in: Capsule())
                        .overlay(
                            Capsule().stroke(Color.green.opacity(0.55), lineWidth: 1.0)
                        )
                        .shadow(color: Color.green.opacity(0.2), radius: 3, y: 1)
                    } else if snapshot.isMissed && snapshot.totalMissed > 0 {
                        HStack(spacing: 3) {
                            Text("-$\(Int(snapshot.totalMissed))")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(Color.red.opacity(0.35), lineWidth: 0.8)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                    }
                }

                // Center Node with Fuse Ring & Presence Pulse
                ZStack {
                    if node.isCurrentlyInside {
                        Circle()
                            .stroke(Color.black.opacity(0.35), lineWidth: 2)
                            .frame(width: isPulsing ? 44 : 30, height: isPulsing ? 44 : 30)
                            .scaleEffect(isPulsing ? 1.2 : 0.9)
                            .opacity(isPulsing ? 0 : 0.8)
                    }

                    FuseRingDot(node: node, snapshot: snapshot)
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
            .background(Color.black, in: Capsule())
            .shadow(color: Color.black.opacity(0.3), radius: 6, y: 2)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: pulse ? 44 : 28, height: pulse ? 44 : 28)

                Circle()
                    .stroke(Color.black, lineWidth: 2)
                    .frame(width: 28, height: 28)

                Circle()
                    .fill(Color.black)
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
