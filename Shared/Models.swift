import Foundation
import SwiftData

enum EntrySource: String {
    case app, widget

    var label: String {
        switch self {
        case .app: return String(localized: "App")
        case .widget: return String(localized: "Widget")
        }
    }
}

@Model
final class WaterEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var volumeML: Int = 0
    var sourceRaw: String = EntrySource.app.rawValue
    var healthKitID: UUID?
    /// Set when an entry was created outside the app (widget), where HealthKit
    /// is unavailable. The app flushes these to Apple Health when it activates.
    var pendingHealthSync: Bool = false

    var source: EntrySource { EntrySource(rawValue: sourceRaw) ?? .app }

    init(timestamp: Date = .now, volumeML: Int, source: EntrySource) {
        self.id = UUID()
        self.timestamp = timestamp
        self.volumeML = volumeML
        self.sourceRaw = source.rawValue
    }
}

enum BottleDatabase {
    static func storeURL() -> URL {
        let base = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: BottleShared.appGroupID)
            ?? URL.applicationSupportDirectory
        return base.appendingPathComponent("BottleOfWater.store")
    }

    static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(url: storeURL())
        return try ModelContainer(for: WaterEntry.self, configurations: config)
    }
}
