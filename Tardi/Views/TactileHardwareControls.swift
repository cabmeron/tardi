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
    var geofenceRadiusMeters: Double = 100
    let onAddTask: (() -> Void)?

    @State private var emberFlicker = false
    @State private var radarSweep = false
    @State private var radarPulse = false

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
            // 0. Teenage Engineering Anodized Slate Aluminum Chassis
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.18, blue: 0.20),
                            Color(red: 0.09, green: 0.10, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: (ringRadius * 2) + 26, height: (ringRadius * 2) + 26)
                .overlay(
                    // Outer Fine Machined Beveled Rim
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.08),
                                    Color.black.opacity(0.4),
                                    Color.black.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    // Minimalist Triangular Index Markings (▲, ▼, ◀, ▶)
                    ZStack {
                        Text("▲")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .offset(y: -(ringRadius + 7))
                        Text("▼")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .offset(y: (ringRadius + 7))
                        Text("◀")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .offset(x: -(ringRadius + 7))
                        Text("▶")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .offset(x: (ringRadius + 7))
                    }
                )
                .overlay(
                    // 4 Precision Torx Corner Bolts
                    ZStack {
                        ForEach([45.0, 135.0, 225.0, 315.0], id: \.self) { angle in
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(white: 0.38), Color(white: 0.16)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 5.5, height: 5.5)
                                .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 0.7))
                                .overlay(Rectangle().fill(Color.black.opacity(0.75)).frame(width: 3.5, height: 0.8))
                                .offset(
                                    x: CGFloat(cos(angle * .pi / 180.0)) * (ringRadius + 8),
                                    y: CGFloat(sin(angle * .pi / 180.0)) * (ringRadius + 8)
                                )
                        }
                    }
                )
                .shadow(color: Color.black.opacity(0.35), radius: 16, y: 8)

            // 1. Etched Hairline Track (Calibrated Groove Channel)
            Circle()
                .stroke(
                    Color.white.opacity(0.10),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 4])
                )
                .frame(width: ringRadius * 2, height: ringRadius * 2)

            // 2. Rotary 48-Step LED Sequencer Ring (Teenage Engineering E-Fuse)
            if taskTitle != nil, !isCompleted {
                let totalSteps = 48
                let activeSteps = Int(progress * Double(totalSteps))

                // Circular Dark LCD Well Background
                Circle()
                    .fill(Color(red: 0.07, green: 0.08, blue: 0.09))
                    .frame(width: (ringRadius * 1.58), height: (ringRadius * 1.58))
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )

                // 48 Discrete Radial LED Light Pipes (International Safety Orange)
                ForEach(0..<totalSteps, id: \.self) { slot in
                    let angleDeg = Double(slot) * (360.0 / Double(totalSteps))
                    let isActive = slot < activeSteps
                    let isLead = (slot == max(0, activeSteps - 1)) && activeSteps > 0

                    RoundedRectangle(cornerRadius: 1.2)
                        .fill(
                            isActive
                                ? (isLead ? Color.white : Color(red: 1.0, green: 0.42, blue: 0.06))
                                : Color(red: 1.0, green: 0.35, blue: 0.0).opacity(0.12)
                        )
                        .frame(width: 3.2, height: 9.5)
                        .shadow(
                            color: isActive ? Color(red: 1.0, green: 0.40, blue: 0.05).opacity(isLead ? 0.95 : 0.75) : .clear,
                            radius: isLead ? 4 : 2
                        )
                        .offset(y: -ringRadius)
                        .rotationEffect(.degrees(angleDeg))
                }
            } else if isCompleted {
                // Completed Ring: Solid Green Circuit Disengaged Seal
                Circle()
                    .stroke(Color.green, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .frame(width: ringRadius * 2, height: ringRadius * 2)
                    .shadow(color: Color.green.opacity(0.5), radius: 6)
                    .transition(.opacity)
            } else {
                // MARK: - Tactical Geodesic Radar Scope Background
                ZStack {
                    // Deep Dark CRT Screen Lens
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.05, green: 0.09, blue: 0.07), // subtle phosphor bloom
                                    Color(red: 0.02, green: 0.035, blue: 0.03), // deep carbon
                                    Color(red: 0.01, green: 0.015, blue: 0.012) // dark vignette
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: ringRadius
                            )
                        )
                        .frame(width: ringRadius * 2, height: ringRadius * 2)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.28), lineWidth: 1)
                        )

                    // Concentric Sonar Range Rings (Bright Glowing Tactical Green)
                    Circle()
                        .stroke(Color.green.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(width: ringRadius * 1.48, height: ringRadius * 1.48)

                    Circle()
                        .stroke(Color.green.opacity(0.28), style: StrokeStyle(lineWidth: 1))
                        .frame(width: ringRadius * 0.95, height: ringRadius * 0.95)

                    // Expanding Pulsing Sonar Wave
                    Circle()
                        .stroke(Color.green.opacity(radarPulse ? 0.48 : 0.04), lineWidth: 1.2)
                        .frame(width: ringRadius * (radarPulse ? 1.55 : 0.65), height: ringRadius * (radarPulse ? 1.55 : 0.65))
                        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: radarPulse)

                    // Crosshair Reticle Hairline Ticks (N, S, E, W) in Tactical Green
                    Rectangle()
                        .fill(Color.green.opacity(0.38))
                        .frame(width: 1, height: 24)
                        .offset(y: -54)
                    Rectangle()
                        .fill(Color.green.opacity(0.38))
                        .frame(width: 1, height: 24)
                        .offset(y: 54)
                    Rectangle()
                        .fill(Color.green.opacity(0.38))
                        .frame(width: 24, height: 1)
                        .offset(x: -54)
                    Rectangle()
                        .fill(Color.green.opacity(0.38))
                        .frame(width: 24, height: 1)
                        .offset(x: 54)

                    // Rotating Radar Sweep Fan Beam
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.green.opacity(0.28),
                                    Color.green.opacity(0.06),
                                    Color.clear,
                                    Color.clear
                                ]),
                                center: .center
                            )
                        )
                        .frame(width: ringRadius * 1.55, height: ringRadius * 1.55)
                        .rotationEffect(.degrees(radarSweep ? 360 : 0))
                        .animation(.linear(duration: 4.5).repeatForever(autoreverses: false), value: radarSweep)

                    // Cardinal Azimuth Compass Indicators (High-Contrast White)
                    VStack {
                        Text("N")
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Spacer()
                        Text("S")
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .frame(height: ringRadius * 1.7)

                    HStack {
                        Text("W")
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Spacer()
                        Text("E")
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .frame(width: ringRadius * 1.7)
                }
            }

            // 4. Center Telemetry: EXACTLY 3 Core Items Surrounded by Burning Ring
            VStack(spacing: 7) {
                if isCompleted {
                    VStack(spacing: 5) {
                        Image(systemName: "bolt.badge.checkmark.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.green)
                            .shadow(color: Color.green.opacity(0.4), radius: 6)

                        Text("CIRCUIT DISENGAGED")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(1.2)

                        Text("FUSE PRESERVED • STAKE SECURED")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .tracking(1.4)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.82).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                } else if taskTitle != nil {
                    // MARK: - Teenage Engineering Inverted LCD Display
                    VStack(spacing: 4) {
                        // Top Mode Placard
                        Text(hours > 0 ? "HOURS REMAINING" : "MINUTES REMAINING")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .tracking(1.4)

                        // Main Inverted Digital LCD Readout
                        if hours > 0 {
                            Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        } else {
                            HStack(spacing: 7) {
                                Text(String(format: "%02d", minutes))
                                Text(String(format: "%02d", seconds))
                            }
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        }

                        // Subtitle
                        Text("E-FUSE DECAY ACTIVE")
                            .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .tracking(1.2)

                        // Circuit Load / Stake Telemetry
                        if pledgeAmount > 0 {
                            HStack(spacing: 4) {
                                Text("LOAD:")
                                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                Text("$\(Int(pledgeAmount)).00")
                                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.08))
                                    .tracking(0.5)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(red: 1.0, green: 0.45, blue: 0.08).opacity(0.14), in: Capsule())
                            .overlay(Capsule().stroke(Color(red: 1.0, green: 0.45, blue: 0.08).opacity(0.35), lineWidth: 0.6))
                        } else {
                            Text(taskTitle?.uppercased() ?? "HABIT TASK")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.75))
                                .lineLimit(1)
                        }

                        // Range Proximity Telemetry
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isInsideLocation ? Color.green : Color.orange)
                                .frame(width: 4, height: 4)

                            Text(isInsideLocation ? "IN GEOFENCE RANGE" : (distanceText != nil ? "\(distanceText!) TO DISENGAGE" : "MONITORING"))
                                .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(isInsideLocation ? Color.green : Color.white.opacity(0.85))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .overlay(Capsule().stroke(isInsideLocation ? Color.green.opacity(0.35) : Color.white.opacity(0.18), lineWidth: 0.5))
                    }
                } else {
                    // MARK: - Tactical Geodesic Radar Scope Center Telemetry
                    VStack(spacing: 3) {
                        // Central Glowing GPS Beacon Origin Dot
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(radarPulse ? 0.6 : 0.2))
                                .frame(width: radarPulse ? 18 : 8, height: radarPulse ? 18 : 8)
                                .blur(radius: 3)

                            Circle()
                                .fill(isInsideLocation ? Color.green : Color.green.opacity(0.95))
                                .frame(width: 6, height: 6)
                                .shadow(color: Color.green, radius: 4)
                        }
                        .padding(.bottom, 2)

                        // Real-Time Distance Readout
                        Text(isInsideLocation ? "INSIDE" : (distanceText ?? "0.0 mi"))
                            .font(.system(size: isInsideLocation ? 21 : 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        // Telemetry Badges
                        Text("GEOFENCE ARMED")
                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.green.opacity(0.95))
                            .tracking(1.4)

                        Text("\(Int(geofenceRadiusMeters))M RADIUS")
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .tracking(1)

                        // Status Pill
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isInsideLocation ? Color.green : Color.orange)
                                .frame(width: 4, height: 4)

                            Text(isInsideLocation ? "IN BOUNDS" : "MONITORING")
                                .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(isInsideLocation ? Color.green : Color.white.opacity(0.85))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 220)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true)) {
                emberFlicker = true
            }
            withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
                radarSweep = true
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                radarPulse = true
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
    var pressedTitle: String = "DISENGAGING CIRCUIT BREAKER..."
    let isCompleted: Bool
    var isGeofenceVerified: Bool = true
    var distanceAwayMeters: Double? = nil
    var requiredRadiusMeters: Double = 100
    var onOutsideLocationTapped: (() -> Void)? = nil
    var onHoldProgressChanged: ((_ isHolding: Bool, _ progress: CGFloat) -> Void)? = nil
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

                // Progress Fill Track (Safety Orange Breaker Charge)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.45, blue: 0.08).opacity(0.4),
                                    Color(red: 1.0, green: 0.45, blue: 0.08)
                                ],
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
                        Image(systemName: "bolt.badge.checkmark.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.green)
                        Text("CIRCUIT DISENGAGED • FUSE PRESERVED")
                            .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                            .tracking(0.8)
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
                        // E-Fuse Circuit Disengage Indicator
                        Image(systemName: isPressed ? "bolt.slash.fill" : "bolt.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isPressed ? Color.white : Color(red: 1.0, green: 0.45, blue: 0.08))
                            .scaleEffect(isPressed ? 0.9 : 1.0)

                        Text(isPressed ? pressedTitle : title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(isPressed ? .white : .primary)
                            .tracking(0.5)

                        if !isPressed {
                            Text("DISENGAGE")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(red: 1.0, green: 0.45, blue: 0.08).opacity(0.18), in: Capsule())
                                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.08))
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
        onHoldProgressChanged?(true, progress)

        let step = 0.05
        timer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { _ in
            progress += CGFloat(step / holdDuration)
            onHoldProgressChanged?(true, progress)
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
        onHoldProgressChanged?(false, 0.0)
        withAnimation(.spring(response: 0.25)) {
            progress = 0
        }
    }

    private func finishHold() {
        timer?.invalidate()
        timer = nil
        isPressed = false
        onHoldProgressChanged?(false, 1.0)
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

// MARK: - 5. Whole-Screen Spatial Radar Particle Scanning Overlay

/// A full-screen tactical scanning HUD overlay that activates when holding down the location verification button.
/// Renders ambient radar particles, moving laser sweep wavefronts, expanding sonar ripples,
/// and an explosive celebratory particle shockwave upon successful verification.
struct SpatialParticleOverlay: View {
    let isActive: Bool
    let progress: CGFloat // 0.0 to 1.0 charge
    let isBursting: Bool  // True on completion burst

    @State private var particles: [ScanParticle] = (0..<85).map { _ in ScanParticle.random() }
    @State private var burstParticles: [BurstParticle] = []
    @State private var laserSweepY: CGFloat = 0.0
    @State private var sonarRipple: CGFloat = 0.0

    struct ScanParticle: Identifiable {
        let id = UUID()
        var x: CGFloat // 0.0 to 1.0 (relative width)
        var y: CGFloat // 0.0 to 1.0 (relative height)
        var vx: CGFloat
        var vy: CGFloat
        var radius: CGFloat
        var baseAlpha: Double
        var colorIdx: Int

        static func random() -> ScanParticle {
            ScanParticle(
                x: CGFloat.random(in: 0.02...0.98),
                y: CGFloat.random(in: 0.02...0.98),
                vx: CGFloat.random(in: -0.0015...0.0015),
                vy: CGFloat.random(in: -0.0025...0.0025),
                radius: CGFloat.random(in: 1.5...4.5),
                baseAlpha: Double.random(in: 0.35...0.85),
                colorIdx: Int.random(in: 0...2)
            )
        }
    }

    struct BurstParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var radius: CGFloat
        var alpha: Double
        var color: Color
    }

    var body: some View {
        ZStack {
            if isActive || isBursting {
                // 1. Dark Atmospheric HUD Tint
                Color.black
                    .opacity(isBursting ? 0.45 : (0.28 + Double(progress) * 0.24))
                    .ignoresSafeArea()

                // 2. Full-Screen Canvas Particle Renderer
                GeometryReader { geo in
                    let h = geo.size.height

                    ZStack {
                        // Ambient Tactical Radar Laser Sweep Line
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.green.opacity(0.3),
                                        Color.green.opacity(0.85),
                                        Color.green.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 2)
                            .shadow(color: Color.green.opacity(0.9), radius: 6)
                            .offset(y: (h * laserSweepY) - (h / 2))

                        // High-Performance Metal Canvas Particle Emitter
                        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                            Canvas { ctx, size in
                                let speedFactor = 1.0 + Double(progress) * 3.5
                                let time = timeline.date.timeIntervalSinceReferenceDate

                                for p in particles {
                                    let driftX = (p.x + p.vx * CGFloat(speedFactor) * CGFloat(time.truncatingRemainder(dividingBy: 10)))
                                    let driftY = (p.y + p.vy * CGFloat(speedFactor) * CGFloat(time.truncatingRemainder(dividingBy: 10)))

                                    let modX = driftX.truncatingRemainder(dividingBy: 1.0)
                                    let modY = driftY.truncatingRemainder(dividingBy: 1.0)

                                    let actualX = (modX < 0 ? modX + 1.0 : modX) * size.width
                                    let actualY = (modY < 0 ? modY + 1.0 : modY) * size.height

                                    let color: Color = {
                                        switch p.colorIdx {
                                        case 0: return Color(red: 1.0, green: 0.45, blue: 0.08)
                                        case 1: return Color(red: 1.0, green: 0.75, blue: 0.2)
                                        default: return Color.white
                                        }
                                    }()

                                    let pRect = CGRect(x: actualX - p.radius, y: actualY - p.radius, width: p.radius * 2, height: p.radius * 2)
                                    ctx.opacity = p.baseAlpha * (0.6 + Double(progress) * 0.4)
                                    ctx.fill(Circle().path(in: pRect), with: .color(color))
                                }

                                // Render Burst Explosion Particles
                                for bp in burstParticles {
                                    let bpRect = CGRect(x: bp.x - bp.radius, y: bp.y - bp.radius, width: bp.radius * 2, height: bp.radius * 2)
                                    ctx.opacity = bp.alpha
                                    ctx.fill(Circle().path(in: bpRect), with: .color(bp.color))
                                }
                            }
                        }

                        // Concentric Sonar Pulse Wavefronts
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(Color(red: 1.0, green: 0.45, blue: 0.08).opacity(0.35 - Double(i) * 0.08), lineWidth: 1.5)
                                .frame(width: CGFloat(i + 1) * 160 * (0.6 + progress * 0.9))
                                .scaleEffect(sonarRipple > 0 ? (1.0 + sonarRipple * 0.8) : 1.0)
                        }

                        // Scanning HUD Telemetry Header
                        VStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(isBursting ? Color.green : Color(red: 1.0, green: 0.45, blue: 0.08))
                                    .frame(width: 6, height: 6)
                                    .shadow(color: isBursting ? Color.green : Color(red: 1.0, green: 0.45, blue: 0.08), radius: 4)

                                Text(isBursting ? "CIRCUIT DISENGAGED // FUSE PRESERVED" : "DISENGAGING CIRCUIT BREAKER // \(Int(progress * 100))%")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(isBursting ? Color.green : Color(red: 1.0, green: 0.45, blue: 0.08))
                                    .tracking(1.5)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7), in: Capsule())
                            .overlay(Capsule().stroke((isBursting ? Color.green : Color(red: 1.0, green: 0.45, blue: 0.08)).opacity(0.4), lineWidth: 1))
                            .padding(.top, 50)

                            Spacer()
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isActive)
        .animation(.easeInOut(duration: 0.35), value: isBursting)
        .onAppear {
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: true)) {
                laserSweepY = 1.0
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                sonarRipple = 0.5
            }
        }
        .onChange(of: isBursting) { _, bursting in
            if bursting {
                triggerBurst()
            }
        }
    }

    private func triggerBurst() {
        let center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.6)
        var newBurst: [BurstParticle] = []
        for _ in 0..<90 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 5...18)
            newBurst.append(
                BurstParticle(
                    x: center.x,
                    y: center.y,
                    vx: CGFloat(cos(angle)) * speed,
                    vy: CGFloat(sin(angle)) * speed,
                    radius: CGFloat.random(in: 2...5.5),
                    alpha: 1.0,
                    color: [Color.green, Color(red: 1.0, green: 0.45, blue: 0.08), Color.white, Color(red: 1.0, green: 0.8, blue: 0.3)].randomElement()!
                )
            )
        }
        burstParticles = newBurst

        let steps = 24
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            currentStep += 1
            for idx in burstParticles.indices {
                burstParticles[idx].x += burstParticles[idx].vx
                burstParticles[idx].y += burstParticles[idx].vy
                burstParticles[idx].vx *= 0.94 // gentle friction
                burstParticles[idx].vy *= 0.94
                burstParticles[idx].alpha = max(0, burstParticles[idx].alpha - 0.042)
            }
            if currentStep >= steps {
                timer.invalidate()
                burstParticles.removeAll()
            }
        }
    }
}

