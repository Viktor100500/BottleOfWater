import SwiftUI
import CoreMotion

/// Publishes the device roll angle so the liquid surface can stay level
/// in the real world while the phone tilts.
final class TiltMotion: ObservableObject {
    static let shared = TiltMotion()
    private let manager = CMMotionManager()
    @Published private(set) var tilt: Double = 0   // radians, clamped

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let g = motion?.gravity else { return }
            // Roll of the device relative to upright portrait.
            let angle = atan2(g.x, -g.y)
            self?.tilt = max(-0.5, min(0.5, angle))
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

/// The "vessel with a wave" — hero of the home screen. Liquid level = goal progress.
struct LiquidGauge: View {
    var totalML: Int
    var goalML: Int
    var useOunces: Bool = false

    @ObservedObject private var motion = TiltMotion.shared

    private var progress: Double { min(1, Double(totalML) / Double(max(1, goalML))) }
    private var goalReached: Bool { totalML >= goalML }

    var body: some View {
        ZStack {
            // Liquid with a drifting wave; surface stays level as the phone tilts.
            // .animation without minimumInterval renders at display refresh rate
            // (60 fps, 120 on ProMotion).
            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                WaveShape(level: progress, phase: phase, tilt: motion.tilt)
                    .fill(goalReached ? Theme.goalGradient : Theme.liquidGradient)
            }
            .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))

            // Top gloss
            LinearGradient(colors: [.white.opacity(0.16), .clear],
                           startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
                .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))
                .allowsHitTesting(false)

            // Readings
            VStack(spacing: 4) {
                Text(verbatim: "\(ProgressMath.percent(total: totalML, goal: goalML))%")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .shadow(color: Theme.bg.opacity(0.5), radius: 10, y: 2)
                    .contentTransition(.numericText())
                if goalReached {
                    VStack(spacing: 1) {
                        Text("Goal reached 🎉")
                        Text(verbatim: VolumeFormatter.string(ml: totalML, ounces: useOunces))
                            .monospacedDigit()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    .multilineTextAlignment(.center)
                } else {
                    Text("\(VolumeFormatter.string(ml: totalML, ounces: useOunces)) of \(VolumeFormatter.string(ml: goalML, ounces: useOunces))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))
                }
            }
        }
        .frame(width: 200, height: 235)
        .background(
            LinearGradient(colors: [Theme.glassRaised, Theme.glass],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 60, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 60, style: .continuous)
            .strokeBorder(Theme.stroke, lineWidth: 1.5))
        .shadow(color: (goalReached ? Theme.success : Theme.aqua).opacity(0.30),
                radius: 30, y: 18)
        .animation(.spring(duration: 0.7, bounce: 0.3), value: progress)
        .accessibilityLabel(Text(String(localized: "Progress: \(totalML) of \(goalML) millilitres")))
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }
}

/// Sine wave for the liquid surface, tilted opposite to the device roll
/// so the water stays level in the real world.
struct WaveShape: Shape {
    var level: Double        // 0...1 — fill fraction
    var phase: Double        // time, drives the wave drift
    var tilt: Double = 0     // device roll, radians
    var amplitude: CGFloat = 5

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard level > 0.001 else { return path }
        let surfaceY = rect.height * (1 - CGFloat(level))
        let wavelength = rect.width / 1.4
        let amp = level >= 0.999 ? 0 : amplitude
        let slope = CGFloat(-tan(tilt))
        let midX = rect.width / 2

        path.move(to: CGPoint(x: 0, y: surfaceY + slope * (0 - midX)))
        var x: CGFloat = 0
        while x <= rect.width {
            let relative = x / wavelength
            let wave = sin((relative + CGFloat(phase.truncatingRemainder(dividingBy: 1000)) * 0.9) * 2 * .pi) * amp
            let y = surfaceY + wave + slope * (x - midX)
            path.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
