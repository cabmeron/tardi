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

/// Compact "in / out" status dot used in the commitment detail sheet.
struct PresenceDot: View {
    let isInside: Bool

    var body: some View {
        Circle()
            .fill(isInside ? Color.green : Color.red)
            .frame(width: 10, height: 10)
    }
}

/// A commitment's map marker: a dot wrapped in a "fuse" ring that burns down
/// from a full circle to nothing as its next deadline approaches.
struct FuseRingDot: View {
    let commitment: Commitment
    let now: Date

    var body: some View {
        let isDone = commitment.isCompletedForToday(asOf: now)
        let color: Color = isDone ? .green : (commitment.isCurrentlyInside ? .green : (commitment.isActive ? Color.accentColor : Color.secondary))
        let progress = commitment.fuseProgress(asOf: now) ?? 0

        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                .frame(width: 34, height: 34)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 34, height: 34)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

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

/// Compact midpoint badge floating along the animated radial path from user to node
struct LineETABadge: View {
    let mode: TravelMode
    let distanceMeters: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: mode.iconName)
                .font(.system(size: 9, weight: .bold))
            Text(mode.formattedETA(distanceMeters: distanceMeters))
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.accentColor.opacity(0.35), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        .foregroundStyle(.primary)
    }
}

/// Rich, interactive node marker placed on the lo-fi real map canvas.
/// Displays place name, fuse ring, and an optional toggleable top detail card
/// with scheduled time, live time remaining, ETA, and distance in miles.
struct NodeMarkerView: View {
    let commitment: Commitment
    let now: Date
    var userCoordinate: CLLocationCoordinate2D? = nil
    var showDetailCard: Bool = true

    @State private var isPulsing = false

    private var distanceMeters: Double? {
        guard let userCoord = userCoordinate else { return nil }
        let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let targetLoc = CLLocation(latitude: commitment.latitude, longitude: commitment.longitude)
        return userLoc.distance(from: targetLoc)
    }

    private var arrivalStatus: ArrivalStatus {
        guard let distance = distanceMeters else { return .onTime }
        return commitment.travelMode.arrivalStatus(distanceMeters: distance, commitment: commitment, now: now)
    }

