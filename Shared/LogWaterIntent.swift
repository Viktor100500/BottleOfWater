import AppIntents
import Foundation

/// Quick-log intent for widget buttons (Home Screen / Lock Screen).
/// Executes in the widget process and writes locally only — no HealthKit here
/// (unavailable in extensions), so the intent never fails and the tap runs the
/// action instead of falling back to opening the app.
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
        WidgetLogger.log(volumeML: volumeML, source: .widget)
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
        WidgetLogger.undoLastToday()
        return .result()
    }
}
