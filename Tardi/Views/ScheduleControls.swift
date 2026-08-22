import SwiftUI
import UIKit

// MARK: - Concept 4: Tactile Circadian Time Slider

/// An architectural, circadian time slider representing the 24-hour cycle from sunrise
/// to night with buttery smooth 120 FPS dragging, bounded geometry that never overflows its card,
/// and instant haptic detents.
struct SolarDaylightArcPicker: View {
    @Binding var time: Date

    @State private var isDragging = false
    @State private var dragProgress: Double? = nil
    @State private var previousNotch: Int = -1

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var calendar: Calendar { .current }

    private var totalMinutes: Int {
        let h = calendar.component(.hour, from: time)
        let m = calendar.component(.minute, from: time)
        return h * 60 + m
    }

    /// Progress across the 24-hour day [0, 1]
    private var dayProgress: Double {
        dragProgress ?? (Double(totalMinutes) / 1440.0)
    }

    private var hour: Int {
        calendar.component(.hour, from: time)
    }

    private var celestialColor: Color {
        switch hour {
        case 5..<8:  return .orange
        case 8..<17: return .yellow
        case 17..<20: return .orange
        default:     return .indigo
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // 1. Prominent Centered Digital Time
            Text(time.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            // 2. Silky Smooth Bounded Slider Track
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let trackHeight: CGFloat = 12
                let knobSize: CGFloat = 30
                let usableWidth = max(totalWidth - knobSize, 1.0)
                let knobX = CGFloat(dayProgress) * usableWidth

                ZStack(alignment: .leading) {
                    // Track Background (Circadian 24h Gradient)
                    RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(height: trackHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.8)
                        )

                    // Active Glowing Fill Bar
                    RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.indigo.opacity(0.7),
                                    Color.orange.opacity(0.85),
                                    Color.yellow.opacity(0.9),
                                    Color.orange.opacity(0.85),
                                    Color.purple.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(knobX + knobSize / 2, trackHeight), height: trackHeight)

                    // Hour Tick Markers
                    HStack(spacing: 0) {
                        ForEach(0..<5) { tick in
                            if tick > 0 {
                                Spacer()
                            }
                            Rectangle()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 1.5, height: tick == 0 || tick == 4 ? 6 : 4)
                        }
                    }
                    .padding(.horizontal, knobSize / 2)
                    .frame(height: trackHeight)

                    // Tactile Draggable Knob
                    ZStack {
                        // Ambient Glowing Halo
                        Circle()
                            .fill(celestialColor.opacity(isDragging ? 0.45 : 0.2))
                            .frame(width: isDragging ? 42 : 32, height: isDragging ? 42 : 32)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)

                        // Solid White Bezel
                        Circle()
                            .fill(Color(.secondarySystemGroupedBackground))
                            .frame(width: knobSize, height: knobSize)
                            .overlay(
                                Circle()
                                    .stroke(celestialColor.opacity(0.9), lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.18), radius: 4, y: 2)

                        // Inner Dynamic Core Dot
                        Circle()
                            .fill(celestialColor)
                            .frame(width: 10, height: 10)
                    }
                    .offset(x: knobX)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let progress = max(min(Double(value.location.x - (knobSize / 2)) / Double(usableWidth), 1.0), 0.0)
                            dragProgress = progress
                            updateTime(from: progress)
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragProgress = nil
                            previousNotch = -1
                        }
                )
            }
            .frame(height: 44)

            // 3. Time Labels (12 AM · 6 AM · 12 PM · 6 PM · 12 AM)
            HStack {
                Text("12 AM").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Text("6 AM").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Text("12 PM").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Text("6 PM").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Text("12 AM").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .padding(.vertical, 10)
    }

    private func updateTime(from progress: Double) {
        let totalMins = Int(progress * 1440.0)
        let snappedMins = (Int(round(Double(totalMins) / 5.0)) * 5) % 1440
        let notchIndex = snappedMins / 5

        if notchIndex != previousNotch {
            haptic.impactOccurred(intensity: 0.6)
            previousNotch = notchIndex
        }

        var components = calendar.dateComponents([.year, .month, .day], from: time)
        components.hour = snappedMins / 60
        components.minute = snappedMins % 60
        components.second = 0

        if let newDate = calendar.date(from: components) {
            time = newDate
        }
    }
}

/// Smooth parabolic curved path representing the daylight arch
struct SolarArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startX = rect.minX
        let endX = rect.maxX
        let startY = rect.maxY
        let apexY = rect.minY + 6
        let midX = rect.midX

        path.move(to: CGPoint(x: startX, y: startY))
        path.addQuadCurve(
            to: CGPoint(x: endX, y: startY),
            control: CGPoint(x: midX, y: apexY - (rect.height * 0.5))
        )
        return path
    }
}

// MARK: - Active Days Switchboard Picker (Mechanical Key Switches)

/// An industrial, ultra-tactile active days selector with 7 physical rocker toggle switches,
/// glowing neon LED indicators, satisfying mechanical haptics, and a Repeat toggle.
struct ActiveDaysSwitchboardPicker: View {
    @Binding var selectedWeekdays: Set<Int> // Standard Calendar: 1 = Sun, 2 = Mon ... 7 = Sat
    @Binding var isOneTime: Bool
    @Binding var oneTimeDate: Date

