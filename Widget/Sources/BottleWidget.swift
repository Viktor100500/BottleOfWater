import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct BottleEntry: TimelineEntry {
    var date: Date
    var totalML: Int
    var goalML: Int
    var button1ML: Int
    var button2ML: Int
    var loggingEnabled: Bool

    var progress: Double { min(1, Double(totalML) / Double(max(1, goalML))) }
    var percent: Int { ProgressMath.percent(total: totalML, goal: goalML) }

    static var demo: BottleEntry {
        BottleEntry(
            date: .now,
            totalML: 800,
            goalML: 2000,
            button1ML: 200,
            button2ML: 330,
            loggingEnabled: true
        )
    }

    static func current() -> BottleEntry {
        let data = WidgetDataReader.today()
        return BottleEntry(
            date: .now,
            totalML: data.totalML,
            goalML: data.goalML,
            button1ML: SettingsStore.widgetButton1ML,
            button2ML: SettingsStore.widgetButton2ML,
            loggingEnabled: SettingsStore.widgetLoggingEnabled
        )
    }
}

struct BottleProvider: TimelineProvider {
    func placeholder(in context: Context) -> BottleEntry { .demo }

    func getSnapshot(in context: Context, completion: @escaping (BottleEntry) -> Void) {
        completion(context.isPreview ? .demo : .current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BottleEntry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
        completion(Timeline(entries: [.current()], policy: .after(midnight)))
    }
}

// MARK: - Widget

struct BottleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BottleWidget", provider: BottleProvider()) { entry in
            BottleWidgetView(entry: entry)
        }
        .configurationDisplayName("Water progress")
        .description("Hydration level and quick logging.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

@main
struct BottleWidgetBundle: WidgetBundle {
    var body: some Widget { BottleWidget() }
}

// MARK: - Root view

struct BottleWidgetView: View {
    var entry: BottleEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    /// accented = tinted home screen, vibrant = lock screen.
    private var accented: Bool { renderingMode != .fullColor }

    var body: some View {
        switch family {
        case .systemMedium: medium
        case .systemSmall: small
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    // MARK: Home Screen

    private var brand: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(accented ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.Widget.aqua))
                .frame(width: 6, height: 6)
            Text(verbatim: "Bottle of Water")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(accented ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.Widget.brandGradient))
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var amount: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(VolumeFormatter.formatted(entry.totalML))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accented ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.Widget.white))
                .widgetAccentable()
                .contentTransition(.numericText(value: Double(entry.totalML)))
                .invalidatableContent()
            Text("of \(VolumeFormatter.formatted(entry.goalML)) ml")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accented ? AnyShapeStyle(.white.opacity(0.6)) : AnyShapeStyle(Theme.Widget.dim))
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            vessel(width: 92, height: 118, fontSize: 22)
            VStack(alignment: .leading, spacing: 8) {
                brand
                amount
                if entry.loggingEnabled {
                    HStack(spacing: 8) {
                        logButton(entry.button1ML, prominent: true)
                        logButton(entry.button2ML, prominent: false)
                        if entry.totalML > 0 { undoButton }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { Theme.Widget.surface }
    }

    private var small: some View {
        VStack(spacing: 7) {
            brand
            vessel(width: 68, height: 74, fontSize: 17)
            if entry.loggingEnabled {
                logButton(entry.button1ML, prominent: true)
            }
        }
        .containerBackground(for: .widget) { Theme.Widget.surface }
    }

    // MARK: Pieces

    /// Mini vessel with a liquid level.
    private func vessel(width: CGFloat, height: CGFloat, fontSize: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.3, style: .continuous)
                .fill(
                    accented
                        ? AnyShapeStyle(.white.opacity(0.10))
                        : AnyShapeStyle(Theme.Widget.aqua.opacity(0.08))
                )
            GeometryReader { geo in
                Rectangle()
                    .fill(
                        accented
                            ? AnyShapeStyle(.white.opacity(0.34))
                            : AnyShapeStyle(Theme.Widget.liquidGradient)
                    )
                    .frame(height: geo.size.height * entry.progress)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .widgetAccentable()
            }
            .clipShape(RoundedRectangle(cornerRadius: width * 0.3, style: .continuous))
            Text(verbatim: "\(entry.percent)%")
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(accented ? 0 : 0.4), radius: 6)
                .contentTransition(.numericText(value: Double(entry.percent)))
                .invalidatableContent()
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: width * 0.3, style: .continuous)
                .strokeBorder(.white.opacity(accented ? 0.28 : 0.14), lineWidth: 1.2)
        )
    }

    /// Quick-add button. Background + border live INSIDE the label and the style
    /// is .plain — the configuration that lets the intent run instead of opening
    /// the app. System supplies the press animation for widget buttons.
    private func logButton(_ ml: Int, prominent: Bool) -> some View {
        Button(intent: LogWaterIntent(volumeML: ml)) {
            Text(verbatim: "+\(ml) \(String(localized: "ml"))")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(accented ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.Widget.ink))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    logButtonFill(prominent: prominent),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(accented ? 0.35 : 0), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func logButtonFill(prominent: Bool) -> AnyShapeStyle {
        if accented { return AnyShapeStyle(.white.opacity(0.16)) }
        return AnyShapeStyle(prominent ? Theme.Widget.buttonPrimaryGradient
                                       : Theme.Widget.buttonSecondaryGradient)
    }

    private var undoButton: some View {
        Button(intent: UndoWaterIntent()) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(accented ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.Widget.danger))
                .frame(width: 38, height: 38)
                .background(
                    accented
                        ? AnyShapeStyle(.white.opacity(0.16))
                        : AnyShapeStyle(Theme.Widget.danger.opacity(0.16)),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(accented ? 0.35 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Lock Screen

    private var circular: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text(verbatim: "\(entry.percent)%")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill").font(.system(size: 11))
                Text(
                    "\(VolumeFormatter.formatted(entry.totalML)) / \(VolumeFormatter.formatted(entry.goalML)) ml"
                )
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
            }
            .widgetAccentable()
            ProgressView(value: entry.progress)
                .progressViewStyle(.linear)
                .tint(.white)
            Text(
                entry.totalML >= entry.goalML
                    ? String(localized: "Goal reached 🎉")
                    : String(
                        localized:
                            "\(VolumeFormatter.formatted(max(0, entry.goalML - entry.totalML))) ml to go"
                    )
            )
            .font(.system(size: 11))
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var inline: some View {
        Text(
            verbatim:
                "💧 \(VolumeFormatter.formatted(entry.totalML)) \(String(localized: "ml")) · \(entry.percent)%"
        )
        .containerBackground(for: .widget) { Color.clear }
    }
}
