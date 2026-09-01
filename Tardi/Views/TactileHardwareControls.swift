import SwiftUI
import UIKit

// MARK: - 0. Animated Minimalist Burning Fuse Countdown (Hero Timer)

/// An architectural burning fuse countdown hero with a tactile braided cord track,
/// minimal monochromatic palette, and an animated flickering spark / white-hot ember head
/// that burns down the ring in real time.
struct BurningFuseCountdownView: View {
    let progress: Double // 0.0 to 1.0 (1.0 = full time remaining, 0.0 = expired / deadline)
    let timeRemaining: TimeInterval
    let pledgeAmount: Double
    let isPledged: Bool
    let taskTitle: String?
    let isCompleted: Bool
    let totalStreak: Int
    let transitETA: String?
    let transitModeIcon: String?
    let distanceText: String?
    let isInsideLocation: Bool
    let onAddTask: (() -> Void)?

    @State private var emberFlicker = false

    private var hours: Int { Int(max(0, timeRemaining)) / 3600 }
    private var minutes: Int { (Int(max(0, timeRemaining)) % 3600) / 60 }
    private var seconds: Int { Int(max(0, timeRemaining)) % 60 }

    private let ringRadius: CGFloat = 96
    private let strokeWidth: CGFloat = 5

    private var emberAngleDegrees: Double {
        -90.0 + (min(max(progress, 0.02), 0.98) * 360.0)
    }

    private var emberPosition: CGPoint {
        let radians = emberAngleDegrees * .pi / 180.0
        return CGPoint(
            x: CGFloat(Darwin.cos(radians)) * ringRadius,
            y: CGFloat(Darwin.sin(radians)) * ringRadius
        )
    }

