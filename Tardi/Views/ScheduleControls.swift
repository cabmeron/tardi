import SwiftUI
import UIKit
import Foundation
import AudioToolbox
import AVFoundation

// MARK: - ASMR Tactile Acoustic Engine (Procedural Synthesis & Dynamic Tapering)

/// High-fidelity, zero-latency in-memory acoustic synthesizer.
/// Produces velvety warm ASMR micro-ticks with velocity tapering for dials/sliders,
/// and deep, resonant physical mechanical relay thumps for rocker toggles.
final class ASMRSoundEngine: @unchecked Sendable {
    static let shared = ASMRSoundEngine()

    private var tickPlayerPool: [[AVAudioPlayer]] = []
    private var thumpPlayers: [AVAudioPlayer] = []
    private var thumpIndex = 0
    private var tickIndex = 0

    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        // 1. Generate 8 Tapering Intensity Levels of ASMR Micro-Ticks
        for tier in 0..<8 {
            let volume = 0.08 + (Double(tier) / 7.0) * 0.72
            let samples = Self.generateTickSamples(volume: volume)
            let wavData = Self.createWavData(samples: samples)
            var pool: [AVAudioPlayer] = []
            for _ in 0..<4 {
                if let player = try? AVAudioPlayer(data: wavData) {
                    player.prepareToPlay()
                    pool.append(player)
                }
            }
            tickPlayerPool.append(pool)
        }

