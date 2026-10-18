import Foundation
import SwiftData

enum EntrySource: String, Sendable {
    case app, widget, notification, shortcut, control

    var symbol: String {
        switch self {
        case .app: "iphone"
        case .widget: "square.grid.2x2.fill"
        case .notification: "bell.fill"
        case .shortcut: "waveform"
        case .control: "switch.2"
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .app: "App"
        case .widget: "Widget"
        case .notification: "Reminder"
        case .shortcut: "Siri & Shortcuts"
        case .control: "Control Center"
        }
    }
}

@Model
final class WaterEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var volumeML: Int = 0
    var sourceRaw: String = EntrySource.app.rawValue
    /// Legacy (v0): HealthKit UUID of a sample saved without a sync identifier.
    var healthKitID: UUID?
    /// True until the current version of this entry is confirmed in Apple Health.
    var pendingHealthSync: Bool = true
    /// HKMetadataKeySyncVersion: bumped on every edit so Health replaces the sample.
    var healthSyncVersion: Int = 1

    var source: EntrySource { EntrySource(rawValue: sourceRaw) ?? .app }

    init(timestamp: Date = .now, volumeML: Int, source: EntrySource) {
        self.id = UUID()
        self.timestamp = timestamp
        self.volumeML = volumeML
        self.sourceRaw = source.rawValue
    }

    var healthSample: HealthSync.Sample {
        HealthSync.Sample(syncID: id.uuidString, volumeML: volumeML, date: timestamp,
                          version: healthSyncVersion, legacySampleID: healthKitID)
    }
}

enum WaterDatabase {
    static var storeURL: URL {
        let base = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
            ?? URL.applicationSupportDirectory
        return base.appendingPathComponent("BottleOfWater.store")
    }

    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: WaterEntry.self,
                           configurations: ModelConfiguration(url: storeURL))
    }

    /// Never crashes: a store that can't be opened is moved aside (Apple Health still
    /// has the data) and a fresh one is created; in-memory as the very last resort.
    static func openContainer() -> ModelContainer {
        if let container = try? makeContainer() { return container }
        let fm = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-shm", "-wal"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            try? fm.moveItem(at: url, to: URL(fileURLWithPath: url.path + ".corrupt-\(stamp)"))
        }
        if let container = try? makeContainer() { return container }
        return try! ModelContainer(for: WaterEntry.self,
                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// Read-only snapshot for widgets (any thread, own context).
    static func todayTotal(now: Date = .now) -> Int {
        guard let container = try? makeContainer() else { return 0 }
        let context = ModelContext(container)
        let start = Calendar.current.startOfDay(for: now)
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.timestamp >= start })
        return ((try? context.fetch(descriptor)) ?? []).reduce(0) { $0 + $1.volumeML }
    }
}
