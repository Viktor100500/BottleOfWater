import Foundation
import SwiftData
import WidgetKit

/// App-side water logging. Owns the main SwiftData container the UI reads from,
/// and is the only place that talks to Apple Health (the app has the entitlement,
/// widget extensions do not).
@MainActor
final class HydrationService {
    static let shared = HydrationService()

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    private init() {
        do {
            container = try BottleDatabase.makeContainer()
        } catch {
            fatalError("Не удалось открыть базу данных: \(error)")
        }
    }

    // MARK: Logging (app)

    @discardableResult
    func log(volumeML: Int, source: EntrySource, date: Date = .now) -> WaterEntry {
        let entry = WaterEntry(timestamp: date, volumeML: volumeML, source: source)
        context.insert(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return entry
    }

    func syncToHealth(_ entry: WaterEntry) async {
        entry.healthKitID = await HealthKitService.shared.save(volumeML: entry.volumeML,
                                                               date: entry.timestamp)
        entry.pendingHealthSync = false
        try? context.save()
    }

    func delete(_ entry: WaterEntry) async {
        let hkID = entry.healthKitID
        context.delete(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        if let hkID { await HealthKitService.shared.delete(sampleID: hkID) }
    }

    /// Undo the last of today's entries.
    func undoLastToday() async {
        guard let last = lastEntryToday() else { return }
        await delete(last)
    }

    // MARK: Reconciliation with Apple Health

    /// Push widget-created entries to Health and process widget-queued deletions.
    /// Called when the app becomes active. Also nudges the main context so
    /// `@Query`-backed views pick up rows the widget wrote in another process.
    func flushPendingHealth() async {
        // 1. Deletions queued by the widget's undo.
        let deletes = SettingsStore.pendingHealthDeletes
        if !deletes.isEmpty {
            for id in deletes { await HealthKitService.shared.delete(sampleID: id) }
            SettingsStore.pendingHealthDeletes = []
        }

        // 2. Entries the widget saved without Health access.
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.pendingHealthSync == true })
        let pending = (try? context.fetch(descriptor)) ?? []
        for entry in pending {
            await syncToHealth(entry)
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Reads

    func lastEntryToday() -> WaterEntry? {
        let start = Calendar.current.startOfDay(for: .now)
        var descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.timestamp >= start },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func totalToday() -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.timestamp >= start })
        return ((try? context.fetch(descriptor)) ?? []).reduce(0) { $0 + $1.volumeML }
    }
}

/// Read-only snapshot for the widget process.
enum WidgetDataReader {
    struct Data {
        var totalML: Int
        var goalML: Int
        var progress: Double { min(1, Double(totalML) / Double(max(1, goalML))) }
    }

    static func today() -> Data {
        let goal = SettingsStore.goalML
        guard let container = try? BottleDatabase.makeContainer() else {
            return Data(totalML: 0, goalML: goal)
        }
        let context = ModelContext(container)
        let start = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.timestamp >= start })
        let total = ((try? context.fetch(descriptor)) ?? []).reduce(0) { $0 + $1.volumeML }
        return Data(totalML: total, goalML: goal)
    }
}