        // 2. Generate Deep Resonant ASMR Mechanical Thump
        let thumpSamples = Self.generateThumpSamples()
        let thumpData = Self.createWavData(samples: thumpSamples)
        for _ in 0..<4 {
            if let player = try? AVAudioPlayer(data: thumpData) {
                player.prepareToPlay()
                thumpPlayers.append(player)
            }
        }
    }

    /// Play a warm ASMR rotary tick whose acoustic energy tapers with velocity
    func playTick(intensity: Double = 0.5) {
        guard !tickPlayerPool.isEmpty else { return }
        let clamped = max(0.0, min(1.0, intensity))
        let tierIndex = min(tickPlayerPool.count - 1, Int(clamped * Double(tickPlayerPool.count)))
        let pool = tickPlayerPool[tierIndex]
        guard !pool.isEmpty else { return }

        tickIndex = (tickIndex + 1) % pool.count
        let player = pool[tickIndex]
        player.currentTime = 0
        player.play()
    }

    /// Play a deep, satisfying ASMR mechanical relay thump
    func playThump() {
        guard !thumpPlayers.isEmpty else { return }
        thumpIndex = (thumpIndex + 1) % thumpPlayers.count
        let player = thumpPlayers[thumpIndex]
        player.currentTime = 0
        player.play()
    }

    // MARK: - Procedural Waveform Synthesizers

    private static func generateTickSamples(volume: Double) -> [Int16] {
        let sampleRate = 44100.0
        let duration = 0.009 // 9 ms micro-transient
        let totalSamples = Int(sampleRate * duration)
        var samples = [Int16]()
        samples.reserveCapacity(totalSamples)

        // Warm resonant wood/plastic micro-tock: 840Hz fundamental with rapid exponential damping
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let decay = exp(-t / 0.0020)
            let tone = sin(2.0 * .pi * 840.0 * t) * 0.72 + sin(2.0 * .pi * 1680.0 * t) * 0.18 + (Double.random(in: -0.15...0.15) * exp(-t / 0.0008))
            let sampleVal = tone * decay * volume * 32767.0
            let clamped = max(-32767.0, min(32767.0, sampleVal))
            samples.append(Int16(clamped))
        }
        return samples
    }

    private static func generateThumpSamples() -> [Int16] {
        let sampleRate = 44100.0
        let duration = 0.055 // 55 ms
        let totalSamples = Int(sampleRate * duration)
        var samples = [Int16]()
        samples.reserveCapacity(totalSamples)

        // Deep mechanical relay thump: 68Hz sub-bass + 125Hz mechanical body + latch snap
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let bodyDecay = exp(-t / 0.017)
            let clickDecay = exp(-t / 0.0025)

            let subBass = sin(2.0 * .pi * 68.0 * t) * 0.65
            let body = sin(2.0 * .pi * 125.0 * t) * 0.35
            let latchClick = sin(2.0 * .pi * 2400.0 * t) * 0.38 * clickDecay

            let combined = (subBass + body) * bodyDecay * 0.88 + latchClick
            let sampleVal = combined * 32767.0
            let clamped = max(-32767.0, min(32767.0, sampleVal))
            samples.append(Int16(clamped))
        }
        return samples
    }

    private static func createWavData(samples: [Int16], sampleRate: Int = 44100) -> Data {
        var data = Data()
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = Int32(sampleRate * Int(numChannels) * Int(bitsPerSample / 8))
        let blockAlign = Int16(numChannels * (bitsPerSample / 8))
        let subChunk2Size = Int32(samples.count * 2)
        let chunkSize = 36 + subChunk2Size

        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        data.append(contentsOf: "fmt ".utf8)
        let subChunk1Size: Int32 = 16
        let audioFormat: Int16 = 1
        data.append(contentsOf: withUnsafeBytes(of: subChunk1Size.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        let sampleRateInt32 = Int32(sampleRate)
        data.append(contentsOf: withUnsafeBytes(of: sampleRateInt32.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: subChunk2Size.littleEndian) { Array($0) })

        for sample in samples {
            let le = sample.littleEndian
            data.append(contentsOf: withUnsafeBytes(of: le) { Array($0) })
        }

        return data
    }
}

// MARK: - Concept 4: Tactile Neumorphic Time Slider

/// An architectural, highly tactile neumorphic time slider representing the 24-hour cycle.
/// Features a smooth continuous horizontal pill-shaped track embedded into a matte surface,
/// a raised extruded cylindrical slider thumb with soft diffused drop shadows, micro-engraved
/// time interval ticks (Hour & Period), and a frosted inner luminescence under the active node.
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

    private var formattedTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    // Key time ticks across 24h: 12 AM, 4 AM, 8 AM, 12 PM, 4 PM, 8 PM, 12 AM
    private let timeIntervals: [(hour: String, period: String)] = [
        ("12", "AM"),
        ("4", "AM"),
        ("8", "AM"),
        ("12", "PM"),
        ("4", "PM"),
        ("8", "PM"),
        ("12", "AM")
    ]

    var body: some View {
        VStack(spacing: 14) {
            // 1. Prominent Digital Time Readout
            VStack(spacing: 2) {
                Text(formattedTimeString)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Text("TARGET DEADLINE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
            }
            .padding(.top, 2)

            // 2. Continuous Horizontal Pill-Shaped Neumorphic Track
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let trackHeight: CGFloat = 46
                let knobWidth: CGFloat = 48
                let knobHeight: CGFloat = 36
                let usableWidth = max(totalWidth - knobWidth, 1.0)
                let knobX = CGFloat(dayProgress) * usableWidth

                ZStack(alignment: .leading) {
                    // A. Recessed Pill-Shaped Channel (Debossed into matte surface)
                    RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(height: trackHeight)
                        .overlay(
                            // Top/Left Inset Dark Shadow
                            RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                                .stroke(Color.black.opacity(0.18), lineWidth: 1.5)
                                .blur(radius: 1.5)
                                .offset(x: 1, y: 1.5)
                                .mask(RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous))
                        )
                        .overlay(
                            // Bottom/Right Inset Light Highlight
                            RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                .blur(radius: 1.5)
                                .offset(x: -1, y: -1.5)
                                .mask(RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous))
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)

                    // B. Micro-Engraved Typographic Time Intervals (Hour & Period)
                    HStack(spacing: 0) {
                        ForEach(0..<timeIntervals.count, id: \.self) { i in
                            if i > 0 { Spacer() }
                            let item = timeIntervals[i]
                            VStack(spacing: 0) {
                                Text(item.hour)
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.secondary.opacity(0.8))
                                Text(item.period)
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.secondary.opacity(0.6))
                            }
                            .frame(width: 26)
                        }
                    }
                    .padding(.horizontal, knobWidth / 2)
                    .frame(height: trackHeight)

                    // C. Frosted Luminescent Glow Under Active Thumb
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.45))
                        .frame(width: knobWidth + 8, height: knobHeight + 6)
                        .blur(radius: 6)
                        .offset(x: knobX - 4, y: 0)

                    // D. Raised Extruded Cylindrical Thumb Slider
                    ZStack {
                        // Ambient Drop Shadow
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .frame(width: knobWidth, height: knobHeight)
                            .shadow(color: Color.white.opacity(0.85), radius: 4, x: -3, y: -3)
                            .shadow(color: Color.black.opacity(0.24), radius: 6, x: 3.5, y: 4)

                        // Subtle Micro Bevel Edge Highlight
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.7), Color.black.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                            .frame(width: knobWidth, height: knobHeight)

                        // Thumb Content: Active Formatted Time
                        let h = calendar.component(.hour, from: time)
                        let m = calendar.component(.minute, from: time)
                        let displayHour = h % 12 == 0 ? 12 : h % 12
                        let period = h >= 12 ? "PM" : "AM"

                        VStack(spacing: 0) {
                            Text(String(format: "%d:%02d", displayHour, m))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(period)
                                .font(.system(size: 7.5, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .offset(x: knobX)
                }
                .frame(height: trackHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let progress = max(0.0, min(1.0, Double(value.location.x - (knobWidth / 2)) / Double(usableWidth)))
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
            .frame(height: 48)
        }
        .padding(.vertical, 4)
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

// MARK: - Active Days Switchboard Picker (Unified 80% Schedule / 20% Time Controller)

/// An architectural, ultra-tactile unified scheduling module.
/// - Left 80%: Smoothly switches between Weekly Toggleable Switches and Horizontal Date Slider based on the Repeat toggle.
/// - Right 20%: Fixed vertical scrollable/draggable Time Pill slider that ALWAYS stays active for time selection.
struct ActiveDaysSwitchboardPicker: View {
    @Binding var selectedWeekdays: Set<Int> // Standard Calendar: 1 = Sun, 2 = Mon ... 7 = Sat
    @Binding var isOneTime: Bool
    @Binding var oneTimeDate: Date
    @Binding var deadlineTime: Date
    @State var repeatWeeks: Int = 4 // Default repeat duration

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private var calendar: Calendar { .current }

    private var formattedDateOrDays: String {
        if selectedWeekdays.count == 7 {
            return "EVERY DAY"
        } else if selectedWeekdays == [2, 3, 4, 5, 6] {
            return "WEEKDAYS"
        } else if selectedWeekdays == [1, 7] {
            return "WEEKENDS"
        } else {
            let dayMap: [Int: String] = [2: "MON", 3: "TUE", 4: "WED", 5: "THU", 6: "FRI", 7: "SAT", 1: "SUN"]
            let sorted = [2, 3, 4, 5, 6, 7, 1].filter { selectedWeekdays.contains($0) }.compactMap { dayMap[$0] }
            return sorted.isEmpty ? "SELECT DAYS" : sorted.joined(separator: ", ")
        }
    }

    private var formattedDeadlineTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: isOneTime ? oneTimeDate : deadlineTime)
    }

    var body: some View {
        VStack(spacing: 12) {
            // 1. Repeat Weekly Mode Toggle + Tactile [ - ] N WEEKS [ + ] Stepper
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: isOneTime ? "calendar" : "repeat")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black)

                    Text(isOneTime ? "Single Week" : "Repeats Weekly")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()

                if !isOneTime {
                    // Tactile Stepper: [ - ] N WEEKS [ + ]
                    HStack(spacing: 6) {
                        Button(action: decrementWeeks) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(repeatWeeks > 1 ? Color.black : Color.secondary.opacity(0.35))
                                .frame(width: 24, height: 24)
                                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(repeatWeeks <= 1)

                        Text(repeatWeeks == 1 ? "1 WK" : "\(repeatWeeks) WKS")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.black)
                            .frame(minWidth: 44)

                        Button(action: incrementWeeks) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(repeatWeeks < 52 ? Color.black : Color.secondary.opacity(0.35))
                                .frame(width: 24, height: 24)
                                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(repeatWeeks >= 52)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                Toggle("", isOn: Binding(
                    get: { !isOneTime },
                    set: { repeats in
                        heavyHaptic.impactOccurred(intensity: 0.95)
                        ASMRSoundEngine.shared.playThump()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isOneTime = !repeats
                            if repeats && selectedWeekdays.isEmpty {
                                selectedWeekdays = [2, 3, 4, 5, 6]
                            }
                        }
                    }
                ))
                .tint(Color.black)
                .labelsHidden()
            }

            // Dual Dynamic Status Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedDateOrDays)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(!isOneTime ? "ACTIVE DAYS (\(repeatWeeks) \(repeatWeeks == 1 ? "WEEK" : "WEEKS"))" : "ACTIVE DAYS (SINGLE WEEK)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedDeadlineTime)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black)
                    Text("DEADLINE TIME")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                }
            }
            .padding(.horizontal, 2)

            // 2. Symmetrical Layout: Equal distance from left and right edges of parent container
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let height: CGFloat = 88
                let dialWidth: CGFloat = 46 // 16 (ticks) + 4 (spacing) + 26 (barrel)
                let spacing: CGFloat = 12
                let leftWidth = max(totalWidth - dialWidth - spacing, 1.0)

                HStack(spacing: spacing) {
                    // LEFT: 7 Mechanical Rocker Day Switches (Mon..Sun)
                    NeumorphicWeeklySwitchboardView(selectedWeekdays: $selectedWeekdays)
                        .frame(width: leftWidth, height: height, alignment: .leading)

                    // RIGHT: Vertical Infinite Rotary Time Dial Pill
                    NeumorphicVerticalTimePillView(time: isOneTime ? $oneTimeDate : $deadlineTime)
                        .frame(width: dialWidth, height: height, alignment: .trailing)
                }
            }
            .frame(height: 88)
        }
        .padding(.vertical, 2)
    }

    private func incrementWeeks() {
        if repeatWeeks < 52 {
            haptic.impactOccurred(intensity: 0.6)
            ASMRSoundEngine.shared.playTick(intensity: 0.65)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                repeatWeeks += 1
            }
        }
    }

    private func decrementWeeks() {
        if repeatWeeks > 1 {
            haptic.impactOccurred(intensity: 0.6)
            ASMRSoundEngine.shared.playTick(intensity: 0.65)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                repeatWeeks -= 1
            }
        }
    }
}

