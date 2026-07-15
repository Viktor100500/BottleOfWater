import Foundation
import SwiftData
import WidgetKit

/// Minimal, self-contained water logging used by widget App Intents.
///
/// Runs inside the widget-extension process, where HealthKit is unavailable,
/// so it writes ONLY to the shared SwiftData store and never touches HealthKit.
/// If it threw or crashed here, iOS would silently fall back to opening the app
/// instead of running the intent — which is exactly the bug this avoids.
/// The app reconciles these entries with Apple Health when it next activates.
enum WidgetLogger {

    static func log(volumeML: Int, source: EntrySource) {
        guard let container = try? BottleDatabase.makeContainer() else { return }
        let context = ModelContext(container)
        let entry = WaterEntry(volumeML: volumeML, source: source)
        entry.pendingHealthSync = true   // app will push this to Health later
        context.insert(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func undoLastToday() {
        guard let container = try? BottleDatabase.makeContainer() else { return }
        let context = ModelContext(container)
        let start = Calendar.current.startOfDay(for: .now)
        var descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.timestamp >= start },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let last = try? context.fetch(descriptor).first else { return }

        // If it already reached Health, queue its removal for the app to perform.
        if let hkID = last.healthKitID {
            SettingsStore.pendingHealthDeletes.append(hkID)
        }
        context.delete(last)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