    private var isCompletedToday: Bool {
        commitment.isCompletedForToday(asOf: now)
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

                            if commitment.streak > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill").font(.system(size: 9)).foregroundStyle(.orange)
                                    Text("\(commitment.streak)").font(.system(size: 10, weight: .bold, design: .rounded))
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 5) {
                            // Scheduled deadline time
                            Text(commitment.formattedDeadlineTime)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            // Time remaining countdown badge
                            if let remaining = commitment.timeRemaining(asOf: now) {
                                Text(commitment.formattedTimeRemaining(asOf: now))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(remaining < 600 ? .orange : .secondary)
                            }

                            // Streak counter
                            if commitment.streak > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.orange)
                                    Text("\(commitment.streak)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }

                        // Real-time travel duration & distance in miles
                        if let distance = distanceMeters, !commitment.isCurrentlyInside {
                            HStack(spacing: 4) {
                                Image(systemName: commitment.travelMode.iconName)
                                    .font(.system(size: 9, weight: .bold))
                                Text(commitment.travelMode.formattedETA(distanceMeters: distance))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                Text("·")
                                    .font(.system(size: 9))
                                Text(Commitment.formatMiles(distanceMeters: distance))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusBackgroundColor, in: Capsule())
                            .foregroundStyle(statusForegroundColor)
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
                if commitment.isCurrentlyInside {
                    Circle()
                        .stroke(Color.green.opacity(0.35), lineWidth: 2)
                        .frame(width: isPulsing ? 48 : 32, height: isPulsing ? 48 : 32)
                        .scaleEffect(isPulsing ? 1.2 : 0.9)
                        .opacity(isPulsing ? 0 : 0.8)
                }

                FuseRingDot(commitment: commitment, now: now)
            }
            .frame(width: 36, height: 36)

            // Location title
            Text(commitment.locationName)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .onAppear {
            if commitment.isCurrentlyInside {
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

/// Elaborate animated countdown timer with burning fuse arc and live ticking seconds
struct ElaborateCountdownTimerView: View {
    let commitment: Commitment
    let now: Date

    @State private var emberPulse = false

    private var isDone: Bool {
        commitment.isCompletedForToday(asOf: now)
    }

    private var timeRemaining: TimeInterval {
        commitment.timeRemaining(asOf: now) ?? 0
    }

    private var progress: Double {
        commitment.fuseProgress(asOf: now) ?? 0
    }

    private var hours: Int {
        Int(timeRemaining) / 3600
    }

    private var minutes: Int {
        (Int(timeRemaining) % 3600) / 60
    }

    private var seconds: Int {
        Int(timeRemaining) % 60
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 10)
                    .frame(width: 170, height: 170)

                // Burning Fuse Arc or Completed Green Ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isDone
                            ? AnyShapeStyle(Color.green)
                            : AnyShapeStyle(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        commitment.isCurrentlyInside ? .green : Color.accentColor,
                                        .orange,
                                        .red
                                    ]),
                                    center: .center,
                                    startAngle: .degrees(-90),
                                    endAngle: .degrees(270)
                                )
                            ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Burning Fuse Ember at Arc Tip (only when active and not completed)
                if !isDone && progress > 0.01 && progress < 0.99 {
                    let angle = Angle.degrees(-90 + progress * 360)
                    let radius: CGFloat = 85
                    let emberX = cos(angle.radians) * radius
                    let emberY = sin(angle.radians) * radius

                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.5))
                            .frame(width: emberPulse ? 22 : 12, height: emberPulse ? 22 : 12)
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 8, height: 8)
                    }
                    .offset(x: emberX, y: emberY)
                }

                // Digital Countdown or Completion Status Display
                if isDone {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.green)
                        Text("CHECKED IN")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .tracking(1)
                        Text("Streak: \(commitment.streak) 🔥")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                } else {
                    VStack(spacing: 4) {
                        Text("TIME REMAINING")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(1.2)

                        HStack(spacing: 2) {
                            timeUnitView(value: hours, label: "H")
                            Text(":").font(.system(.title3, design: .monospaced, weight: .bold)).foregroundStyle(.secondary)
                            timeUnitView(value: minutes, label: "M")
                            Text(":").font(.system(.title3, design: .monospaced, weight: .bold)).foregroundStyle(.secondary)
                            timeUnitView(value: seconds, label: "S")
                        }

                        HStack(spacing: 6) {
                            PresenceDot(isInside: commitment.isCurrentlyInside)
                            Text(commitment.isCurrentlyInside ? "At Location" : "Away")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(commitment.isCurrentlyInside ? .green : .secondary)
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .frame(height: 190)
        }
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                emberPulse = true
            }
        }
    }

    private func timeUnitView(value: Int, label: String) -> some View {
        VStack(spacing: 0) {
            Text(String(format: "%02d", value))
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}

/// Card calculating and recommending the latest time to leave for a destination
struct TimeToLeaveCard: View {
    let commitment: Commitment
    let userCoordinate: CLLocationCoordinate2D?
    let now: Date

    private var distanceMeters: Double? {
        guard let userCoord = userCoordinate else { return nil }
        let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let targetLoc = CLLocation(latitude: commitment.latitude, longitude: commitment.longitude)
        return userLoc.distance(from: targetLoc)
    }

    private var travelSeconds: TimeInterval? {
        guard let dist = distanceMeters else { return nil }
        return commitment.travelMode.estimatedTravelTime(distanceMeters: dist)
    }

    private var latestDeparture: Date? {
        commitment.latestDepartureTime(from: userCoordinate, asOf: now)
    }

    private var secondsUntilDeparture: TimeInterval? {
        commitment.timeUntilDeparture(from: userCoordinate, asOf: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("TIME TO LEAVE", systemImage: "clock.badge.exclamationmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .tracking(1)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: commitment.travelMode.iconName)
                    Text(commitment.travelMode.rawValue)
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .foregroundStyle(Color.accentColor)
            }

            if commitment.isCompletedForToday(asOf: now) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Habit completed for today!")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("Your streak is secured until the next scheduled occurrence.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else if commitment.isCurrentlyInside {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're currently here!")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("You can check in early below to complete this node today.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else if let leaveTime = latestDeparture, let timeRemaining = secondsUntilDeparture {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(leaveTime.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(timeRemaining < 0 ? .red : .primary)

                        Text(timeRemaining >= 0 ? "Latest departure" : "You're running late!")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(timeRemaining < 0 ? .red : .secondary)
                    }

                    // Urgency Countdown Banner
                    HStack(spacing: 8) {
                        Image(systemName: departureStatusIcon(timeRemaining))
                        Text(departureStatusText(timeRemaining))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(departureStatusColor(timeRemaining).opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(departureStatusColor(timeRemaining))

                    if let dist = distanceMeters, let travelSecs = travelSeconds {
                        HStack {
                            Text("\(commitment.travelMode.rawValue) ETA: \(Int(ceil(travelSecs / 60))) min")
                            Text("·")
                            Text("\(Commitment.formatMiles(distanceMeters: dist)) away")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }
                }
            } else {
                Text("Enable location to calculate recommended departure time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func departureStatusText(_ seconds: TimeInterval) -> String {
        if seconds < -60 {
            let minsLate = Int(abs(seconds) / 60)
            return "Depart immediately! (\(minsLate) min behind)"
        } else if seconds < 0 {
            return "Depart now to arrive on time!"
        } else if seconds < 600 {
            let minsLeft = Int(ceil(seconds / 60))
            return "Leave in \(minsLeft) min · Get ready!"
        } else {
            let minsLeft = Int(ceil(seconds / 60))
            let hours = minsLeft / 60
            let remMins = minsLeft % 60
            let durationStr = hours > 0 ? "\(hours)h \(remMins)m" : "\(minsLeft) min"
            return "Leave in \(durationStr) · On schedule"
        }
    }

    private func departureStatusIcon(_ seconds: TimeInterval) -> String {
        if seconds < 0 {
            return "exclamationmark.triangle.fill"
        } else if seconds < 600 {
            return "figure.walk.motion"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private func departureStatusColor(_ seconds: TimeInterval) -> Color {
        if seconds < 0 {
            return .red
        } else if seconds < 600 {
            return .orange
        } else {
            return .green
        }
    }
}

/// Renders a commitment's schedule as a short, glanceable string
enum ScheduleFormatter {
    static func summary(for commitment: Commitment) -> String {
        let time = timeString(hour: commitment.deadlineHour, minute: commitment.deadlineMinute)

        if commitment.isRecurring {
            let symbols = Calendar.current.shortWeekdaySymbols
            let names = commitment.weekdays.sorted().compactMap { weekday -> String? in
                guard weekday >= 1, weekday <= symbols.count else { return nil }
                return symbols[weekday - 1]
            }
            return "\(names.joined(separator: ", ")) · \(time)"
        } else if let date = commitment.oneTimeDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: date)) · \(time)"
        }
        return time
    }

    private static func timeString(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
