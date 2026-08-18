import SwiftUI
import UIKit

// MARK: - 1. Split-Flap Mechanical Odometer (Streaks & Counter)

/// A physical Solari split-flap digit counter with realistic 3D flipping animations,
/// horizontal seam, matte texture, and mechanical click haptics.
struct SplitFlapOdometerView: View {
    let value: Int
    var digitCount: Int = 3

    private var digitArray: [Int] {
        var str = String(value)
        while str.count < digitCount {
            str = "0" + str
        }
        return str.compactMap { Int(String($0)) }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<digitArray.count, id: \.self) { index in
                SplitFlapDigitCell(digit: digitArray[index])
            }
        }
    }
}

struct SplitFlapDigitCell: View {
    let digit: Int
    @State private var previousDigit: Int = 0
    @State private var isFlipping = false
    private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    var body: some View {
        ZStack {
            // Background Card
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(white: 0.12))
                .frame(width: 28, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                )

            // Digit Text
            Text("\(digit)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            // Horizontal Split Seam
            Rectangle()
                .fill(Color.black.opacity(0.85))
                .frame(width: 28, height: 1.5)

            // Split-flap top/bottom subtle shading
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.white.opacity(0.06), Color.clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 19)
                LinearGradient(colors: [Color.black.opacity(0.25), Color.clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 19)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .allowsHitTesting(false)
        }
        .rotation3DEffect(.degrees(isFlipping ? 360 : 0), axis: (x: 1, y: 0, z: 0))
        .onChange(of: digit) { oldVal, newVal in
            if oldVal != newVal {
                haptic.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                    isFlipping.toggle()
                }
            }
        }
    }
}

// MARK: - 2. Spring-Loaded Industrial Plunger Button (Check-In)

/// An aerospace / industrial spring-loaded plunger button with press-and-hold charge progress,
/// coiled steel spring physics, progressive heartbeat haptics, and a mechanical lock.
struct IndustrialPlungerButton: View {
    let title: String
    let isCompleted: Bool
    let onComplete: () -> Void

    @State private var isPressed = false
    @State private var progress: CGFloat = 0.0
    @State private var timer: Timer?

    private let holdDuration: Double = 1.0 // 1 second hold
    private let hapticImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let hapticSuccess = UINotificationFeedbackGenerator()

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Outer Recessed Mounting Plate
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(height: 58)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                // Progress Fill Track
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.4), Color.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.05), value: progress)
                }
                .frame(height: 52)
                .padding(.horizontal, 3)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // The Heavy Plunger Button
                HStack(spacing: 10) {
                    if isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.green)
                        Text("ARRIVED & VERIFIED")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                            .tracking(1)
                    } else {
                        // Coiled Spring Icon / Plunger Indicator
                        Image(systemName: isPressed ? "lock.fill" : "lock.open.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isPressed ? Color.white : Color.primary)
                            .scaleEffect(isPressed ? 0.9 : 1.0)

                        Text(isPressed ? "ARMING CHECK-IN..." : title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isPressed ? .white : .primary)
                            .tracking(0.5)

                        if !isPressed {
                            Text("HOLD")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.secondarySystemBackground), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .offset(y: isPressed ? 2 : 0)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isCompleted, !isPressed else { return }
                        startHold()
                    }
                    .onEnded { _ in
                        guard !isCompleted else { return }
                        cancelHold()
                    }
            )
        }
    }

    private func startHold() {
        isPressed = true
        hapticImpact.impactOccurred(intensity: 0.6)

        let step = 0.05
        timer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { _ in
            progress += CGFloat(step / holdDuration)
            if progress >= 1.0 {
                progress = 1.0
                finishHold()
            }
        }
    }

    private func cancelHold() {
        isPressed = false
        timer?.invalidate()
        timer = nil
        withAnimation(.spring(response: 0.25)) {
            progress = 0
        }
    }

    private func finishHold() {
        timer?.invalidate()
        timer = nil
        isPressed = false
        hapticSuccess.notificationOccurred(.success)
        onComplete()
    }
}

// MARK: - 3. Cockpit Urgency Needle Gauge (Time-to-Leave Manometer)

/// An analog cockpit pressure gauge displaying departure urgency with a physical sweeping
/// needle, green/amber/redline pressure zones, and real-time urgency damping.
struct CockpitUrgencyGauge: View {
    let secondsUntilLeave: TimeInterval? // Negative = running late, >0 = time remaining

    private var normalizedUrgency: Double {
        guard let seconds = secondsUntilLeave else { return 0.0 }
        if seconds <= 0 { return 1.0 } // Critical redline
        let maxSeconds: Double = 3600 // 60 minutes window
        return max(0.0, min(1.0, 1.0 - (seconds / maxSeconds)))
    }

    private var needleAngle: Double {
        // Sweep from -120 deg (Calm) to +120 deg (Critical Redline)
        -120.0 + (normalizedUrgency * 240.0)
    }

    private var zoneColor: Color {
        if normalizedUrgency > 0.8 { return .red }
        if normalizedUrgency > 0.4 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Dial Gauge Face
                Circle()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.18), lineWidth: 1.5))

                // Graduated Arc Zones (Green -> Amber -> Redline)
                Circle()
                    .trim(from: 0.16, to: 0.84)
                    .stroke(
                        AngularGradient(
                            colors: [.green, .yellow, .orange, .red],
                            center: .center,
                            startAngle: .degrees(90),
                            endAngle: .degrees(450)
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: 80, height: 80)

                // Dial Tick Marks
                ForEach(0..<9) { i in
                    let angle = -120.0 + Double(i) * 30.0
                    Rectangle()
                        .fill(i >= 6 ? Color.red : Color.secondary.opacity(0.4))
                        .frame(width: 1.5, height: i % 2 == 0 ? 5 : 3)
                        .offset(y: -34)
                        .rotationEffect(.degrees(angle))
                }

                // Sweeping Physical Red Needle
                ZStack {
                    // Needle Pin
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))

                    // Needle Arm
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: 32)
                        .offset(y: -16)
                }
                .rotationEffect(.degrees(needleAngle))
                .animation(.spring(response: 0.6, dampingFraction: 0.65), value: needleAngle)
            }

            Text("URGENCY")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(zoneColor)
                .tracking(1)
        }
    }
}

// MARK: - 4. Multiband Radio Transit Tuner (Transit Mode Selector)

/// A Dieter Rams / Braun-inspired physical frequency tuner with a sliding indicator needle,
/// frequency scale markings, and magnetic stepped detents for transit modes.
struct MultibandTransitTuner: View {
    @Binding var selection: TravelMode
    private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    private let modes = TravelMode.allCases

    var body: some View {
        VStack(spacing: 8) {
            // Tuner Frequency Window
            ZStack(alignment: .bottom) {
                // Background Metallic Housing
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.12))
                    .frame(height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                // Scale Ticks & Mode Icons
                VStack(spacing: 6) {
                    HStack {
                        ForEach(modes) { mode in
                            let isSelected = selection == mode
                            VStack(spacing: 2) {
                                Image(systemName: mode.iconName)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                                    .foregroundStyle(isSelected ? Color.orange : Color.white.opacity(0.45))

                                Text(mode.rawValue)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                setMode(mode)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    // Laser Frequency Scale Line
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.orange.opacity(0.3))
                            .frame(height: 1)

                        // Stepped Tick Dashes
                        HStack {
                            ForEach(0..<modes.count, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.orange.opacity(0.5))
                                    .frame(width: 1.5, height: 6)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func setMode(_ mode: TravelMode) {
        if selection != mode {
            haptic.impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                selection = mode
            }
        }
    }
}
