import SwiftUI
import CoreLocation
import UIKit

/// Presented as a sheet when a commitment's dot is tapped on the map.
/// Features custom location renaming, elaborate burning fuse countdown clock,
/// "Time to Leave" departure advisor, and Early Check-In to complete and clear nodes.
struct CommitmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var commitment: Commitment
    var userCoordinate: CLLocationCoordinate2D? = LocationManager.shared.currentCoordinate

    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var showingCheckInSuccess = false

    private let hapticFeedback = UINotificationFeedbackGenerator()

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. Elaborate Animated Countdown Timer / Burning Fuse Clock
                        ElaborateCountdownTimerView(commitment: commitment, now: context.date)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)

                        // 2. Early Check-In Action Card
                        earlyCheckInCard(now: context.date)

                        // 3. "Time to Leave" Departure Advisor Card
                        TimeToLeaveCard(
                            commitment: commitment,
                            userCoordinate: userCoordinate,
                            now: context.date
                        )

                        // 4. Location Details & Settings
                        VStack(spacing: 12) {
                            SectionCard {
                                HStack {
                                    Text("Location Name")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }

                                if isEditingName {
                                    HStack {
                                        TextField("Name", text: $editedName)
                                            .font(.headline)
                                            .padding(8)
                                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        Button("Save") {
                                            if !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                commitment.locationName = editedName
                                                try? modelContext.save()
                                            }
                                            isEditingName = false
                                        }
                                        .fontWeight(.bold)
                                    }
                                } else {
                                    HStack {
                                        Text(commitment.locationName)
                                            .font(.title3.weight(.bold))
                                        Spacer()
                                        Button {
                                            editedName = commitment.locationName
                                            isEditingName = true
                                        } label: {
                                            Image(systemName: "pencil.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                }

                                Divider()

                                LabeledContent("Schedule", value: ScheduleFormatter.summary(for: commitment))
                                LabeledContent("Geofence Radius", value: "\(Int(commitment.radius)) m")

                                Picker("Transportation", selection: $commitment.travelMode) {
                                    ForEach(TravelMode.allCases) { mode in
                                        Label(mode.rawValue, systemImage: mode.iconName)
                                            .tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: commitment.travelMode) { _, _ in
                                    try? modelContext.save()
                                }

                                LabeledContent("Current Streak") {
                                    HStack(spacing: 4) {
                                        Image(systemName: "flame.fill").foregroundStyle(.orange)
                                        Text("\(commitment.streak)").fontWeight(.bold)
                                    }
                                }
                            }

                            // 5. Check-in History
                            SectionCard {
                                Text("Recent Check-in History")
                                    .font(.headline)

                                if commitment.history.isEmpty {
                                    Text("No check-ins yet. Be here by the deadline to start your streak!")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(commitment.history.sorted(by: { $0.date > $1.date }).prefix(5)) { record in
                                        HStack {
                                            Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundStyle(record.success ? .green : .red)
                                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.subheadline)
                                            Spacer()
                                            Text(record.success ? "Passed" : "Missed")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(record.success ? .green : .red)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }

                            // 6. Active Toggle & Delete Action
                            SectionCard {
                                Toggle("Monitor Commitment", isOn: $commitment.isActive)
                                    .onChange(of: commitment.isActive) { _, isActive in
                                        if isActive {
                                            LocationManager.shared.startMonitoring(commitment)
                                        } else {
                                            LocationManager.shared.stopMonitoring(commitment)
                                            NotificationManager.shared.cancelPendingNotifications(for: commitment)
                                        }
                                        try? modelContext.save()
                                    }

                                Divider()

                                Button(role: .destructive, action: delete) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Delete Node")
                                    }
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(commitment.locationName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    // MARK: - Early Check-In Card

    @ViewBuilder
    private func earlyCheckInCard(now: Date) -> some View {
        let isDone = commitment.isCompletedForToday(asOf: now)

        if isDone {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Checked in for today!")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("Streak +1 secured. Next check-in on next scheduled day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.green.opacity(0.3), lineWidth: 1))
        } else {
            VStack(spacing: 10) {
                Button {
                    performEarlyCheckIn()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(commitment.isCurrentlyInside ? "Check In Early (At Location)" : "Check In Early & Clear Node")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        commitment.isCurrentlyInside ? Color.green : Color.accentColor,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .foregroundStyle(.white)
                    .shadow(color: (commitment.isCurrentlyInside ? Color.green : Color.accentColor).opacity(0.35), radius: 8, y: 3)
                }
                .buttonStyle(.plain)

                Text(commitment.isCurrentlyInside
                     ? "Arrived before deadline? Tap to record your check-in early and advance your streak!"
                     : "Check in early to secure your streak and clear this node for today.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func performEarlyCheckIn() {
        hapticFeedback.notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            commitment.checkInEarly(now: Date(), in: modelContext)
            showingCheckInSuccess = true
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
