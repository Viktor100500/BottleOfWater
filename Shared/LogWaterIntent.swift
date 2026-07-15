import AppIntents
import Foundation

/// Quick-log intent for widget buttons (Home Screen / Lock Screen).
/// Saves locally first (instant widget update), then writes to Apple Health
/// directly from the extension; on Health failure the entry stays pending and
/// the app re-syncs it — the intent itself never throws.
struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log water"
    static let description = IntentDescription("Adds water to Bottle of Water and Apple Health.")
    static let openAppWhenRun = false

    @Parameter(title: "Volume (ml)")
    var volumeML: Int

    init() {}

    init(volumeML: Int) {
        self.volumeML = volumeML
    }

    func perform() async throws -> some IntentResult {
        guard SettingsStore.widgetLoggingEnabled else { return .result() }
        await WidgetLogger.log(volumeML: volumeML, source: .widget)
        return .result()
    }
}

/// Undo the last of today's entries right from the widget.
struct UndoWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Undo last entry"
    static let description = IntentDescription("Removes the last water entry from Bottle of Water and Apple Health.")
    static let openAppWhenRun = false

    init() {}

    func perform() async throws -> some IntentResult {
        await WidgetLogger.undoLastToday()
        return .result()
    }
}
