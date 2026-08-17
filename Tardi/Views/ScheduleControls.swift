import SwiftUI
import UIKit

// MARK: - Concept 4: Solar Daylight Arc Picker (Time of Day)

/// An architectural, circadian daylight arc representing the 24-hour cycle from sunrise
/// to sunset and night, featuring a draggable celestial indicator, stepper micro-nudges,
/// and ambient daylight lighting.
struct SolarDaylightArcPicker: View {
    @Binding var time: Date

    @State private var isDragging = false
    @State private var previousNotch: Int = -1

    private let arcWidth: CGFloat = 260
    private let arcHeight: CGFloat = 135
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var calendar: Calendar { .current }

    private var totalMinutes: Int {
        let h = calendar.component(.hour, from: time)
        let m = calendar.component(.minute, from: time)
        return h * 60 + m
    }

    /// Progress across the 24-hour day [0, 1]
    private var dayProgress: Double {
        Double(totalMinutes) / 1440.0
    }

    private var isDaytime: Bool {
        let hour = calendar.component(.hour, from: time)
        return hour >= 6 && hour < 19
    }

    var body: some View {
        VStack(spacing: 16) {
            // 1. Solar Arc & Celestial Knob
            ZStack {
                // Arc Background Track
                SolarArcShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.4),
                                Color.yellow.opacity(0.7),
                                Color.orange.opacity(0.8),
                                Color.indigo.opacity(0.6),
                                Color.purple.opacity(0.4)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: arcWidth, height: arcHeight)

                // Reference Celestial Icons Along Arc
                celestialMilestoneIcons

                // Draggable Sun / Moon Knob
                knobView
            }
            .frame(width: arcWidth + 30, height: arcHeight + 30)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(at: value.location)
                    }
                    .onEnded { _ in
                        isDragging = false
                        previousNotch = -1
                    }
            )

            // 2. Digital Readout with Symmetrical Stepper Buttons
            HStack(spacing: 16) {
                // -5m Nudge
                Button {
                    stepMinutes(-5)
                } label: {
                    Text("-5m")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.secondary.opacity(0.18), lineWidth: 0.8))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                // Large Centered Digital Readout
                VStack(spacing: 2) {
                    Text(time.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: isDaytime ? "sun.max.fill" : "moon.stars.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isDaytime ? .orange : .indigo)
                        Text(timeOfDayLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)
                    }
                }
                .frame(minWidth: 140)

                // +5m Nudge
                Button {
                    stepMinutes(5)
                } label: {
                    Text("+5m")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.secondary.opacity(0.18), lineWidth: 0.8))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Subviews

    private var celestialMilestoneIcons: some View {
        ZStack {
            // Sunrise (6 AM -> progress ~0.25)
            let pSunrise = pointOnArc(progress: 0.25)
            Image(systemName: "sunrise.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .position(x: pSunrise.x - 14, y: pSunrise.y + 16)

            // Midday (12 PM -> progress 0.50)
            let pNoon = pointOnArc(progress: 0.50)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)
                .position(x: pNoon.x, y: pNoon.y - 18)

            // Sunset (6 PM -> progress ~0.75)
            let pSunset = pointOnArc(progress: 0.75)
            Image(systemName: "sunset.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .position(x: pSunset.x + 14, y: pSunset.y + 16)

            // Night Moon (Midnight -> progress 1.0)
            let pNight = pointOnArc(progress: 0.98)
            Image(systemName: "moon.fill")
                .font(.system(size: 11))
                .foregroundStyle(.indigo)
                .position(x: pNight.x + 18, y: pNight.y + 14)
        }
    }

    private var knobView: some View {
        let point = pointOnArc(progress: dayProgress)

        return ZStack {
            // Ambient glowing halo
            Circle()
                .fill(isDaytime ? Color.yellow.opacity(0.35) : Color.indigo.opacity(0.35))
                .frame(width: isDragging ? 32 : 24, height: isDragging ? 32 : 24)

            // Solid celestial indicator
            Circle()
                .fill(isDaytime ? Color.yellow : Color.white)
                .frame(width: 16, height: 16)
                .overlay(
                    Image(systemName: isDaytime ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isDaytime ? Color.orange : Color.indigo)
                )
                .shadow(color: (isDaytime ? Color.yellow : Color.indigo).opacity(0.6), radius: 6, y: 1)
        }
        .position(point)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: dayProgress)
    }

    private var timeOfDayLabel: String {
        let hour = calendar.component(.hour, from: time)
        switch hour {
        case 5..<12: return "MORNING"
        case 12..<17: return "AFTERNOON"
        case 17..<21: return "EVENING"
        default: return "NIGHT"
        }
    }

    // MARK: - Geometry & Drag Math

    /// Calculates (x, y) along the parabolic daylight arch
    private func pointOnArc(progress: Double) -> CGPoint {
        let p = max(min(progress, 1.0), 0.0)
        let x = 15 + p * arcWidth
        let normalizedX = (p - 0.5) * 2.0
        let y = 20 + (normalizedX * normalizedX) * (arcHeight - 20)
        return CGPoint(x: x, y: y)
    }

    private func handleDrag(at point: CGPoint) {
        let adjustedX = point.x - 15
        let rawProgress = max(min(adjustedX / arcWidth, 1.0), 0.0)

        let totalMins = Int(rawProgress * 1440.0)
        let snappedMins = (Int(round(Double(totalMins) / 5.0)) * 5) % 1440
        let notchIndex = snappedMins / 5

        if notchIndex != previousNotch {
            haptic.impactOccurred()
            previousNotch = notchIndex
        }

        var components = calendar.dateComponents([.year, .month, .day], from: time)
        components.hour = snappedMins / 60
        components.minute = snappedMins % 60
        components.second = 0

        if let newDate = calendar.date(from: components) {
            time = newDate
        }
        isDragging = true
    }

    private func stepMinutes(_ step: Int) {
        haptic.impactOccurred()
        if let newDate = calendar.date(byAdding: .minute, value: step, to: time) {
            withAnimation(.spring(response: 0.25)) {
                time = newDate
            }
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
