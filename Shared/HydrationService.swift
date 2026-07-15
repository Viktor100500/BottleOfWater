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
        // pending до подтверждённой записи в Health: если синхронизацию прервут
        // (смерть процесса и т.п.), flushPendingHealth дошлёт её без дублей.
        entry.pendingHealthSync = true
        context.insert(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return entry
    }

    func syncToHealth(_ entry: WaterEntry) async {
        if entry.healthKitID == nil {
            // Прошлая попытка могла прерваться ПОСЛЕ записи в Health —
            // сначала ищем сэмпл по external UUID и усыновляем его (никаких дублей).
            entry.healthKitID = await HealthKitService.shared.existingSampleID(entryID: entry.id)
        }
        if entry.healthKitID == nil {
            entry.healthKitID = await HealthKitService.shared.save(volumeML: entry.volumeML,
                                                                   date: entry.timestamp,
                                                                   entryID: entry.id)
        }
        if entry.healthKitID != nil {
            entry.pendingHealthSync = false
        }
        try? context.save()
    }

    func delete(_ entry: WaterEntry) async {
        let entryID = entry.id
        let sampleID = entry.healthKitID
        context.delete(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()

        var ok = await HealthKitService.shared.delete(entryID: entryID)
        if let sampleID {
            ok = await HealthKitService.shared.delete(sampleID: sampleID) && ok
        }
        if !ok {
            // Health сейчас недоступен — дочистим в flushPendingHealth().
            SettingsStore.pendingHealthDeletes.append(entryID)
            if let sampleID { SettingsStore.pendingHealthDeletes.append(sampleID) }
        }
    }

    /// Undo the last of today's entries.
    func undoLastToday() async {
        guard let last = lastEntryToday() else { return }
        await delete(last)
    }

    // MARK: Reconciliation with Apple Health

    private var isFlushing = false

    /// Форс-синхронизация с Apple Health: дошлифовывает записи, чья синхронизация
    /// прервалась, и выполняет отложенные удаления. Вызывается в критических точках
    /// (запуск, возврат в приложение, уход в фон). Защищена от параллельного входа —
    /// одновременный двойной flush и был источником дублей в Health.
    func flushPendingHealth() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        // 1. Отложенные удаления (из виджета или при недоступном Health).
        let deletes = SettingsStore.pendingHealthDeletes
        if !deletes.isEmpty {
            var remaining: [UUID] = []
            for id in deletes {
                let byEntry = await HealthKitService.shared.delete(entryID: id)
                let bySample = await HealthKitService.shared.delete(sampleID: id)
                if !(byEntry && bySample) { remaining.append(id) }
            }
            SettingsStore.pendingHealthDeletes = remaining
        }

        // 2. Записи, не дошедшие до Health (syncToHealth дедуплицирует и сохраняет
        //    контекст после каждой записи — прерывание не откатывает уже сделанное).
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.pendingHealthSync == true })
        let pending = (try? context.fetch(descriptor)) ?? []
        for entry in pending {
            await syncToHealth(entry)
        }

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
