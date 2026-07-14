import Foundation
import SwiftData
import WidgetKit

/// Центральная точка записи/удаления воды. Используется приложением и интентом виджета.
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

    // MARK: Запись

    /// Быстрый локальный лог: сохранение + мгновенная перезагрузка виджетов.
    /// Синхронизация с Apple Health — отдельным шагом (`syncToHealth`), чтобы
    /// не задерживать обновление UI и виджета.
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
        try? context.save()
    }

    /// Полный цикл: локально + Health.
    func logAndSync(volumeML: Int, source: EntrySource) async {
        let entry = log(volumeML: volumeML, source: source)
        await syncToHealth(entry)
    }

    func delete(_ entry: WaterEntry) async {
        let hkID = entry.healthKitID
        context.delete(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        if let hkID { await HealthKitService.shared.delete(sampleID: hkID) }
    }

    /// Отмена последней записи за сегодня.
    func undoLastToday() async {
        guard let last = lastEntryToday() else { return }
        await delete(last)
    }

    // MARK: Чтение

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

    func entries(from: Date, to: Date) -> [WaterEntry] {
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.timestamp >= from && $0.timestamp < to },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

/// Чтение данных для виджета (отдельный процесс — свой контейнер, только чтение).
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
