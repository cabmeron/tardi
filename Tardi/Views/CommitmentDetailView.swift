import SwiftUI
import CoreLocation
import SwiftData
import UIKit

/// Presented as a sheet when a location node is tapped on the map.
/// Reorganized into the "Single Monolith Cockpit" architecture with financial pledge stakes:
/// Minimal text, zero verbose card grids, embedded telemetry inside the hero countdown ring,
/// spring-loaded check-in plunger, and Dieter Rams multiband transit tuner.
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
                    VStack(spacing: 18) {
                        // 1. Clean Symmetrical Header
                        headerSection

                        // 2. Monolith Cockpit Hero: Countdown Ring with Embedded Telemetry
                        monolithCockpitRing(now: context.date)

                        // 3. Heavy Industrial Plunger Check-In Button (If task pending)
                        if let nearest = node.nearestUpcomingTask(after: context.date), !nearest.isCompletedForToday(asOf: context.date) {
                            let stakeText = nearest.isPledged && nearest.pledgeAmount > 0 ? " · $\(Int(nearest.pledgeAmount)) AT RISK" : ""
                            IndustrialPlungerButton(
                                title: "HOLD TO CHECK IN (\(nearest.title.uppercased())\(stakeText))",
                                isCompleted: nearest.isCompletedForToday(asOf: context.date)
                            ) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    nearest.checkInEarly(now: Date(), in: modelContext)
                                }
                            }
                        }

                        // 4. Tasks at this Location Section (with Stake Badges)
                        tasksSection(now: context.date)

                        // 5. Multiband Radio Transit Tuner
                        transitTunerSection

                        // 6. Quiet Delete Node Action
                        deleteButton
                            .padding(.top, 4)
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

    // MARK: - 1. Symmetrical Header Section

    private var headerSection: some View {
        VStack(spacing: 4) {
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

            // Compact Subtitle Tag
            HStack(spacing: 6) {
                Text("\(node.tasks.count) \(node.tasks.count == 1 ? "Task" : "Tasks")")
                Text("•")
                Text("\(Int(node.radius))m Geofence")
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - 2. Monolith Cockpit Hero (Embedded Telemetry Ring)

    private func monolithCockpitRing(now: Date) -> some View {
        let nearest = node.nearestUpcomingTask(after: now)
        let isDone = node.isAnyTaskCompletedToday(asOf: now)
        let progress = node.fuseProgress(asOf: now) ?? (node.tasks.isEmpty ? 0 : 1)
        let timeRemaining = nearest?.timeRemaining(asOf: now) ?? 0
        let distance = calculatedDistance
        let totalStreak = node.tasks.reduce(0) { $0 + $1.streak }

        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60

        return ZStack {
            // Ambient Outer Track
            Circle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 8)
                .frame(width: 200, height: 200)

            // Dynamic Glowing Progress Arc
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
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
            }

            // Monolith Interior: Digits + Embedded Telemetry Bar
            VStack(spacing: 6) {
                if isDone {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.green)

                    Text("CHECKED IN")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .tracking(1)

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text("\(totalStreak) Days Streak")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, 2)
                } else if let task = nearest {
                    // Task Name Header
                    Text(task.title.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                        .lineLimit(1)

                    // Bold Countdown Digits
                    HStack(spacing: 2) {
                        if hours > 0 {
                            timeDigitBlock(value: hours, label: "H")
                            Text(":").font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        timeDigitBlock(value: minutes, label: "M")
                        Text(":").font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        timeDigitBlock(value: seconds, label: "S")
                    }

                    // Embedded Compact Telemetry Icon Row
                    HStack(spacing: 8) {
                        // Transit ETA
                        if let dist = distance {
                            HStack(spacing: 2) {
                                Image(systemName: node.travelMode.iconName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                                Text(node.travelMode.formattedETA(distanceMeters: dist))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            Text("·").foregroundStyle(.secondary)

                            // Distance
                            Text(TravelMode.formatMiles(distanceMeters: dist))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Text("·").foregroundStyle(.secondary)
                        }

                        // Streak
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("\(totalStreak)d")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.top, 2)

                    // Presence Pill
                    HStack(spacing: 5) {
                        Circle()
                            .fill(node.isCurrentlyInside ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(node.isCurrentlyInside ? "At Location" : "Away")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(node.isCurrentlyInside ? .green : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
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
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 215)
    }

    private func timeDigitBlock(value: Int, label: String) -> some View {
        VStack(spacing: 0) {
            Text(String(format: "%02d", value))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 3. Tasks at this Location Section

    private func tasksSection(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TASKS AT THIS LOCATION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Spacer()

                Button {
                    showingAddTaskSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Task")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
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
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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
            VStack(alignment: .leading, spacing: 4) {
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

                    if task.isPledged && task.pledgeAmount > 0 {
                        Text("$\(Int(task.pledgeAmount))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .foregroundStyle(.red)
                    }
                }

                HStack(spacing: 6) {
                    Text(task.scheduleSummary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if task.totalForfeitedAmount > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("$\(Int(task.totalForfeitedAmount)) lost")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.red.opacity(0.85))
                    }
                }
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

    // MARK: - 4. Multiband Radio Transit Tuner

    private var transitTunerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRANSIT METHOD TUNER")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1)

            MultibandTransitTuner(selection: $node.travelMode)
                .onChange(of: node.travelMode) { _, _ in
                    try? modelContext.save()
                }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 5. Delete Button

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

    private func deleteTask(_ task: HabitTask) {
        if let idx = node.tasks.firstIndex(where: { $0.id == task.id }) {
            node.tasks.remove(at: idx)
        }
        NotificationManager.shared.cancelPendingNotifications(for: task)
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