    @State private var dragIsSelecting: Bool?
    @State private var previousDraggedIndex: Int = -1

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    // Standard work-week ordering: Monday (2) -> Sunday (1)
    private let dayOrder: [(id: Int, short: String, label: String)] = [
        (2, "MON", "Mon"),
        (3, "TUE", "Tue"),
        (4, "WED", "Wed"),
        (5, "THU", "Thu"),
        (6, "FRI", "Fri"),
        (7, "SAT", "Sat"),
        (1, "SUN", "Sun")
    ]

    var body: some View {
        VStack(spacing: 14) {
            // 1. Repeat Weekly Toggle Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: isOneTime ? "calendar" : "switch.2")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isOneTime ? Color.secondary : Color.cyan)

                    Text(isOneTime ? "One-Time Deadline" : "Repeats Weekly")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { !isOneTime },
                    set: { repeats in
                        haptic.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isOneTime = !repeats
                            if repeats && selectedWeekdays.isEmpty {
                                selectedWeekdays = [2, 3, 4, 5, 6]
                            }
                        }
                    }
                ))
                .labelsHidden()
            }

            // 2. Mechanical Switchboard or One-Time Date Picker
            if !isOneTime {
                VStack(spacing: 12) {
                    // 7 Switches Row
                    GeometryReader { geometry in
                        let totalWidth = geometry.size.width
                        let slotWidth = totalWidth / 7.0

                        HStack(spacing: 0) {
                            ForEach(Array(dayOrder.enumerated()), id: \.element.id) { index, item in
                                let isActive = selectedWeekdays.contains(item.id)
                                MechanicalSwitchCell(
                                    label: item.short,
                                    isActive: isActive,
                                    onTap: { toggleDay(item.id) }
                                )
                                .frame(width: slotWidth)
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleSwitchboardDrag(at: value.location.x, slotWidth: slotWidth)
                                }
                                .onEnded { _ in
                                    dragIsSelecting = nil
                                    previousDraggedIndex = -1
                                }
                        )
                    }
                    .frame(height: 84)
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                DatePicker("Target Date", selection: $oneTimeDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isOneTime)
    }

    // MARK: - Actions & Gestures

    private func toggleDay(_ id: Int) {
        haptic.impactOccurred()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
            if selectedWeekdays.contains(id) {
                if selectedWeekdays.count > 1 {
                    selectedWeekdays.remove(id)
                }
            } else {
                selectedWeekdays.insert(id)
            }
        }
    }

    private func handleSwitchboardDrag(at x: CGFloat, slotWidth: CGFloat) {
        guard slotWidth > 0 else { return }
        let rawIndex = Int(x / slotWidth)
        guard rawIndex >= 0, rawIndex < 7 else { return }

        let dayId = dayOrder[rawIndex].id

        if dragIsSelecting == nil {
            dragIsSelecting = !selectedWeekdays.contains(dayId)
        }
        guard let isSelecting = dragIsSelecting else { return }

        if rawIndex != previousDraggedIndex {
            if isSelecting {
                selectedWeekdays.insert(dayId)
                haptic.impactOccurred()
            } else {
                if selectedWeekdays.count > 1 {
                    selectedWeekdays.remove(dayId)
                    haptic.impactOccurred()
                }
            }
            previousDraggedIndex = rawIndex
        }
    }
}

/// A single mechanical vertical rocker toggle switch cell
struct MechanicalSwitchCell: View {
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    private let switchWidth: CGFloat = 34
    private let switchHeight: CGFloat = 68
    private let thumbHeight: CGFloat = 32

    var body: some View {
        VStack(spacing: 8) {
            // Physical Rocker Bezel
            ZStack(alignment: isActive ? .top : .bottom) {
                // Bezel Inset Track
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: switchWidth, height: switchHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                isActive ? Color.cyan.opacity(0.3) : Color.black.opacity(0.2),
                                lineWidth: 1
                            )
                    )

                // Tactical Thumb Rocker
                VStack(spacing: 3) {
                    // Glowing Neon Cyan LED Slot
                    Capsule()
                        .fill(isActive ? Color.cyan : Color.secondary.opacity(0.3))
                        .frame(width: 14, height: 3)
                        .shadow(color: isActive ? Color.cyan.opacity(0.9) : .clear, radius: 4, y: 0)
                        .padding(.top, 4)

                    // Knurled Grip Texture Lines
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.primary.opacity(isActive ? 0.25 : 0.12))
                            .frame(width: 16, height: 1.5)
                        Rectangle()
                            .fill(Color.primary.opacity(isActive ? 0.25 : 0.12))
                            .frame(width: 16, height: 1.5)
                        Rectangle()
                            .fill(Color.primary.opacity(isActive ? 0.25 : 0.12))
                            .frame(width: 16, height: 1.5)
                    }
                    .padding(.vertical, 2)
                }
                .frame(width: switchWidth - 4, height: thumbHeight)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? Color(.secondarySystemGroupedBackground) : Color(.tertiarySystemBackground))
                        .shadow(color: Color.black.opacity(0.25), radius: 2, y: isActive ? 1 : -1)
                )
                .padding(2)
                .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isActive)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Day Label
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .tracking(0.5)
        }
    }
}
