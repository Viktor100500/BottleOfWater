import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Data

struct BottleEntry: TimelineEntry {
    var date: Date
    var totalML: Int
    var goalML: Int
    var button1ML: Int
    var button2ML: Int
    var loggingEnabled: Bool

    var progress: Double { min(1, Double(totalML) / Double(max(1, goalML))) }
    var percent: Int { Int((Double(totalML) / Double(max(1, goalML)) * 100).rounded()) }

    static var demo: BottleEntry {
        BottleEntry(date: .now, totalML: 800, goalML: 2000,
                    button1ML: 200, button2ML: 330, loggingEnabled: true)
    }

    static func current() -> BottleEntry {
        let data = WidgetDataReader.today()
        return BottleEntry(date: .now,
                           totalML: data.totalML,
                           goalML: data.goalML,
                           button1ML: SettingsStore.widgetButton1ML,
                           button2ML: SettingsStore.widgetButton2ML,
                           loggingEnabled: SettingsStore.widgetLoggingEnabled)
    }
}

struct BottleProvider: TimelineProvider {
    func placeholder(in context: Context) -> BottleEntry { .demo }

    func getSnapshot(in context: Context, completion: @escaping (BottleEntry) -> Void) {
        completion(context.isPreview ? .demo : .current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BottleEntry>) -> Void) {
        let entry = BottleEntry.current()
        // Refresh at midnight — the new day's progress starts at zero.
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
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
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct BottleWidgetBundle: WidgetBundle {
    var body: some Widget {
        BottleWidget()
    }
}

// MARK: - Views

struct BottleWidgetView: View {
    var entry: BottleEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    /// accented = tinted home screen, vibrant = lock screen (fix #2).
    private var isAccented: Bool { renderingMode != .fullColor }

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

    private var medium: some View {
        HStack(spacing: 14) {
            vessel(width: 92, height: 116, fontSize: 22)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(VolumeFormatter.formatted(entry.totalML))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .widgetAccentable()
                        .contentTransition(.numericText(value: Double(entry.totalML)))
                        .invalidatableContent()
                    Text("of \(VolumeFormatter.formatted(entry.goalML)) ml")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if entry.loggingEnabled {
                    HStack(spacing: 8) {
                        logButton(entry.button1ML, prominent: true)
                        logButton(entry.button2ML, prominent: false)
                        if entry.totalML > 0 {
                            undoButton
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { widgetBackground }
    }

    private var small: some View {
        VStack(spacing: 8) {
            vessel(width: 72, height: 84, fontSize: 17)
            if entry.loggingEnabled {
                logButton(entry.button1ML, prominent: true)
            } else {
                Text(verbatim: "\(VolumeFormatter.formatted(entry.totalML)) / \(VolumeFormatter.formatted(entry.goalML))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) { widgetBackground }
    }

    /// Mini "vessel" with a liquid level.
    private func vessel(width: CGFloat, height: CGFloat, fontSize: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.3, style: .continuous)
                .fill(isAccented ? AnyShapeStyle(.white.opacity(0.10))
                                 : AnyShapeStyle(Color(red: 0.58, green: 0.72, blue: 1).opacity(0.08)))
            GeometryReader { geo in
                Rectangle()
                    .fill(isAccented
                          ? AnyShapeStyle(.white.opacity(0.34))
                          : AnyShapeStyle(LinearGradient(
                                colors: [Color(red: 0.133, green: 0.827, blue: 0.933),
                                         Color(red: 0.145, green: 0.388, blue: 0.922)],
                                startPoint: .top, endPoint: .bottom)))
                    .frame(height: geo.size.height * entry.progress)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .widgetAccentable()
            }
            .clipShape(RoundedRectangle(cornerRadius: width * 0.3, style: .continuous))
            Text(verbatim: "\(entry.percent)%")
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isAccented ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .shadow(color: .black.opacity(isAccented ? 0 : 0.4), radius: 6)
                .contentTransition(.numericText(value: Double(entry.percent)))
                .invalidatableContent()
        }
        .frame(width: width, height: height)
        .overlay(RoundedRectangle(cornerRadius: width * 0.3, style: .continuous)
            .strokeBorder(.white.opacity(isAccented ? 0.28 : 0.14), lineWidth: 1.2))
    }

    /// Quick-add button. In accented mode: solid fill, border and white text —
    /// readable with any home screen color scheme (fix #2).
    /// No .buttonStyle(.plain): the default style keeps the system press
    /// highlight so taps are visibly acknowledged.
    private func logButton(_ ml: Int, prominent: Bool) -> some View {
        Button(intent: LogWaterIntent(volumeML: ml)) {
            Text(verbatim: "+\(ml) \(String(localized: "ml"))")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(buttonTextStyle(prominent: prominent))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .invalidatableContent()
        }
        .buttonStyle(.borderless)
        .background(buttonBackground(prominent: prominent),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(.white.opacity(isAccented ? 0.35 : 0), lineWidth: 1))
    }

    /// Undo the last entry of the day.
    private var undoButton: some View {
        Button(intent: UndoWaterIntent()) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(isAccented ? AnyShapeStyle(.white)
                                            : AnyShapeStyle(Color(red: 0.984, green: 0.443, blue: 0.522)))
                .frame(width: 34, height: 34)
                .invalidatableContent()
        }
        .buttonStyle(.borderless)
        .background(isAccented ? AnyShapeStyle(.white.opacity(0.16))
                               : AnyShapeStyle(Color(red: 0.984, green: 0.443, blue: 0.522).opacity(0.16)),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(.white.opacity(isAccented ? 0.35 : 0.10), lineWidth: 1))
    }

    private func buttonTextStyle(prominent: Bool) -> AnyShapeStyle {
        if isAccented { return AnyShapeStyle(.white) }
        return AnyShapeStyle(Color(red: 0.016, green: 0.071, blue: 0.11))
    }

    private func buttonBackground(prominent: Bool) -> AnyShapeStyle {
        if isAccented { return AnyShapeStyle(.white.opacity(0.16)) }
        if prominent {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.133, green: 0.827, blue: 0.933),
                         Color(red: 0.22, green: 0.74, blue: 0.97)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(LinearGradient(
            colors: [Color(red: 0.507, green: 0.549, blue: 0.973),
                     Color(red: 0.388, green: 0.400, blue: 0.945)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    @ViewBuilder
    private var widgetBackground: some View {
        if isAccented {
            Color.clear
        } else {
            LinearGradient(colors: [Color(red: 0.051, green: 0.102, blue: 0.188),
                                    Color(red: 0.075, green: 0.102, blue: 0.227)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: Lock Screen (fix #1)

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
                Text("\(VolumeFormatter.formatted(entry.totalML)) / \(VolumeFormatter.formatted(entry.goalML)) ml")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .widgetAccentable()
            ProgressView(value: entry.progress)
                .progressViewStyle(.linear)
                .tint(.white)
            Text(entry.totalML >= entry.goalML
                 ? String(localized: "Goal reached 🎉")
                 : String(localized: "\(VolumeFormatter.formatted(max(0, entry.goalML - entry.totalML))) ml to go"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var inline: some View {
        Text(verbatim: "💧 \(VolumeFormatter.formatted(entry.totalML)) \(String(localized: "ml")) · \(entry.percent)%")
            .containerBackground(for: .widget) { Color.clear }
    }
}