/// The 7 tactile rocker switches for Monday..Sunday, formatted cleanly to fit the left 80% slot
struct NeumorphicWeeklySwitchboardView: View {
    @Binding var selectedWeekdays: Set<Int>

    @State private var dragIsSelecting: Bool?
    @State private var previousDraggedIndex: Int = -1

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    private let dayOrder: [(id: Int, short: String, label: String)] = [
        (2, "M", "Mon"),
        (3, "T", "Tue"),
        (4, "W", "Wed"),
        (5, "T", "Thu"),
        (6, "F", "Fri"),
        (7, "S", "Sat"),
        (1, "S", "Sun")
    ]

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let slotWidth = totalWidth / 7.0

            HStack(spacing: 0) {
                ForEach(Array(dayOrder.enumerated()), id: \.element.id) { index, item in
                    let isActive = selectedWeekdays.contains(item.id)
                    MechanicalSwitchCell(
                        label: item.label.uppercased(),
                        isActive: isActive,
                        onTap: { toggleDay(item.id) }
                    )
                    .frame(width: slotWidth)
                }
            }
            .frame(height: geometry.size.height, alignment: .center)
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
        .frame(height: 88)
    }

    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)

    private func toggleDay(_ id: Int) {
        heavyHaptic.impactOccurred(intensity: 1.0)
        ASMRSoundEngine.shared.playThump()
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
            heavyHaptic.impactOccurred(intensity: 0.85)
            ASMRSoundEngine.shared.playThump()
            if isSelecting {
                selectedWeekdays.insert(dayId)
            } else {
                if selectedWeekdays.count > 1 {
                    selectedWeekdays.remove(dayId)
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
                                isActive ? Color.black.opacity(0.35) : Color.black.opacity(0.15),
                                lineWidth: 1
                            )
                    )

                // Tactical Thumb Rocker
                VStack(spacing: 3) {
                    // Tactile Indicator Slot
                    Capsule()
                        .fill(isActive ? Color.white : Color.secondary.opacity(0.3))
                        .frame(width: 14, height: 3)
                        .padding(.top, 4)

                    // Knurled Grip Texture Lines
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(isActive ? Color.white.opacity(0.6) : Color.primary.opacity(0.12))
                            .frame(width: 16, height: 1.5)
                        Rectangle()
                            .fill(isActive ? Color.white.opacity(0.6) : Color.primary.opacity(0.12))
                            .frame(width: 16, height: 1.5)
                        Rectangle()
                            .fill(isActive ? Color.white.opacity(0.6) : Color.primary.opacity(0.12))
                            .frame(width: 16, height: 1.5)
                    }
                    .padding(.vertical, 2)
                }
                .frame(width: switchWidth - 4, height: thumbHeight)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? Color.black : Color(.secondarySystemGroupedBackground))
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
                .foregroundStyle(isActive ? Color.black : Color.secondary)
                .tracking(0.5)
        }
    }
}

