import Foundation

#if !DEBUG
enum DemoData {
    static let screen: String? = nil
    static let initialTab = AppTab.today
    static let initialRange = HistoryRange.week
    static let prefilledAmount: String? = nil
}
#else
import SwiftData
import WidgetKit

/// Debug-only: launch with `-demoData YES` to replace the log with four weeks of
/// realistic history (used for App Store screenshots and UI checks).
@MainActor
enum DemoData {
    static func seedIfRequested() {
        guard UserDefaults.standard.bool(forKey: "demoData") else { return }
        let context = WaterStore.shared.container.mainContext
        try? context.delete(model: WaterEntry.self)

        let unit = SettingsStore.unit
        SettingsStore.onboardingCompleted = true
        SettingsStore.goalML = unit == .milliliters ? 2000 : unit.milliliters(from: 68)
        SettingsStore.presets = VolumePreset.defaults(for: unit)
        var reminders = ReminderSettings()
        reminders.isEnabled = true
        SettingsStore.reminders = reminders

        var random = SeededRandom(seed: 42)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let volumes = VolumePreset.defaults(for: unit).map(\.volumeML)
        let sources: [EntrySource] = [.app, .app, .widget, .widget, .notification, .control]

        for offset in 1...27 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let target = Int.random(in: 1500...2600, using: &random)
            var total = 0
            var minute = 7 * 60 + Int.random(in: 30...90, using: &random)
            while total < target, minute < 22 * 60 {
                let ml = volumes[Int.random(in: 1..<volumes.count, using: &random)]
                insert(ml, at: calendar.date(byAdding: .minute, value: minute, to: day)!,
                       source: sources[Int.random(in: 0..<sources.count, using: &random)], into: context)
                total += ml
                minute += Int.random(in: 60...150, using: &random)
            }
        }

        // Today: a good morning so far, ending an hour ago.
        let now = Date.now
        for (hoursAgo, index, source) in [(7.0, 1, EntrySource.app), (5.5, 3, .widget), (4.0, 2, .notification),
                                          (2.5, 4, .app), (1.0, 1, .control)] {
            let date = now.addingTimeInterval(-hoursAgo * 3600)
            guard calendar.isDate(date, inSameDayAs: now) else { continue }
            insert(volumes[index], at: date, source: source, into: context)
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func insert(_ ml: Int, at date: Date, source: EntrySource, into context: ModelContext) {
        let entry = WaterEntry(timestamp: date, volumeML: ml, source: source)
        entry.pendingHealthSync = false
        context.insert(entry)
    }
}

extension DemoData {
    /// `-screen history|settings|reminders|add` opens a screen directly (screenshots).
    static var screen: String? { UserDefaults.standard.string(forKey: "screen") }

    /// `-range month` etc.
    static var initialRange: HistoryRange {
        UserDefaults.standard.string(forKey: "range").flatMap(HistoryRange.init(rawValue:)) ?? .week
    }

    /// `-amount 350` prefills the keypad.
    static var prefilledAmount: String? { UserDefaults.standard.string(forKey: "amount") }

    static var initialTab: AppTab {
        switch screen {
        case "history": .history
        case "settings", "reminders": .settings
        default: .today
        }
    }
}

/// Deterministic generator, so screenshots look the same on every run.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
#endif
