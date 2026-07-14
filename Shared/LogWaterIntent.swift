import AppIntents
import Foundation

/// Quick-log intent used by widget buttons (Home Screen / Lock Screen).
/// Runs in the app's process — the entry lands in both the database and Apple Health.
struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log water"
    static let description = IntentDescription("Adds water to Bottle of Water and Apple Health.")

    @Parameter(title: "Volume (ml)")
    var volumeML: Int

    init() {}

    init(volumeML: Int) {
        self.volumeML = volumeML
    }

    func perform() async throws -> some IntentResult {
        guard SettingsStore.widgetLoggingEnabled else { return .result() }
        // log() записывает локально и сразу перезагружает виджет;
        // Health-синхронизация идёт после и не задерживает обновление UI.
        await HydrationService.shared.logAndSync(volumeML: volumeML, source: .widget)
        return .result()
    }
}

/// Undo the last of today's entries right from the widget.
struct UndoWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Undo last entry"
    static let description = IntentDescription("Removes the last water entry from Bottle of Water and Apple Health.")

    init() {}

    func perform() async throws -> some IntentResult {
        await HydrationService.shared.undoLastToday()
        return .result()
    }
}