// MARK: - Neumorphic Tactile Date Scrubber Picker

/// A minimalist, highly tactile neumorphic date selection component.
/// Features a smooth continuous horizontal pill-shaped track embedded into a matte surface,
/// an extruded cylindrical slider thumb with soft diffused drop shadows, micro-engraved
/// date interval ticks (Day & Month), and a frosted inner luminescence under the active node.
struct NeumorphicDateScrubberPicker: View {
    @Binding var selectedDate: Date
    let numberOfDays: Int = 14

    @State private var isDragging = false
    @State private var dragProgress: Double? = nil
    @State private var previousNotch: Int = -1

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var calendar: Calendar { .current }

    private var availableDates: [Date] {
        let start = calendar.startOfDay(for: Date())
        return (0..<numberOfDays).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var selectedIndex: Int {
        let start = calendar.startOfDay(for: Date())
        let current = calendar.startOfDay(for: selectedDate)
        let diff = calendar.dateComponents([.day], from: start, to: current).day ?? 0
        return max(0, min(numberOfDays - 1, diff))
    }

    private var currentProgress: Double {
        if let drag = dragProgress {
            return drag
        }
        return Double(selectedIndex) / Double(max(1, numberOfDays - 1))
    }

    private var formattedActiveDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        VStack(spacing: 12) {
            // 1. Prominent Active Date Readout
            VStack(spacing: 2) {
                Text(formattedActiveDate.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .tracking(0.8)

                Text("SELECTED TARGET DATE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }
            .padding(.top, 2)

            // 2. Neumorphic Date Pill Track
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let trackHeight: CGFloat = 46
                let knobWidth: CGFloat = 44
                let knobHeight: CGFloat = 36
                let usableWidth = max(totalWidth - knobWidth, 1.0)
                let knobX = CGFloat(currentProgress) * usableWidth

                ZStack(alignment: .leading) {
                    // A. Recessed Pill-Shaped Base Channel
                    RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(height: trackHeight)
                        .overlay(
                            // Top/Left Inset Dark Shadow for tactile debossing
                            RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                                .stroke(Color.black.opacity(0.18), lineWidth: 1.5)
                                .blur(radius: 1.5)
                                .offset(x: 1, y: 1.5)
                                .mask(RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous))
                        )
                        .overlay(
                            // Bottom/Right Inset Light Highlight
                            RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                .blur(radius: 1.5)
                                .offset(x: -1, y: -1.5)
                                .mask(RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous))
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)

                    // B. Micro-Engraved Typographic Date Intervals
                    HStack(spacing: 0) {
                        ForEach(0..<min(7, numberOfDays), id: \.self) { i in
                            if i > 0 { Spacer() }
                            let dateIndex = i * (numberOfDays - 1) / 6
                            let date = availableDates.indices.contains(dateIndex) ? availableDates[dateIndex] : Date()
                            let dayNum = calendar.component(.day, from: date)
                            let monthIdx = max(0, min(11, calendar.component(.month, from: date) - 1))
                            let monthName = calendar.shortMonthSymbols[monthIdx].uppercased()

                            VStack(spacing: 0) {
                                Text("\(dayNum)")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.secondary.opacity(0.8))
                                Text(monthName)
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.secondary.opacity(0.6))
                            }
                            .frame(width: 28)
                        }
                    }
                    .padding(.horizontal, knobWidth / 2)
                    .frame(height: trackHeight)

                    // C. Frosted Luminescent Glow Under Active Thumb
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.45))
                        .frame(width: knobWidth + 8, height: knobHeight + 6)
                        .blur(radius: 5)
                        .offset(x: knobX - 4, y: 0)

