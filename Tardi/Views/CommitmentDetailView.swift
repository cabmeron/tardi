import SwiftUI
import CoreLocation
import UIKit

/// Presented as a sheet when a commitment's node is tapped on the map.
/// Built with a clean, symmetrical, and uncluttered layout:
/// - Centered header & schedule subtitle
/// - Symmetrical hero countdown ring
/// - 2x2 balanced metric grid (Departure, Transit, Streak, Radius)
/// - Single primary action button (Early Check-In)
/// - Clean secondary settings & history
struct CommitmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var commitment: Commitment
    var userCoordinate: CLLocationCoordinate2D? = LocationManager.shared.currentCoordinate

    @State private var isEditingName = false
    @State private var editedName = ""

    private let hapticFeedback = UINotificationFeedbackGenerator()

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Centered Symmetrical Header
                        headerSection

                        // 2. Hero Centerpiece: Symmetrical Countdown Ring
                        heroCountdownRing(now: context.date)

                        // 3. Primary Action: Early Check-In Button
                        actionButton(now: context.date)

                        // 4. Symmetrical 2x2 Metric Grid
                        metricGrid(now: context.date)

                        // 5. Settings & Transit Mode Card
                        settingsSection

                        // 6. Recent History Summary
                        historySection

                        // 7. Quiet Delete Node Action
                        deleteButton
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
    }

    // MARK: - 1. Centered Header Section

    private var headerSection: some View {
        VStack(spacing: 6) {
            if isEditingName {
                HStack(spacing: 8) {
                    TextField("Location Name", text: $editedName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("Save") {
                        if !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            commitment.locationName = editedName
                            try? modelContext.save()
                        }
                        isEditingName = false
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            } else {
                HStack(spacing: 6) {
                    Text(commitment.locationName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Button {
                        editedName = commitment.locationName
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Clean, glanceable schedule subtitle
            Text(ScheduleFormatter.summary(for: commitment))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - 2. Hero Centerpiece Countdown Ring

    private func heroCountdownRing(now: Date) -> some View {
        let isDone = commitment.isCompletedForToday(asOf: now)
        let progress = commitment.fuseProgress(asOf: now) ?? 0
        let timeRemaining = commitment.timeRemaining(asOf: now) ?? 0

        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60

        return ZStack {
            // Ambient Outer Track
            Circle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 8)
                .frame(width: 174, height: 174)

            // Dynamic Progress Ring
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
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 174, height: 174)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            // Inner Centered Content
            VStack(spacing: 4) {
                if isDone {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.green)

                    Text("CHECKED IN")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .tracking(1)

                    Text("Streak +1 Secured")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text("DEADLINE IN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)

                    HStack(spacing: 2) {
                        timeBlock(value: hours, label: "H")
                        Text(":").font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        timeBlock(value: minutes, label: "M")
                        Text(":").font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        timeBlock(value: seconds, label: "S")
                    }

                    // Presence status pill
                    HStack(spacing: 5) {
                        Circle()
                            .fill(commitment.isCurrentlyInside ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(commitment.isCurrentlyInside ? "At Location" : "Away")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(commitment.isCurrentlyInside ? .green : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                    .padding(.top, 2)
                }
            }
        }
        .frame(height: 190)
    }

    private func timeBlock(value: Int, label: String) -> some View {
        VStack(spacing: 0) {
            Text(String(format: "%02d", value))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 3. Primary Early Check-In Action Button

    private func actionButton(now: Date) -> some View {
        let isDone = commitment.isCompletedForToday(asOf: now)

        return Button {
            if !isDone {
                performEarlyCheckIn()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(isDone ? "Completed for Today" : (commitment.isCurrentlyInside ? "Check In Early" : "Check In & Clear Today"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isDone
                    ? Color.green.opacity(0.18)
                    : (commitment.isCurrentlyInside ? Color.green : Color.accentColor),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(isDone ? Color.green : Color.white)
            .shadow(color: isDone ? .clear : (commitment.isCurrentlyInside ? Color.green : Color.accentColor).opacity(0.3), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isDone)
    }

    // MARK: - 4. Symmetrical 2x2 Metric Grid

    private func metricGrid(now: Date) -> some View {
        let distance = calculatedDistance
        let leaveTime = commitment.latestDepartureTime(from: userCoordinate, asOf: now)
        let timeUntilLeave = commitment.timeUntilDeparture(from: userCoordinate, asOf: now)

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // Tile 1: Latest Departure
            metricTile(
                icon: "clock.badge.exclamationmark",
                iconColor: .orange,
                title: "TIME TO LEAVE",
                value: leaveTime?.formatted(date: .omitted, time: .shortened) ?? "--:--",
                subtitle: departureSubtitle(seconds: timeUntilLeave)
            )

            // Tile 2: Transit & Distance
            metricTile(
                icon: commitment.travelMode.iconName,
                iconColor: Color.accentColor,
                title: "TRANSIT & ETA",
                value: distance != nil ? commitment.travelMode.formattedETA(distanceMeters: distance!) : "--",
                subtitle: distance != nil ? "\(Commitment.formatMiles(distanceMeters: distance!)) away" : "Location required"
            )

            // Tile 3: Streak & Status
            metricTile(
                icon: "flame.fill",
                iconColor: .orange,
                title: "CURRENT STREAK",
                value: "\(commitment.streak) \(commitment.streak == 1 ? "Day" : "Days")",
                subtitle: commitment.streak > 0 ? "Keep it burning!" : "Start today"
            )

            // Tile 4: Geofence Zone
            metricTile(
                icon: "mappin.and.ellipse",
                iconColor: .blue,
                title: "GEOFENCE ZONE",
                value: "\(Int(commitment.radius)) m",
                subtitle: "Passive boundary"
            )
        }
    }

    private func metricTile(icon: String, iconColor: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
            }

            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 5. Settings & Transit Mode Card

    private var settingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Transit Method")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Travel Mode", selection: $commitment.travelMode) {
                    ForEach(TravelMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: commitment.travelMode) { _, _ in
                    try? modelContext.save()
                }
            }

            Divider()

            Toggle(isOn: $commitment.isActive) {
                Text("Monitor Deadline")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .onChange(of: commitment.isActive) { _, isActive in
                if isActive {
                    LocationManager.shared.startMonitoring(commitment)
                } else {
                    LocationManager.shared.stopMonitoring(commitment)
                    NotificationManager.shared.cancelPendingNotifications(for: commitment)
                }
                try? modelContext.save()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 6. Recent History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent History")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            if commitment.history.isEmpty {
                Text("No check-in records yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                HStack(spacing: 8) {
                    ForEach(commitment.history.sorted(by: { $0.date > $1.date }).prefix(7)) { record in
                        VStack(spacing: 4) {
                            Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(record.success ? .green : .red)
                            Text(record.date.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 7. Delete Button

    private var deleteButton: some View {
        Button(role: .destructive, action: delete) {
            Label("Delete Habit Node", systemImage: "trash")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.red.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var calculatedDistance: Double? {
        guard let userCoord = userCoordinate else { return nil }
        let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let targetLoc = CLLocation(latitude: commitment.latitude, longitude: commitment.longitude)
        return userLoc.distance(from: targetLoc)
    }

    private func departureSubtitle(seconds: TimeInterval?) -> String {
        guard let seconds else { return "Calculating..." }
        if seconds < 0 {
            return "Running late"
        } else {
            let mins = Int(ceil(seconds / 60))
            return "In \(mins) min"
        }
    }

    private func performEarlyCheckIn() {
        hapticFeedback.notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            commitment.checkInEarly(now: Date(), in: modelContext)
        }
    }

    private func delete() {
        LocationManager.shared.stopMonitoring(commitment)
        NotificationManager.shared.cancelPendingNotifications(for: commitment)
        modelContext.delete(commitment)
        try? modelContext.save()
        dismiss()
    }
}
