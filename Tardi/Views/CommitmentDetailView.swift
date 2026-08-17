import SwiftUI
import CoreLocation
import SwiftData
import UIKit

/// Presented as a sheet when a location node is tapped on the map.
/// Manages all habit tasks assigned to this physical location.
struct CommitmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var node: LocationNode
    var userCoordinate: CLLocationCoordinate2D? = LocationManager.shared.currentCoordinate

    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var showingAddTaskSheet = false

    private let hapticFeedback = UINotificationFeedbackGenerator()

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Centered Symmetrical Header
                        headerSection

                        // 2. Hero Centerpiece: Countdown Ring for Nearest Upcoming Task
                        heroCountdownRing(now: context.date)

                        // 3. Symmetrical 2x2 Metric Grid
                        metricGrid(now: context.date)

                        // 4. Tasks at this Location Section
                        tasksSection(now: context.date)

                        // 5. Node Settings & Transit Mode
                        settingsSection

                        // 6. Quiet Delete Node Action
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
            .sheet(isPresented: $showingAddTaskSheet) {
                NewTaskSheet(node: node)
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
                            node.name = editedName
                            try? modelContext.save()
                        }
                        isEditingName = false
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            } else {
                HStack(spacing: 6) {
                    Text(node.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Button {
                        editedName = node.name
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Subtitle showing task count & radius
            Text("\(node.tasks.count) \(node.tasks.count == 1 ? "Task" : "Tasks") · \(Int(node.radius))m Geofence")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - 2. Hero Centerpiece Countdown Ring

    private func heroCountdownRing(now: Date) -> some View {
        let nearest = node.nearestUpcomingTask(after: now)
        let isDone = node.isAnyTaskCompletedToday(asOf: now)
        let progress = node.fuseProgress(asOf: now) ?? (node.tasks.isEmpty ? 0 : 1)
        let timeRemaining = nearest?.timeRemaining(asOf: now) ?? 0

        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60

        return ZStack {
            // Ambient Outer Track
            Circle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 8)
                .frame(width: 174, height: 174)

            // Dynamic Progress Ring
            if !node.tasks.isEmpty {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isDone
                            ? AnyShapeStyle(Color.green)
                            : AnyShapeStyle(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        node.isCurrentlyInside ? .green : Color.accentColor,
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
            }

            // Inner Centered Content
            VStack(spacing: 4) {
                if isDone {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)

                    Text("CHECKED IN")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .tracking(1)

                    Text("Completed for Today")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } else if let task = nearest {
                    Text(task.title.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                        .lineLimit(1)

                    HStack(spacing: 2) {
                        timeBlock(value: hours, label: "H")
                        Text(":").font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        timeBlock(value: minutes, label: "M")
                        Text(":").font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        timeBlock(value: seconds, label: "S")
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(node.isCurrentlyInside ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(node.isCurrentlyInside ? "At Location" : "Away")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(node.isCurrentlyInside ? .green : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                    .padding(.top, 2)
                } else {
                    Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentColor)

                    Text("NO ACTIVE TASKS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    Button("Add Task") {
                        showingAddTaskSheet = true
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16)
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

    // MARK: - 3. Symmetrical 2x2 Metric Grid

    private func metricGrid(now: Date) -> some View {
        let distance = calculatedDistance
        let leaveTime = node.latestDepartureTime(from: userCoordinate, asOf: now)
        let timeUntilLeave = node.timeUntilDeparture(from: userCoordinate, asOf: now)
        let totalStreak = node.tasks.reduce(0) { $0 + $1.streak }

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // Tile 1: Latest Departure
            metricTile(
                icon: "clock.badge.exclamationmark",
                iconColor: .orange,
                title: "TIME TO LEAVE",
                value: leaveTime != nil ? leaveTime!.formatted(date: .omitted, time: .shortened) : "--:--",
                subtitle: leaveTime != nil ? departureSubtitle(seconds: timeUntilLeave) : "No tasks due"
            )

            // Tile 2: Transit & Distance
            metricTile(
                icon: node.travelMode.iconName,
                iconColor: Color.accentColor,
                title: "TRANSIT & ETA",
                value: distance != nil ? node.travelMode.formattedETA(distanceMeters: distance!) : "--",
                subtitle: distance != nil ? "\(TravelMode.formatMiles(distanceMeters: distance!)) away" : "Location required"
            )

            // Tile 3: Streaks
            metricTile(
                icon: "flame.fill",
                iconColor: .orange,
                title: "TOTAL STREAKS",
                value: "\(totalStreak) \(totalStreak == 1 ? "Day" : "Days")",
                subtitle: "\(node.tasks.count) \(node.tasks.count == 1 ? "task" : "tasks") registered"
            )

            // Tile 4: Geofence Zone
            metricTile(
                icon: "mappin.and.ellipse",
                iconColor: .blue,
                title: "GEOFENCE ZONE",
                value: "\(Int(node.radius)) m",
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

    // MARK: - 4. Tasks at this Location Section

    private func tasksSection(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tasks at this Location")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showingAddTaskSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Task")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                }
            }

            if node.tasks.isEmpty {
                VStack(spacing: 8) {
                    Text("No tasks scheduled here yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        showingAddTaskSheet = true
                    } label: {
                        Text("+ Add First Task")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(node.tasks) { task in
                        taskRow(task: task, now: now)
                    }
                }
            }
        }
    }

    private func taskRow(task: HabitTask, now: Date) -> some View {
        let isDone = task.isCompletedForToday(asOf: now)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if task.streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("\(task.streak)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                    }
                }

                Text(task.scheduleSummary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Early Check-In or Done Pill
            if isDone {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Done")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12), in: Capsule())
            } else {
                Button {
                    hapticFeedback.notificationOccurred(.success)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        task.checkInEarly(now: Date(), in: modelContext)
                    }
                } label: {
                    Text("Check In")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(node.isCurrentlyInside ? Color.green : Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            // Task Delete Button
            Button(role: .destructive) {
                withAnimation {
                    deleteTask(task)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
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
                Picker("Travel Mode", selection: $node.travelMode) {
                    ForEach(TravelMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: node.travelMode) { _, _ in
                    try? modelContext.save()
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 6. Delete Button

    private var deleteButton: some View {
        Button(role: .destructive, action: deleteNode) {
            Label("Delete Location Node", systemImage: "trash")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.red.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var calculatedDistance: Double? {
        guard let userCoord = userCoordinate else { return nil }
        let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let targetLoc = CLLocation(latitude: node.latitude, longitude: node.longitude)
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

    private func deleteTask(_ task: HabitTask) {
        NotificationManager.shared.cancelPendingNotifications(for: task)
        if let idx = node.tasks.firstIndex(where: { $0.id == task.id }) {
            node.tasks.remove(at: idx)
        }
        modelContext.delete(task)
        try? modelContext.save()
    }

    private func deleteNode() {
        LocationManager.shared.stopMonitoring(node)
        for task in node.tasks {
            NotificationManager.shared.cancelPendingNotifications(for: task)
        }
        modelContext.delete(node)
        try? modelContext.save()
        dismiss()
    }
}