                    // D. Raised Extruded Cylindrical Thumb Slider
                    ZStack {
                        // Ambient Drop Shadow
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .frame(width: knobWidth, height: knobHeight)
                            .shadow(color: Color.white.opacity(0.85), radius: 4, x: -3, y: -3)
                            .shadow(color: Color.black.opacity(0.24), radius: 6, x: 3.5, y: 4)

                        // Subtle Micro Bevel Edge Highlight
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.7), Color.black.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                            .frame(width: knobWidth, height: knobHeight)

                        // Thumb Content: Active Day Number & Month
                        let activeDate = availableDates.indices.contains(selectedIndex) ? availableDates[selectedIndex] : Date()
                        let activeDay = calendar.component(.day, from: activeDate)
                        let activeMonthIdx = max(0, min(11, calendar.component(.month, from: activeDate) - 1))
                        let activeMonth = calendar.shortMonthSymbols[activeMonthIdx].uppercased()

                        VStack(spacing: 0) {
                            Text("\(activeDay)")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(activeMonth)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.black)
                        }
                    }
                    .offset(x: knobX)
                }
                .frame(height: trackHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let progress = max(0.0, min(1.0, Double(value.location.x - (knobWidth / 2)) / Double(usableWidth)))
                            dragProgress = progress
                            updateDate(from: progress)
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragProgress = nil
                            previousNotch = -1
                        }
                )
            }
            .frame(height: 48)
        }
        .padding(.vertical, 4)
    }

    private func updateDate(from progress: Double) {
        let index = Int(round(progress * Double(numberOfDays - 1)))
        let clampedIndex = max(0, min(numberOfDays - 1, index))

        if clampedIndex != previousNotch {
            haptic.impactOccurred(intensity: 0.7)
            previousNotch = clampedIndex
            if availableDates.indices.contains(clampedIndex) {
                let newDate = availableDates[clampedIndex]
                let hour = calendar.component(.hour, from: selectedDate)
                let minute = calendar.component(.minute, from: selectedDate)
                if let updated = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: newDate) {
                    selectedDate = updated
                } else {
                    selectedDate = newDate
                }
            }
        }
    }
}

// MARK: - Concept 5: Unified Tactile Date & Time Composite Picker (80% / 20% Layout)

/// A unified, highly tactile neumorphic scheduling component.
/// Left 80%: Continuous horizontal date slider with micro-engraved dates and tactile cylindrical thumb.
/// Right 20%: Single vertical up/down scrollable/draggable pill UI element to select the time.
struct TactileDateTimeCompositePicker: View {
    @Binding var selectedDate: Date
    @Binding var selectedTime: Date

