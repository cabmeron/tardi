import SwiftUI
import SwiftData

/// A sheet to configure and attach a new scheduled habit task to a LocationNode
/// featuring the SolarDaylightArcPicker, ActiveDaysSwitchboardPicker, and PledgeStakeSelector.
struct NewTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let node: LocationNode

    @State private var taskTitle = ""
    @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri default
    @State private var isOneTime = false
    @State private var oneTimeDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var deadlineTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var pledgeAmount: Double = 0.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Task Name Input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TASK NAME")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        TextField("e.g. Morning Workout, Arrive at Office", text: $taskTitle)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // 2. Active Days Switchboard
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACTIVE DAYS SWITCHBOARD")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        ActiveDaysSwitchboardPicker(
                            selectedWeekdays: $selectedWeekdays,
                            isOneTime: $isOneTime,
                            oneTimeDate: $oneTimeDate
                        )
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // 3. Solar Daylight Arc Picker
                    VStack(alignment: .center, spacing: 8) {
                        SolarDaylightArcPicker(time: $deadlineTime)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // 4. Financial Pledge Stake (Money at Risk)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FINANCIAL PLEDGE STAKE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        PledgeStakeSelector(pledgeAmount: $pledgeAmount)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // 5. Primary Add Button
                    Button(action: saveTask) {
                        Text(pledgeAmount > 0 ? "Arm Task ($\(Int(pledgeAmount)) Stake)" : "Add Task to \(node.name)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(pledgeAmount > 0 ? Color.red : Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                            .shadow(color: (pledgeAmount > 0 ? Color.red : Color.accentColor).opacity(0.3), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!isOneTime && selectedWeekdays.isEmpty))
                    .opacity(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!isOneTime && selectedWeekdays.isEmpty) ? 0.5 : 1.0)
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Habit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveTask() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: deadlineTime)
        let minute = calendar.component(.minute, from: deadlineTime)

        let task = HabitTask(
            title: taskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            weekdays: isOneTime ? [] : Array(selectedWeekdays).sorted(),
            deadlineHour: hour,
            deadlineMinute: minute,
            oneTimeDate: isOneTime ? oneTimeDate : nil,
            pledgeAmount: pledgeAmount,
            node: node
        )

        node.tasks.append(task)
        modelContext.insert(task)
        try? modelContext.save()

        if let next = task.nextDeadline(after: Date()) {
            NotificationManager.shared.scheduleDeadlineNotification(for: task, at: next)
        }

        dismiss()
    }
}
