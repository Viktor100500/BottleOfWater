import Foundation
import SwiftData
import WidgetKit

/// The single path for every change to the water log, in the app and in extensions:
/// save locally → Apple Health → reminders → widgets → ping other processes.
@MainActor
@Observable
final class WaterStore {
    static let shared = WaterStore()

    let container: ModelContainer
    /// Bumped on every change (local or from another process); views read it to refresh.
    private(set) var revision = 0

    @ObservationIgnored private var context: ModelContext { container.mainContext }
    @ObservationIgnored private var deletedIDs: Set<UUID> = []
    @ObservationIgnored private var isFlushing = false

    private init() {
        container = WaterDatabase.openContainer()
    }

    // MARK: Mutations

    @discardableResult
    func add(ml: Int, at date: Date = .now, source: EntrySource) async -> WaterEntry? {
        let ml = min(5000, ml)
        guard ml > 0 else { return nil }
        let entry = WaterEntry(timestamp: min(date, .now), volumeML: ml, source: source)
        context.insert(entry)
        commit()
        await push(entry)
        await afterChange()
        return entry
    }

    /// `add` for callers outside the main actor that don't need the entry back.
    func log(ml: Int, source: EntrySource) async {
        await add(ml: ml, source: source)
    }

    func update(_ entry: WaterEntry, ml: Int, date: Date) async {
        guard ml > 0, ml != entry.volumeML || date != entry.timestamp else { return }
        if let legacy = entry.healthKitID {
            // v0 sample without a sync identifier: remove it, the new version replaces it.
            if await HealthSync.shared.deleteLegacy(sampleID: legacy) { entry.healthKitID = nil }
        }
        entry.volumeML = min(5000, ml)
        entry.timestamp = min(date, .now)
        entry.healthSyncVersion += 1
        entry.pendingHealthSync = true
        commit()
        await push(entry)
        await afterChange()
    }

    func delete(_ entry: WaterEntry) async {
        let sample = entry.healthSample
        deletedIDs.insert(entry.id)
        context.delete(entry)
        commit()
        if !(await HealthSync.shared.delete(sample)) {
            SettingsStore.pendingHealthDeletes.append(sample.syncID)
        }
        await afterChange()
    }

    /// Removes today's most recent entry. Returns its volume.
    @discardableResult
    func undoLast() async -> Int? {
        guard let last = entries(on: .now).first else { return nil }
        let ml = last.volumeML
        await delete(last)
        return ml
    }

    // MARK: Apple Health

    private func push(_ entry: WaterEntry) async {
        guard HealthSync.shared.canWrite else { return }
        let sample = entry.healthSample
        guard await HealthSync.shared.save(sample) else { return }
        if deletedIDs.contains(entry.id) {
            // Undone while the save was in flight.
            _ = await HealthSync.shared.delete(sample)
            return
        }
        if entry.healthSyncVersion == sample.version {
            entry.pendingHealthSync = false
            commit()
        }
    }

    /// Retries everything that didn't reach Apple Health. Safe to call often.
    func flushPendingHealth() async {
        guard HealthSync.shared.canWrite, !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        var remaining: [String] = []
        for syncID in SettingsStore.pendingHealthDeletes {
            let sample = HealthSync.Sample(syncID: syncID, volumeML: 0, date: .now, version: 0, legacySampleID: nil)
            if !(await HealthSync.shared.delete(sample)) { remaining.append(syncID) }
        }
        SettingsStore.pendingHealthDeletes = remaining

        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.pendingHealthSync == true })
        for entry in (try? context.fetch(descriptor)) ?? [] {
            await push(entry)
        }
    }

    // MARK: Change propagation

    private func commit() {
        try? context.save()
        revision += 1
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func afterChange() async {
        ChangeNotifier.post()
        await ReminderScheduler.reschedule()
    }

    /// Another process (widget, control, Siri) changed the store.
    func externalChange() {
        revision += 1
    }

    // MARK: Reads

    func entries(on day: Date) -> [WaterEntry] {
        let interval = Calendar.current.dateInterval(of: .day, for: day)!
        return entries(in: interval).reversed()
    }

    /// Ascending by time.
    func entries(in interval: DateInterval) -> [WaterEntry] {
        let start = interval.start, end = interval.end
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func entry(id: UUID) -> WaterEntry? {
        var descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func total(on day: Date) -> Int {
        entries(on: day).reduce(0) { $0 + $1.volumeML }
    }

    /// Per-day totals for the whole log (for streaks and charts).
    func dailyTotals() -> [Date: Int] {
        let descriptor = FetchDescriptor<WaterEntry>()
        let all = (try? context.fetch(descriptor)) ?? []
        return HistoryMath.dailyTotals(all.map { ($0.timestamp, $0.volumeML) })
    }

    func reminderContext(now: Date = .now) -> ReminderPlanner.Context {
        let today = entries(on: now)
        return ReminderPlanner.Context(now: now,
                                       lastLog: today.first?.timestamp,
                                       todayTotalML: today.reduce(0) { $0 + $1.volumeML },
                                       goalML: SettingsStore.goalML)
    }
}