    private var calendar: Calendar { .current }

    private var formattedDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: selectedDate).uppercased()
    }

    private var formattedTimeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: selectedTime)
    }

    var body: some View {
        VStack(spacing: 12) {
            // 1. Dual Digital Readout (Date on Left, Time on Right)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedDateText)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("TARGET DATE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedTimeText)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black)
                    Text("DEADLINE TIME")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                }
            }
            .padding(.horizontal, 4)

            // 2. Symmetrical Layout: Equal distance from left and right edges of parent container
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let height: CGFloat = 88
                let dialWidth: CGFloat = 46
                let spacing: CGFloat = 12
                let dateWidth = max(totalWidth - dialWidth - spacing, 1.0)

                HStack(spacing: spacing) {
                    // Left: Horizontal Date Slider
                    NeumorphicDateTrackView(selectedDate: $selectedDate)
                        .frame(width: dateWidth, height: height, alignment: .leading)

                    // Right: Vertical Time Scrollable Pill
                    NeumorphicVerticalTimePillView(time: $selectedTime)
                        .frame(width: dialWidth, height: height, alignment: .trailing)
                }
            }
            .frame(height: 88)
        }
        .padding(.vertical, 4)
    }
}

/// Horizontal Date Slider section with micro-engraved days, pill track, and tactile thumb
struct NeumorphicDateTrackView: View {
    @Binding var selectedDate: Date
    let numberOfDays: Int = 14

    @State private var isDragging = false
    @State private var dragProgress: Double? = nil
    @State private var previousNotch: Int = -1

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var calendar: Calendar { .current }

    private var availableDates: [Date] {
        let start = calendar.startOfDay(for: Date())
        return (0..<numberOfDays).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var selectedIndex: Int {
        let start = calendar.startOfDay(for: Date())
        let current = calendar.startOfDay(for: selectedDate)
        let diff = calendar.dateComponents([.day], from: start, to: current).day ?? 0
        return max(0, min(numberOfDays - 1, diff))
    }

    private var currentProgress: Double {
        if let drag = dragProgress {
            return drag
        }
        return Double(selectedIndex) / Double(max(1, numberOfDays - 1))
    }

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let knobWidth: CGFloat = 38
            let knobHeight: CGFloat = 34
            let trackHeight: CGFloat = 24
            let usableWidth = max(totalWidth - knobWidth, 1.0)
            let knobX = CGFloat(currentProgress) * usableWidth

            VStack(spacing: 8) {
                // Top Day Numbers Scale
                HStack(spacing: 0) {
                    ForEach(0..<min(8, numberOfDays), id: \.self) { i in
                        if i > 0 { Spacer() }
                        let dateIndex = i * (numberOfDays - 1) / 7
                        let date = availableDates.indices.contains(dateIndex) ? availableDates[dateIndex] : Date()
                        let dayNum = calendar.component(.day, from: date)
                        let isSelected = selectedIndex == dateIndex

                        Text("\(dayNum)")
                            .font(.system(size: 11, weight: isSelected ? .black : .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.7))
                            .frame(width: 22)
                    }
                }
                .padding(.horizontal, knobWidth / 2)

                // Middle Debossed Horizontal Pill Track & Extruded Cylindrical Thumb
                ZStack(alignment: .leading) {
                    // Debossed Pill Channel
                    RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(height: trackHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                                .stroke(Color.black.opacity(0.16), lineWidth: 1.5)
                                .blur(radius: 1.5)
                                .offset(x: 1, y: 1.5)
                                .mask(RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                .blur(radius: 1.5)
                                .offset(x: -1, y: -1.5)
                                .mask(RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous))
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)

                    // Active Frosted Glow
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.4))
                        .frame(width: knobWidth + 6, height: knobHeight + 4)
                        .blur(radius: 5)
                        .offset(x: knobX - 3, y: 0)

                    // Raised Cylindrical Thumb Knob
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .frame(width: knobWidth, height: knobHeight)
                            .shadow(color: Color.white.opacity(0.85), radius: 3, x: -2.5, y: -2.5)
                            .shadow(color: Color.black.opacity(0.22), radius: 5, x: 3, y: 3.5)

                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.7), Color.black.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                            .frame(width: knobWidth, height: knobHeight)

