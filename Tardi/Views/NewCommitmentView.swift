import SwiftUI
import CoreLocation

/// A location chosen on the map: its display name plus real coordinate.
struct PickedLocation {
    var name: String
    var coordinate: CLLocationCoordinate2D
}

/// The final step in adding a commitment: custom location naming,
/// travel method assignment, and schedule setup.
struct NewCommitmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let location: PickedLocation
    let radius: Double
    var onSave: () -> Void = {}

    @State private var locationName: String = ""
    @State private var travelMode: TravelMode = .bicycle
    @State private var scheduleType: ScheduleType = .recurring
    @State private var selectedWeekdays: Set<Int> = []
    @State private var oneTimeDate = Date().addingTimeInterval(3600)
    @State private var deadlineTime = Date()

    enum ScheduleType: String, CaseIterable, Identifiable {
        case recurring = "Repeats"
        case oneTime = "Once"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Location & Custom Naming Section
                    SectionCard {
                        Text("Location Name")
                            .font(.headline)

                        TextField("e.g. Gym, Office, Coffee Shop", text: $locationName)
                            .font(.system(size: 16, weight: .semibold))
                            .padding(12)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            Text(location.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(radius))m radius")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Transportation Section
                    SectionCard {
                        Text("Transportation")
                            .font(.headline)
                        Text("How will you travel to this destination?")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TravelModePickerBar(selectedMode: $travelMode)
                    }

                    // Schedule Section
                    SectionCard {
                        Text("Schedule")
                            .font(.headline)

                        SlidingSegmentedControl(options: ScheduleType.allCases, selection: $scheduleType) { type in
                            Text(type.rawValue).font(.subheadline.weight(.semibold))
                        }

                        if scheduleType == .recurring {
                            WeekdayDragPicker(selectedWeekdays: $selectedWeekdays)
                                .padding(.vertical, 4)
                        } else {
                            DatePicker("Date", selection: $oneTimeDate, displayedComponents: .date)
                        }

                        Divider()

                        TimeOfDaySlider(time: $deadlineTime)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Habit Node")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .fontWeight(.bold)
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if locationName.isEmpty {
                    locationName = location.name
                }
            }
        }
    }

    private var isValid: Bool {
        let hasName = !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasSchedule = scheduleType == .recurring ? !selectedWeekdays.isEmpty : true
        return hasName && hasSchedule
    }

    private func save() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: deadlineTime)
        let minute = calendar.component(.minute, from: deadlineTime)
        let finalName = locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? location.name : locationName

        let commitment = Commitment(
            locationName: finalName,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radius: radius,
            weekdays: scheduleType == .recurring ? Array(selectedWeekdays) : [],
            deadlineHour: hour,
            deadlineMinute: minute,
            oneTimeDate: scheduleType == .oneTime ? oneTimeDate : nil,
            travelMode: travelMode
        )
        modelContext.insert(commitment)
        try? modelContext.save()

        LocationManager.shared.startMonitoring(commitment)
        if let next = commitment.nextDeadline(after: Date()) {
            NotificationManager.shared.scheduleDeadlineNotification(for: commitment, at: next)
        }
        onSave()
        dismiss()
    }
}
