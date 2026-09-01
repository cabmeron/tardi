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
    var userCoordinate: CLLocationCoordinate2D? = nil

    @ObservedObject private var locationManager = LocationManager.shared

    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var showingAddTaskSheet = false
    @State private var showingVaultSheet = false
    @State private var showingGeoVerificationAlert = false
    @State private var geoAlertDistance: Int = 0
    @State private var showingMomentaryCompletion = false
    @State private var momentaryCompletionTimer: Task<Void, Never>? = nil
    @State private var isHoldingLocationScan = false
    @State private var locationScanProgress: CGFloat = 0.0
    @State private var isScanBursting = false
    @State private var scanBurstTimer: Task<Void, Never>? = nil

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

                        // 3. Heavy Industrial Plunger Button: ONLY available when an armed task needs to be de-armed
                        if let nearest = node.nearestUpcomingTask(after: context.date), !nearest.isCompletedForToday(asOf: context.date) {
                            let stakeText = nearest.isPledged && nearest.pledgeAmount > 0 ? " · $\(Int(nearest.pledgeAmount)) AT RISK" : ""
                            let isVerified = isInsideGeofence
                            let dist = calculatedDistance ?? 0

                            IndustrialPlungerButton(
                                title: isVerified ? "HOLD TO SCAN & DE-ARM (\(nearest.title.uppercased())\(stakeText))" : "GPS VERIFYING (\(Int(dist))m AWAY)",
                                pressedTitle: "SCANNING LOCATION & DE-ARMING...",
                                isCompleted: nearest.isCompletedForToday(asOf: context.date),
                                isGeofenceVerified: isVerified,
                                distanceAwayMeters: calculatedDistance,
                                requiredRadiusMeters: node.radius,
                                onOutsideLocationTapped: {
                                    geoAlertDistance = Int(calculatedDistance ?? 0)
                                    showingGeoVerificationAlert = true
                                },
                                onHoldProgressChanged: { holding, prog in
                                    withAnimation(.linear(duration: 0.05)) {
                                        isHoldingLocationScan = holding
                                        locationScanProgress = prog
                                    }
                                },
                                onComplete: {
                                    triggerScanBurst()
                                    triggerCheckInSuccess(for: nearest)
                                }
                            )
                        }

                        // 4. Tasks at this Location Section (with Stake Badges)
                        tasksSection(now: context.date)

                        // 5. Quiet Delete Node Action
                        deleteButton
                            .padding(.top, 4)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .onAppear {
                locationManager.startUpdatingUserLocation()
                locationManager.requestWhenInUseAuthorization()
            }
            .onDisappear {
                momentaryCompletionTimer?.cancel()
                scanBurstTimer?.cancel()
            }
            .alert("Geolocation Verification Required", isPresented: $showingGeoVerificationAlert) {
                Button("OK", role: .cancel) { }
                Button("Refresh GPS") {
                    locationManager.startUpdatingUserLocation()
                }
            } message: {
                if geoAlertDistance > 0 {
                    Text("You are currently \(geoAlertDistance)m away from \(node.name).\n\nYou must be physically within the \(Int(node.radius))m geofence radius to verify arrival.")
                } else {
                    Text("GPS coordinates could not be confirmed. Please enable Location Services and move within the \(Int(node.radius))m geofence to verify your check-in.")
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingVaultSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "creditcard.fill")
                            Text("Vault")
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
            .sheet(isPresented: $showingAddTaskSheet) {
                NewTaskSheet(node: node)
            }
            .sheet(isPresented: $showingVaultSheet) {
                VaultArmingView()
            }
        }
        .overlay {
            SpatialParticleOverlay(
                isActive: isHoldingLocationScan,
                progress: locationScanProgress,
                isBursting: isScanBursting
            )
            .allowsHitTesting(false)
            .ignoresSafeArea()
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

    // MARK: - 2. Monolith Cockpit Hero (Embedded Burning Fuse Countdown)

    private func monolithCockpitRing(now: Date) -> some View {
        let nearest = node.nearestUpcomingTask(after: now)
        let isDone = showingMomentaryCompletion
        let progress = node.fuseProgress(asOf: now) ?? (node.tasks.isEmpty ? 0 : 1)
        let timeRemaining = nearest?.timeRemaining(asOf: now) ?? 0
        let distance = calculatedDistance
        let totalStreak = node.tasks.reduce(0) { $0 + $1.streak }
        let pledgeAmount = nearest?.pledgeAmount ?? 0.0
        let isPledged = nearest?.isPledged ?? false

        // Only show task countdown if there is an active pending task not completed today.
        // Once checked in, activeTaskTitle is nil, which automatically shows the Tactical Geodesic Radar Scope!
        let activeTaskTitle: String? = (nearest != nil && !nearest!.isCompletedForToday(asOf: now)) ? nearest?.title : nil

        return BurningFuseCountdownView(
            progress: progress,
            timeRemaining: timeRemaining,
            pledgeAmount: pledgeAmount,
            isPledged: isPledged,
            taskTitle: activeTaskTitle,
            isCompleted: isDone,
            totalStreak: totalStreak,
            transitETA: distance != nil ? node.travelMode.formattedETA(distanceMeters: distance!) : nil,
            transitModeIcon: distance != nil ? node.travelMode.iconName : nil,
            distanceText: distance != nil ? TravelMode.formatMiles(distanceMeters: distance!) : nil,
            isInsideLocation: isInsideGeofence,
            geofenceRadiusMeters: node.radius,
            onAddTask: { showingAddTaskSheet = true }
        )
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
                VStack(spacing: 6) {
                    Text("No tasks scheduled here yet.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
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

            // Early De-Arm or De-Armed Pill
            if isDone {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("De-Armed")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12), in: Capsule())
            } else {
                Button {
                    if isInsideGeofence {
                        triggerScanBurst()
                        triggerCheckInSuccess(for: task)
                    } else {
                        hapticFeedback.notificationOccurred(.warning)
                        geoAlertDistance = Int(calculatedDistance ?? 0)
                        showingGeoVerificationAlert = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isInsideGeofence ? "location.fill" : "location.slash")
                            .font(.system(size: 9, weight: .bold))
                        Text(isInsideGeofence ? "De-Arm" : "Outside")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isInsideGeofence ? Color.green : Color.orange.opacity(0.18), in: Capsule())
                    .foregroundStyle(isInsideGeofence ? Color.white : Color.orange)
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

    private func triggerScanBurst() {
        withAnimation(.easeOut(duration: 0.2)) {
            isScanBursting = true
            isHoldingLocationScan = false
            locationScanProgress = 1.0
        }

        scanBurstTimer?.cancel()
        scanBurstTimer = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.4)) {
                    isScanBursting = false
                    locationScanProgress = 0.0
                }
            }
        }
    }

    private func triggerCheckInSuccess(for task: HabitTask) {
        hapticFeedback.notificationOccurred(.success)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
            task.checkInEarly(
                now: Date(),
                isLocationVerified: true,
                distanceMeters: calculatedDistance,
                in: modelContext
            )
            showingMomentaryCompletion = true
        }

        momentaryCompletionTimer?.cancel()
        momentaryCompletionTimer = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000) // Momentary 2.5s celebration
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.55)) {
                    showingMomentaryCompletion = false
                }
            }
        }
    }

    private var calculatedDistance: Double? {
        guard let userCoord = locationManager.currentCoordinate ?? userCoordinate else { return nil }
        let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let targetLoc = CLLocation(latitude: node.latitude, longitude: node.longitude)
        return userLoc.distance(from: targetLoc)
    }

    private var isInsideGeofence: Bool {
        if node.isCurrentlyInside { return true }
        if let distance = calculatedDistance {
            return distance <= node.radius
        }
        return false
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