                        // Vertical knurling ribs on thumb
                        HStack(spacing: 3) {
                            Capsule().fill(Color.primary.opacity(0.35)).frame(width: 2, height: 14)
                            Capsule().fill(Color.primary.opacity(0.35)).frame(width: 2, height: 14)
                            Capsule().fill(Color.primary.opacity(0.35)).frame(width: 2, height: 14)
                        }
                    }
                    .offset(x: knobX)
                }
                .frame(height: knobHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let progress = max(0.0, min(1.0, Double(value.location.x - (knobWidth / 2)) / Double(usableWidth)))
                            dragProgress = progress
                            updateDate(from: progress)
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragProgress = nil
                            previousNotch = -1
                        }
                )

                // Bottom Weekday Labels Scale
                HStack(spacing: 0) {
                    ForEach(0..<min(8, numberOfDays), id: \.self) { i in
                        if i > 0 { Spacer() }
                        let dateIndex = i * (numberOfDays - 1) / 7
                        let date = availableDates.indices.contains(dateIndex) ? availableDates[dateIndex] : Date()
                        let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
                        let isSelected = selectedIndex == dateIndex

                        Text(weekday)
                            .font(.system(size: 8, weight: isSelected ? .black : .bold, design: .monospaced))
                            .foregroundStyle(isSelected ? Color.black : Color.secondary.opacity(0.6))
                            .frame(width: 24)
                    }
                }
                .padding(.horizontal, knobWidth / 2)
            }
            .frame(height: geo.size.height, alignment: .center)
        }
    }

    private func updateDate(from progress: Double) {
        let index = Int(round(progress * Double(numberOfDays - 1)))
        let clampedIndex = max(0, min(numberOfDays - 1, index))

        if clampedIndex != previousNotch {
            haptic.impactOccurred(intensity: 0.7)
            ASMRSoundEngine.shared.playTick(intensity: 0.75)
            previousNotch = clampedIndex
            if availableDates.indices.contains(clampedIndex) {
                let newDate = availableDates[clampedIndex]
                let hour = calendar.component(.hour, from: selectedDate)
                let minute = calendar.component(.minute, from: selectedDate)
                if let updated = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: newDate) {
                    selectedDate = updated
                } else {
                    selectedDate = newDate
                }
            }
        }
    }
}

// MARK: - Concept 6: Infinite Tactile Ribbed Time Dial Thumbwheel with Inertial Momentum

/// An architectural, infinite rotary ribbed thumbwheel time dial.
/// Features a recessed mechanical pill cavity, an infinite rolling cylindrical barrel
/// with deeply knurled horizontal ridges, 3D perspective shading, endless cyclic wrapping (0:00 - 23:59),
/// velocity-driven inertial spinning physics on hard swipes, mechanical audio tick sounds, and tactile vibration.
struct NeumorphicVerticalTimePillView: View {
    @Binding var time: Date

    @State private var accumulatedDrag: CGFloat = 0.0
    @State private var lastDragY: CGFloat = 0.0
    @State private var spinTimer: Timer? = nil
    @State private var previousHapticDetent: Int = 0

    private let haptic = UIImpactFeedbackGenerator(style: .rigid)
    private var calendar: Calendar { .current }

    private let ribHeight: CGFloat = 6.0 // Distance between physical ridges
    private let minutesPerRib: Int = 5 // Standard 5 minutes per mechanical detent

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let wheelWidth: CGFloat = 26

            HStack(spacing: 4) {
                // Micro-engraved tick landmark dots / minute notches
                VStack(spacing: 0) {
                    let displayHour = calendar.component(.hour, from: time)
                    let hour12 = displayHour % 12 == 0 ? 12 : displayHour % 12
                    let period = displayHour >= 12 ? "P" : "A"

                    Text("\(hour12)\(period)")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.black)

                    Spacer()

                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 5, height: 1.5)

                    Spacer()

