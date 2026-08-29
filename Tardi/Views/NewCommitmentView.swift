import SwiftUI
import CoreLocation
import SwiftData

/// Presented as a sheet to create a new LocationNode on the map.
/// Nodes can be saved immediately with just a name, radius, and transit mode (no schedule required),
/// or created with an optional initial habit task using the SolarDaylightArcPicker and ActiveDaysSwitchboardPicker.
struct NewCommitmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let coordinate: CLLocationCoordinate2D
    let initialName: String
    let initialRadius: Double

    @State private var locationName: String
    @State private var radius: Double
    @State private var selectedTravelMode: TravelMode = .bicycle

    // Optional initial task configuration
    @State private var addInitialTask = false
    @State private var taskTitle = ""
    @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var isOneTime = false
    @State private var oneTimeDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var deadlineTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var pledgeAmount: Double = 0.0

    init(coordinate: CLLocationCoordinate2D, initialName: String = "Pinned Location", initialRadius: Double = 100) {
        self.coordinate = coordinate
        self.initialName = initialName
        self.initialRadius = initialRadius
        _locationName = State(initialValue: initialName)
        _radius = State(initialValue: initialRadius)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Node Details
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LOCATION DETAILS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        VStack(spacing: 12) {
                            TextField("Location Name (e.g. Gym, Office, Home)", text: $locationName)
                                .font(.system(size: 16, weight: .medium, design: .rounded))

                            Divider()

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Check-In Radius")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    Spacer()
                                    Text("\(Int(radius)) m")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.accentColor)
                                }
                                Slider(value: $radius, in: 25...1000, step: 25)
                                    .tint(Color.accentColor)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Transit Mode Tuner")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                MultibandTransitTuner(selection: $selectedTravelMode)
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // 2. Optional Initial Task Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("SCHEDULE (OPTIONAL)")
                                .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                            Spacer()
                            Toggle("", isOn: $addInitialTask)
                                .tint(Color.black)
                                .labelsHidden()
                        }

                        if addInitialTask {
                            VStack(spacing: 16) {
                                TextField("Task Title (e.g. Morning Workout)", text: $taskTitle)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .padding(12)
                                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                                ActiveDaysSwitchboardPicker(
                                    selectedWeekdays: $selectedWeekdays,
                                    isOneTime: $isOneTime,
                                    oneTimeDate: $oneTimeDate,
                                    deadlineTime: $deadlineTime
                                )

                                Divider()

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Financial Stake (Optional)")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    PledgeStakeSelector(pledgeAmount: $pledgeAmount)
                                }
                            }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }
                    }

                    // 3. Primary Action Button
                    Button(action: saveNode) {
                        Text(addInitialTask ? "Save Node & Task" : "Save Location Node")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Location Node")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: addInitialTask)
        }
    }

    private func saveNode() {
        let node = LocationNode(
            name: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: radius,
            travelMode: selectedTravelMode
        )

        modelContext.insert(node)

        if addInitialTask {
            let calendar = Calendar.current
            let timeSource = isOneTime ? oneTimeDate : deadlineTime
            let hour = calendar.component(.hour, from: timeSource)
            let minute = calendar.component(.minute, from: timeSource)
            let effectiveTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Arrival Deadline" : taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)

            let task = HabitTask(
                title: effectiveTitle,
                weekdays: isOneTime ? [] : Array(selectedWeekdays).sorted(),
                deadlineHour: hour,
                deadlineMinute: minute,
                oneTimeDate: isOneTime ? oneTimeDate : nil,
                pledgeAmount: pledgeAmount,
                node: node
            )
            node.tasks.append(task)
            modelContext.insert(task)

            if let next = task.nextDeadline(after: Date()) {
                NotificationManager.shared.scheduleDeadlineNotification(for: task, at: next)
            }
        }

        try? modelContext.save()
        LocationManager.shared.startMonitoring(node)
        dismiss()
    }
}
