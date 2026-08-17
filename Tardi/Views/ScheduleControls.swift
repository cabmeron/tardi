import SwiftUI
import UIKit

/// A compact, animated two-option toggle used for "Repeats" vs "Once"
struct SlidingSegmentedControl<Option: Hashable & Identifiable, Label: View>: View {
    let options: [Option]
    @Binding var selection: Option
    @ViewBuilder let label: (Option) -> Label

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                ZStack {
                    if selection == option {
                        Capsule()
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "highlight", in: namespace)
                    }
                    label(option)
                        .foregroundStyle(selection == option ? .white : .primary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .contentShape(Capsule())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection = option
                    }
                }
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
    }
}

/// Weekday selector you paint across with a drag instead of tapping each circle individually
struct WeekdayDragPicker: View {
    @Binding var selectedWeekdays: Set<Int>

    @State private var dragIsSelecting: Bool?

    private let symbols = Calendar.current.veryShortWeekdaySymbols
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / 7
            HStack(spacing: 0) {
                ForEach(1...7, id: \.self) { weekday in
                    dayCircle(weekday)
                        .frame(width: cellWidth)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in handleDrag(at: value.location.x, cellWidth: cellWidth) }
                    .onEnded { _ in dragIsSelecting = nil }
            )
        }
        .frame(height: 36)
    }

    private func dayCircle(_ weekday: Int) -> some View {
        let isSelected = selectedWeekdays.contains(weekday)
        return Text(symbols[weekday - 1])
            .font(.system(.callout, design: .rounded, weight: .bold))
            .frame(width: 34, height: 34)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Circle())
            .scaleEffect(isSelected ? 1.08 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
    }

    private func handleDrag(at x: CGFloat, cellWidth: CGFloat) {
        guard cellWidth > 0 else { return }
        let index = Int(x / cellWidth)
        guard index >= 0, index < 7 else { return }
        let weekday = index + 1

        if dragIsSelecting == nil {
            dragIsSelecting = !selectedWeekdays.contains(weekday)
        }
        guard let isSelecting = dragIsSelecting else { return }

        if isSelecting, selectedWeekdays.insert(weekday).inserted {
            haptic.impactOccurred()
        } else if !isSelecting, selectedWeekdays.remove(weekday) != nil {
            haptic.impactOccurred()
        }
    }
}

/// A big readable time label riding on top of a slider spanning the full day
struct TimeOfDaySlider: View {
    @Binding var time: Date

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isDaytime ? "sun.max.fill" : "moon.stars.fill")
                    .foregroundStyle(isDaytime ? .orange : .indigo)
                Text(time.formatted(date: .omitted, time: .shortened))
                    .font(.system(.title2, design: .rounded, weight: .bold))
            }
            Slider(value: minutesBinding, in: 0...1435, step: 5) { editing in
                if !editing { haptic.impactOccurred() }
            }
        }
    }

    private var isDaytime: Bool {
        (6..<20).contains(Calendar.current.component(.hour, from: time))
    }

    private var minutesBinding: Binding<Double> {
        Binding(
            get: {
                let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                return Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
            },
            set: { newValue in
                let totalMinutes = Int(newValue.rounded())
                var components = Calendar.current.dateComponents([.year, .month, .day], from: time)
                components.hour = totalMinutes / 60
                components.minute = totalMinutes % 60
                if let date = Calendar.current.date(from: components) {
                    time = date
                }
            }
        )
    }
}
