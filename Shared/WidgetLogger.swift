import Foundation
import SwiftData
import WidgetKit

/// Water logging used by widget App Intents (runs in the widget-extension process).
///
/// Order matters: the local save + widget reload happen FIRST so the widget
/// updates instantly, then Apple Health is written directly from the extension.
/// If the Health write fails for any reason, the entry keeps
/// `pendingHealthSync = true` and the app re-syncs it in `flushPendingHealth()`
/// — so a Health hiccup can never lose a log or break the button.
enum WidgetLogger {

    static func log(volumeML: Int, source: EntrySource) async {
        guard let container = try? BottleDatabase.makeContainer() else { return }
        let context = ModelContext(container)
        let entry = WaterEntry(volumeML: volumeML, source: source)
        entry.pendingHealthSync = true
        context.insert(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()

        // Мгновенная синхронизация с Apple Health прямо из виджета.
        if let hkID = await HealthKitService.shared.save(volumeML: entry.volumeML,
                                                         date: entry.timestamp,
                                                         entryID: entry.id) {
            entry.healthKitID = hkID
            entry.pendingHealthSync = false
            try? context.save()
        }
    }

    static func undoLastToday() async {
        guard let container = try? BottleDatabase.makeContainer() else { return }
        let context = ModelContext(container)
        let start = Calendar.current.startOfDay(for: .now)
        var descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.timestamp >= start },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let last = (try? context.fetch(descriptor))?.first else { return }

        let entryID = last.id
        let sampleID = last.healthKitID
        context.delete(last)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()

        // Сразу удаляем из Health; при неудаче — в очередь, приложение дочистит.
        var ok = await HealthKitService.shared.delete(entryID: entryID)
        if let sampleID {
            ok = await HealthKitService.shared.delete(sampleID: sampleID) && ok
        }
        if !ok {
            SettingsStore.pendingHealthDeletes.append(entryID)
            if let sampleID { SettingsStore.pendingHealthDeletes.append(sampleID) }
        }
    }
}
