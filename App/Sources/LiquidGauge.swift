import CoreMotion
import SwiftUI

/// Device roll, so the liquid surface stays level as the phone tilts.
/// Not observable on purpose: it's read inside the TimelineView frame closure,
/// which redraws anyway — observing would re-render the whole gauge per sample.
@MainActor
final class TiltMotion {
    static let shared = TiltMotion()
    private let manager = CMMotionManager()
    private var users = 0
    private(set) var tilt: Double = 0

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let gravity = motion?.gravity else { return }
            MainActor.assumeIsolated {
                let angle = atan2(gravity.x, -gravity.y)
                TiltMotion.shared.tilt = max(-0.5, min(0.5, angle))
            }
        }
    }

    func stop() {
        users = max(0, users - 1)
        guard users == 0 else { return }
        manager.stopDeviceMotionUpdates()
        tilt = 0
    }
}

/// The vessel with a wave — hero of the Today screen. Liquid level = goal progress.
struct LiquidGauge: View {
    var totalML: Int
    var goalML: Int
    var unit: VolumeUnit
    var size = CGSize(width: 210, height: 248)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    private var progress: Double { ProgressMath.fraction(total: totalML, goal: goalML) }
    private var goalReached: Bool { totalML >= goalML }
    private var radius: CGFloat { size.width * 0.29 }
    private var animating: Bool { isVisible && scenePhase == .active && !reduceMotion }

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animating)) { timeline in
                WaveShape(level: progress,
                          phase: animating ? timeline.date.timeIntervalSinceReferenceDate : 0,
                          tilt: animating ? TiltMotion.shared.tilt : 0,
                          amplitude: reduceMotion ? 0 : 5)
                    .fill(goalReached ? Theme.goalGradient : Theme.liquidGradient)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

            LinearGradient(colors: [.white.opacity(0.16), .clear],
                           startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .allowsHitTesting(false)

            VStack(spacing: 4) {
                Text(verbatim: "\(ProgressMath.percent(total: totalML, goal: goalML))%")
                    .font(.system(size: size.width * 0.26, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(totalML)))
                Group {
                    if goalReached {
                        Label("Goal reached", systemImage: "checkmark.seal.fill")
                    } else {
                        Text("\(VolumeFormat.number(totalML, unit: unit)) of \(VolumeFormat.string(goalML, unit: unit))")
                            .monospacedDigit()
                    }
                }
                .font(.footnote.weight(.semibold))
                .opacity(0.9)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
            }
            .foregroundStyle(Theme.textPrimary)
            .shadow(color: Theme.bg.opacity(0.45), radius: 8, y: 2)
        }
        .frame(width: size.width, height: size.height)
        .background(
            LinearGradient(colors: [Theme.glassRaised, Theme.glass], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(Theme.stroke, lineWidth: 1.5))
        .background {
            // Soft glow as a blurred shape, not a .shadow on the whole animated stack.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill((goalReached ? Theme.success : Theme.aqua).opacity(0.22))
                .blur(radius: 28)
                .offset(y: 16)
        }
        .animation(.spring(duration: 0.7, bounce: 0.3), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today's progress"))
        .accessibilityValue(Text("\(VolumeFormat.string(totalML, unit: unit)) of \(VolumeFormat.string(goalML, unit: unit)), \(ProgressMath.percent(total: totalML, goal: goalML)) percent"))
        .onAppear {
            isVisible = true
            TiltMotion.shared.start()
        }
        .onDisappear {
            isVisible = false
            TiltMotion.shared.stop()
        }
    }
}

/// Sine wave for the liquid surface, tilted against the device roll.
struct WaveShape: Shape {
    var level: Double
    var phase: Double
    var tilt: Double = 0
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
        let drift = CGFloat(phase.truncatingRemainder(dividingBy: 1000)) * 0.9

        path.move(to: CGPoint(x: 0, y: surfaceY - slope * midX))
        var x: CGFloat = 0
        while x <= rect.width {
            let wave = sin((x / wavelength + drift) * 2 * .pi) * amp
            path.addLine(to: CGPoint(x: x, y: surfaceY + wave + slope * (x - midX)))
            x += 3
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