    var body: some View {
        ZStack {
            // 0. Clear Acrylic Glass Lens Disc (Frosted Material + Specular Sheen)
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: (ringRadius * 2) + 24, height: (ringRadius * 2) + 24)
                .overlay(
                    // Outer Glass Beveled Rim
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.65),
                                    Color.white.opacity(0.2),
                                    Color.primary.opacity(0.1),
                                    Color.black.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    // Diagonal Specular Reflection Glint Arc
                    Circle()
                        .trim(from: 0.05, to: 0.4)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.45), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-70))
                        .padding(2)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 14, y: 6)

            // 1. Etched Glass Track (Groove Channel in Deep Black Tint)
            Circle()
                .stroke(
                    Color.black.opacity(0.18),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, dash: [3, 4])
                )
                .frame(width: ringRadius * 2, height: ringRadius * 2)

            // 2. Solid Black Burning Fuse Cord Ring
            if taskTitle != nil, !isCompleted {
                Circle()
                    .trim(from: 0, to: CGFloat(max(progress, 0.03)))
                    .stroke(
                        Color.black,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringRadius * 2, height: ringRadius * 2)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // 3. The Animated Burning Spark / Ember Head (White-Hot with Fiery Glow)
                ZStack {
                    // Outer Pulsing Heat Halo
                    Circle()
                        .fill(Color.orange.opacity(emberFlicker ? 0.45 : 0.2))
                        .frame(width: emberFlicker ? 24 : 16, height: emberFlicker ? 24 : 16)
                        .blur(radius: 3.5)

                    // Burning Amber Corona
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8.5, height: 8.5)
                        .shadow(color: Color.orange.opacity(0.95), radius: emberFlicker ? 6 : 3)

                    // White-Hot Ember Core
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)

                    // Radiating Spark Flecks
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.orange.opacity(emberFlicker ? 0.85 : 0.25))
                            .frame(width: 1.5, height: 1.5)
                            .offset(
                                x: CGFloat(Darwin.cos(Double(i) * 2.1 + (emberFlicker ? 1.0 : 0.0))) * 7,
                                y: CGFloat(Darwin.sin(Double(i) * 2.1 + (emberFlicker ? 1.0 : 0.0))) * 7
                            )
                    }
                }
                .offset(x: emberPosition.x, y: emberPosition.y)
                .animation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true), value: emberFlicker)
            } else if isCompleted {
                // Completed Ring: Solid Black Seal
                Circle()
                    .stroke(Color.black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .frame(width: ringRadius * 2, height: ringRadius * 2)
            }

            // 4. Center Telemetry: EXACTLY 3 Core Items Surrounded by Burning Ring
            VStack(spacing: 7) {
                if isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.primary)

                    Text("CHECKED IN")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .tracking(1)

                    Text("STAKE SECURED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                } else if taskTitle != nil {
                    // ITEM 1: Amount of Money at Risk
                    VStack(spacing: 0) {
                        if pledgeAmount > 0 {
                            Text("$\(Int(pledgeAmount))")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)

                            Text("AT RISK")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.red.opacity(0.9))
                                .tracking(1.5)
                        } else {
                            Text("$0")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)

                            Text("AT RISK")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .tracking(1.2)
                        }
                    }

                    Divider()
                        .frame(width: 36)
                        .opacity(0.3)

                    // ITEM 2: Current Distance Away in Miles
                    VStack(spacing: 1) {
                        Text(distanceText ?? "0.0 mi")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("DISTANCE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                    }

                    // ITEM 3: Time Away & Mode of Transit
                    HStack(spacing: 4) {
                        Image(systemName: transitModeIcon ?? "figure.walk")
                            .font(.system(size: 10, weight: .bold))

                        Text(transitETA != nil ? "\(transitETA!) away" : "Nearby")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 220)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true)) {
                emberFlicker = true
            }
        }
    }

    private func timeDigitCell(value: Int, unit: String) -> some View {
        VStack(spacing: 0) {
            Text(String(format: "%02d", value))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(unit)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

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
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(width: 28, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.8)
                )

            // Digit Text
            Text("\(digit)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)

            // Horizontal Split Seam
            Rectangle()
                .fill(Color(.separator).opacity(0.6))
                .frame(width: 28, height: 1.5)

            // Split-flap top/bottom subtle shading
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.primary.opacity(0.04), Color.clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 19)
                LinearGradient(colors: [Color.primary.opacity(0.08), Color.clear], startPoint: .bottom, endPoint: .top)
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
    var isGeofenceVerified: Bool = true
    var distanceAwayMeters: Double? = nil
    var requiredRadiusMeters: Double = 100
    var onOutsideLocationTapped: (() -> Void)? = nil
    let onComplete: () -> Void

    @State private var isPressed = false
    @State private var progress: CGFloat = 0.0
    @State private var timer: Timer?

    private let holdDuration: Double = 1.0 // 1 second hold
    private let hapticImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let hapticWarning = UINotificationFeedbackGenerator()
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
                HStack(spacing: 8) {
                    if isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.green)
                        Text("ARRIVED & VERIFIED")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                            .tracking(1)
                    } else if !isGeofenceVerified {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.orange)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("OUTSIDE LOCATION")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            if let dist = distanceAwayMeters {
                                Text("\(Int(dist))m away (Must be within \(Int(requiredRadiusMeters))m)")
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("GPS location confirming...")
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text("VERIFY")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.orange)
                    } else {
                        // Coiled Spring Icon / Plunger Indicator
                        Image(systemName: isPressed ? "lock.fill" : "location.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isPressed ? Color.white : Color.green)
                            .scaleEffect(isPressed ? 0.9 : 1.0)

                        Text(isPressed ? "VERIFYING GPS ARRIVAL..." : title)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
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
                .padding(.horizontal, 14)
                .offset(y: isPressed ? 2 : 0)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isCompleted, !isPressed else { return }
                        if !isGeofenceVerified {
                            hapticWarning.notificationOccurred(.warning)
                            onOutsideLocationTapped?()
                            return
                        }
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
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))

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
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
                    )

                // Scale Ticks & Mode Icons
                VStack(spacing: 6) {
                    HStack {
                        ForEach(modes) { mode in
                            let isSelected = selection == mode
                            VStack(spacing: 2) {
                                Image(systemName: mode.iconName)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                                Text(mode.rawValue)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
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
                            .fill(Color.primary.opacity(0.15))
                            .frame(height: 1)

                        // Stepped Tick Dashes
                        HStack {
                            ForEach(0..<modes.count, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.primary.opacity(0.35))
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

// MARK: - 5. Financial Pledge Stake Selector (Money at Risk)

/// A tactical pledge stake selector allowing users to commit financial stakes
/// ($0, $5, $10, $25, $50, $100) with glowing armed warning state and mechanical detent haptics.
struct PledgeStakeSelector: View {
    @Binding var pledgeAmount: Double
    private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    private let presetAmounts: [Double] = [0, 5, 10, 25, 50, 100]

    var body: some View {
        VStack(spacing: 12) {
            // Preset Buttons Row
            HStack(spacing: 8) {
                ForEach(presetAmounts, id: \.self) { amount in
                    let isSelected = pledgeAmount == amount
                    Button {
                        if pledgeAmount != amount {
                            haptic.impactOccurred()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                pledgeAmount = amount
                            }
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(amount == 0 ? "FREE" : "$\(Int(amount))")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? (amount > 0 ? Color.red : Color.primary) : Color.secondary)

                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? (amount > 0 ? Color.red.opacity(0.12) : Color(.tertiarySystemGroupedBackground)) : Color(.tertiarySystemGroupedBackground).opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    isSelected ? (amount > 0 ? Color.red.opacity(0.6) : Color.primary.opacity(0.3)) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Tactical Armed Warning Banner
            if pledgeAmount > 0 {
                HStack(spacing: 10) {
                    // Pulsing Red Warning LED
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.red.opacity(0.8), radius: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("STAKE ARMED: $\(Int(pledgeAmount)).00 AT RISK")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red)
                            .tracking(0.5)

                        Text("Card charged automatically if not at location by deadline.")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.red.opacity(0.25), lineWidth: 1))
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Casual Mode — No financial risk pledged for this task.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: pledgeAmount)
    }
}

