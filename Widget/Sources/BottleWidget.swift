import AppIntents
import SwiftUI
import WidgetKit

@main
struct BottleWidgetBundle: WidgetBundle {
    var body: some Widget {
        BottleWidget()
        LogWaterControl()
    }
}

// MARK: - Timeline

struct BottleEntry: TimelineEntry {
    var date: Date
    var totalML: Int
    var goalML: Int
    var unit: VolumeUnit
    var button1ML: Int
    var button2ML: Int

    var progress: Double { ProgressMath.fraction(total: totalML, goal: goalML) }
    var percent: Int { ProgressMath.percent(total: totalML, goal: goalML) }
    var goalReached: Bool { totalML >= goalML }

    static let preview = BottleEntry(date: .now, totalML: 1250, goalML: 2000, unit: .localeDefault,
                                     button1ML: 250, button2ML: 500)

    static func load(at date: Date = .now, totalML: Int? = nil) -> BottleEntry {
        BottleEntry(date: date,
                    totalML: totalML ?? WaterDatabase.todayTotal(now: date),
                    goalML: SettingsStore.goalML,
                    unit: SettingsStore.unit,
                    button1ML: SettingsStore.widgetButton1ML,
                    button2ML: SettingsStore.widgetButton2ML)
    }
}

struct BottleProvider: TimelineProvider {
    func placeholder(in context: Context) -> BottleEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping (BottleEntry) -> Void) {
        completion(context.isPreview ? .preview : .load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BottleEntry>) -> Void) {
        let now = Date.now
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        // Today's value, then a fresh empty day at midnight.
        let entries = [BottleEntry.load(at: now), BottleEntry.load(at: midnight, totalML: 0)]
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }
}

struct BottleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BottleWidget", provider: BottleProvider()) { entry in
            BottleWidgetView(entry: entry)
        }
        .configurationDisplayName("Water Progress")
        .description("Today's progress with one-tap logging.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Control Center / Action Button

struct LogWaterControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LogWaterControl") {
            let ml = SettingsStore.widgetButton1ML
            ControlWidgetButton(action: QuickLogIntent(ml: ml, source: .control)) {
                Label("+\(VolumeFormat.string(ml, unit: SettingsStore.unit))", systemImage: "drop.fill")
            }
        }
        .displayName("Log Water")
        .description("Adds your quick-button amount. Change it in the app's Settings.")
    }
}

// MARK: - Views

struct BottleWidgetView: View {
    var entry: BottleEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    /// Tinted / clear home screen and the Lock Screen render without our colors.
    private var accented: Bool { renderingMode != .fullColor }

    var body: some View {
        switch family {
        case .systemMedium: medium
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                vessel(width: 54, height: 64, fontSize: 14)
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(VolumeFormat.number(entry.totalML, unit: entry.unit))
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText(value: Double(entry.totalML)))
                        .widgetAccentable()
                    Text("of \(VolumeFormat.string(entry.goalML, unit: entry.unit))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 0)
            logButton(entry.button1ML, prominent: true)
        }
        .foregroundStyle(accented ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.textPrimary))
        .containerBackground(for: .widget) { Theme.widgetSurface }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            vessel(width: 92, height: 120, fontSize: 24)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.goalReached ? String(localized: "Goal reached") : String(localized: "Today"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accented ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.aqua))
                        .textCase(.uppercase)
                    Text("\(VolumeFormat.number(entry.totalML, unit: entry.unit)) of \(VolumeFormat.string(entry.goalML, unit: entry.unit))")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText(value: Double(entry.totalML)))
                        .widgetAccentable()
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    logButton(entry.button1ML, prominent: true)
                    logButton(entry.button2ML, prominent: false)
                    if entry.totalML > 0 { undoButton }
                }
            }
        }
        .foregroundStyle(accented ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.textPrimary))
        .containerBackground(for: .widget) { Theme.widgetSurface }
    }

    private func vessel(width: CGFloat, height: CGFloat, fontSize: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: width * 0.3, style: .continuous)
        return ZStack {
            shape.fill(accented ? AnyShapeStyle(.white.opacity(0.1)) : AnyShapeStyle(Theme.aqua.opacity(0.08)))
            GeometryReader { geo in
                Rectangle()
                    .fill(accented ? AnyShapeStyle(.white.opacity(0.35))
                                   : AnyShapeStyle(entry.goalReached ? Theme.goalGradient : Theme.liquidGradient))
                    .frame(height: geo.size.height * entry.progress)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .widgetAccentable()
            }
            .clipShape(shape)
            Text(verbatim: "\(entry.percent)%")
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(accented ? 0 : 0.35), radius: 4)
                .contentTransition(.numericText(value: Double(entry.percent)))
        }
        .frame(width: width, height: height)
        .overlay(shape.strokeBorder(.white.opacity(accented ? 0.3 : 0.14), lineWidth: 1.2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(entry.percent) percent of daily goal"))
    }

    /// Background lives inside the label with `.plain` style, so the button runs
    /// the intent instead of opening the app.
    private func logButton(_ ml: Int, prominent: Bool) -> some View {
        Button(intent: QuickLogIntent(ml: ml, source: .widget)) {
            Text(verbatim: "+" + VolumeFormat.number(ml, unit: entry.unit))
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(accented ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.ink))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(accented ? AnyShapeStyle(.white.opacity(0.16))
                                     : AnyShapeStyle(prominent ? Theme.buttonPrimaryGradient : Theme.buttonSecondaryGradient),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Add \(VolumeFormat.string(ml, unit: entry.unit))"))
    }

    private var undoButton: some View {
        Button(intent: UndoLastWaterIntent()) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(accented ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.danger))
                .frame(width: 36, height: 36)
                .background(accented ? AnyShapeStyle(.white.opacity(0.16)) : AnyShapeStyle(Theme.danger.opacity(0.16)),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Undo last drink"))
    }

    // MARK: Lock Screen

    private var circular: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text(verbatim: "\(entry.percent)")
                .font(.system(.body, design: .rounded, weight: .heavy))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                Text("\(VolumeFormat.number(entry.totalML, unit: entry.unit)) of \(VolumeFormat.string(entry.goalML, unit: entry.unit))")
                    .monospacedDigit()
            }
            .font(.system(.headline, design: .rounded, weight: .bold))
            .widgetAccentable()
            ProgressView(value: entry.progress)
                .progressViewStyle(.linear)
            Text(entry.goalReached
                 ? String(localized: "Goal reached")
                 : String(localized: "\(VolumeFormat.string(entry.goalML - entry.totalML, unit: entry.unit)) to go"))
                .font(.caption)
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var inline: some View {
        Label {
            Text(verbatim: "\(VolumeFormat.compact(entry.totalML, unit: entry.unit)) · \(entry.percent)%")
        } icon: {
            Image(systemName: "drop.fill")
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

#Preview(as: .systemMedium) {
    BottleWidget()
} timeline: {
    BottleEntry.preview
}