                    let m = calendar.component(.minute, from: time)
                    Text(String(format: ":%02d", m))
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                }
                .frame(width: 16, height: totalHeight - 6)

                // The Infinite Ribbed Rotating Barrel Wheel
                ZStack {
                    // 1. Debossed Housing Cavity
                    RoundedRectangle(cornerRadius: wheelWidth / 2, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: wheelWidth / 2, style: .continuous)
                                .stroke(Color.black.opacity(0.2), lineWidth: 1.5)
                        )
                        .overlay(
                            // Deep Inset Cavity Shadow
                            RoundedRectangle(cornerRadius: wheelWidth / 2, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.35), Color.clear, Color.black.opacity(0.35)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )

                    // 2. Rolling Ribbed Barrel Cylinder
                    let ribOffset = ((accumulatedDrag.truncatingRemainder(dividingBy: ribHeight)) + ribHeight).truncatingRemainder(dividingBy: ribHeight)
                    let numberOfVisibleRibs = Int(totalHeight / ribHeight) + 4

                    VStack(spacing: 0) {
                        ForEach(-2..<numberOfVisibleRibs, id: \.self) { _ in
                            VStack(spacing: 0) {
                                // Ridge Peak (Specular Highlight)
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.black.opacity(0.75),
                                                Color.gray.opacity(0.85),
                                                Color.black.opacity(0.9)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 2.2)

                                // Groove Valley (Deep Shadow)
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(height: ribHeight - 2.2)
                            }
                        }
                    }
                    .frame(width: wheelWidth - 2, height: totalHeight)
                    .offset(y: ribOffset)
                    .clipShape(RoundedRectangle(cornerRadius: (wheelWidth - 2) / 2, style: .continuous))

                    // 3. 3D Cylindrical Barrel Shading Overlay (Curvature horizon)
                    RoundedRectangle(cornerRadius: (wheelWidth - 2) / 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.black.opacity(0.92), location: 0.0),
                                    .init(color: Color.black.opacity(0.40), location: 0.18),
                                    .init(color: Color.white.opacity(0.18), location: 0.48),
                                    .init(color: Color.white.opacity(0.22), location: 0.52),
                                    .init(color: Color.black.opacity(0.40), location: 0.82),
                                    .init(color: Color.black.opacity(0.92), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                        .frame(width: wheelWidth - 2, height: totalHeight)

                    // 4. Center Optical Index Line
                    HStack {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 4, height: 2)
                            .shadow(color: Color.white, radius: 2)
                        Spacer()
                    }
                    .frame(width: wheelWidth)
                    .allowsHitTesting(false)

                    // 5. Outer Bezel Highlight Ring
                    RoundedRectangle(cornerRadius: wheelWidth / 2, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.black.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .allowsHitTesting(false)
                }
                .frame(width: wheelWidth, height: totalHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Brake any active inertial spin on user contact
                            stopInertialSpin()
                            haptic.prepare()

                            let delta = value.translation.height - lastDragY
                            lastDragY = value.translation.height
                            applyDragDelta(delta)
                        }
                        .onEnded { value in
                            lastDragY = 0

                            // Calculate swipe fling velocity for inertial physics
                            let predictedDelta = value.predictedEndTranslation.height - value.translation.height
                            let velocityY = value.velocity.height
                            let effectiveVelocity = abs(velocityY) > 50 ? velocityY : predictedDelta * 2.0

                            if abs(effectiveVelocity) > 80 {
                                startInertialSpin(initialVelocity: effectiveVelocity)
                            }
                        }
                )
            }
            .frame(width: geo.size.width, height: totalHeight, alignment: .trailing)
        }
        .onDisappear {
            stopInertialSpin()
        }
    }

    // MARK: - Inertial Physics Engine & Continuous Looping

    private func applyDragDelta(_ deltaY: CGFloat, overrideIntensity: Double? = nil) {
        accumulatedDrag += deltaY

        let totalDetents = Int(floor(-accumulatedDrag / ribHeight))
        if totalDetents != previousHapticDetent {
            let diff = totalDetents - previousHapticDetent
            previousHapticDetent = totalDetents

            // Dynamic intensity tapering based on drag speed or deceleration curve
            let intensity: Double
            if let custom = overrideIntensity {
                intensity = max(0.08, min(1.0, custom))
            } else {
                intensity = max(0.18, min(1.0, abs(Double(deltaY)) / 4.5))
            }

            // 1. Tactile Physical Vibration (scales with intensity)
            haptic.impactOccurred(intensity: CGFloat(intensity))

            // 2. Warm ASMR Micro-Tick (tapers in volume and resonance)
            ASMRSoundEngine.shared.playTick(intensity: intensity)

            shiftMinutes(by: diff * minutesPerRib)
        }
    }

    private func shiftMinutes(by deltaMinutes: Int) {
        let currentMins = calendar.component(.hour, from: time) * 60 + calendar.component(.minute, from: time)
        let newMins = ((currentMins + deltaMinutes) % 1440 + 1440) % 1440

        var components = calendar.dateComponents([.year, .month, .day], from: time)
        components.hour = newMins / 60
        components.minute = newMins % 60
        components.second = 0

        if let newDate = calendar.date(from: components) {
            time = newDate
        }
    }

    private func startInertialSpin(initialVelocity: CGFloat) {
        stopInertialSpin()

        var velocity = initialVelocity / 60.0 // Convert to per-frame velocity (~60 FPS)
        let peakVelocity = max(abs(velocity), 1.0)
        let friction: CGFloat = 0.955 // Natural mechanical wheel friction decay

        spinTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            velocity *= friction

            // Taper acoustic volume as velocity decays
            let speedRatio = abs(velocity) / peakVelocity
            let taperedIntensity = max(0.06, speedRatio * 0.88)

            applyDragDelta(velocity, overrideIntensity: Double(taperedIntensity))

            if abs(velocity) < 0.25 {
                timer.invalidate()
                spinTimer = nil
            }
        }
    }

    private func stopInertialSpin() {
        spinTimer?.invalidate()
        spinTimer = nil
    }
}
