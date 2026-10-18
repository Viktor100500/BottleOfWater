import Foundation

struct VolumePreset: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID()
    var volumeML: Int
    var name: String
    var emoji: String

    static let maxCount = 8

    /// Built-in names are stored as keys and translated on display, so they
    /// follow the device language; names the user typed are shown as is.
    var displayName: String {
        switch name {
        case "Sip": String(localized: "Sip")
        case "Glass": String(localized: "Glass")
        case "Cup": String(localized: "Cup")
        case "Can": String(localized: "Can")
        case "Bottle": String(localized: "Bottle")
        case "Tumbler": String(localized: "Tumbler")
        default: name
        }
    }

    static func defaults(for unit: VolumeUnit) -> [VolumePreset] {
        switch unit {
        case .milliliters:
            return [
                VolumePreset(volumeML: 100, name: "Sip", emoji: "💧"),
                VolumePreset(volumeML: 200, name: "Glass", emoji: "🥛"),
                VolumePreset(volumeML: 250, name: "Cup", emoji: "☕️"),
                VolumePreset(volumeML: 330, name: "Can", emoji: "🥤"),
                VolumePreset(volumeML: 500, name: "Bottle", emoji: "🧊"),
            ]
        case .fluidOunces:
            return [
                VolumePreset(volumeML: 118, name: "Sip", emoji: "💧"),
                VolumePreset(volumeML: 237, name: "Glass", emoji: "🥛"),
                VolumePreset(volumeML: 355, name: "Can", emoji: "🥤"),
                VolumePreset(volumeML: 500, name: "Bottle", emoji: "🧊"),
                VolumePreset(volumeML: 591, name: "Tumbler", emoji: "🧋"),
            ]
        }
    }
}

struct ReminderTime: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID()
    /// Minutes from midnight, 0...1439.
    var minutes: Int
    var label: String = ""
    /// Calendar weekdays (1 = Sunday … 7 = Saturday).
    var weekdays: Set<Int> = Set(1...7)
}

struct ReminderSettings: Codable, Equatable, Sendable {
    enum Mode: String, Codable, CaseIterable, Sendable {
        case interval, times
    }

    var isEnabled = false
    var mode: Mode = .interval
    var intervalMinutes = 90
    var windowStart = 9 * 60
    var windowEnd = 21 * 60
    var times: [ReminderTime] = [
        ReminderTime(minutes: 9 * 60),
        ReminderTime(minutes: 12 * 60 + 30),
        ReminderTime(minutes: 15 * 60 + 30),
        ReminderTime(minutes: 18 * 60 + 30),
    ]
    /// Interval mode: count the interval from the last drink.
    /// Times mode: skip a reminder if you drank in the 30 minutes before it.
    var skipIfRecentlyLogged = true
    var skipWhenGoalReached = true

    static let intervalRange = 30...240
    static let maxTimes = 12
}

/// App-group backed settings, readable from any process and thread.
enum SettingsStore {
    private static var d: UserDefaults { AppGroup.defaults }

    static let goalRange = 500...6000

    static var goalML: Int {
        get { clampGoal(d.object(forKey: "goalML") as? Int ?? 2000) }
        set { d.set(clampGoal(newValue), forKey: "goalML") }
    }

    static var unit: VolumeUnit {
        get {
            if let raw = d.string(forKey: "unit"), let unit = VolumeUnit(rawValue: raw) { return unit }
            // v0 stored a boolean
            if d.object(forKey: "useOunces") != nil {
                return d.bool(forKey: "useOunces") ? .fluidOunces : .milliliters
            }
            return .localeDefault
        }
        set { d.set(newValue.rawValue, forKey: "unit") }
    }

    static var presets: [VolumePreset] {
        get { decode([VolumePreset].self, "presets").flatMap { $0.isEmpty ? nil : $0 } ?? VolumePreset.defaults(for: unit) }
        set { encode(Array(newValue.prefix(VolumePreset.maxCount)), "presets") }
    }

    static var widgetButton1ML: Int {
        get { d.object(forKey: "widgetButton1ML") as? Int ?? presets.dropFirst().first?.volumeML ?? 200 }
        set { d.set(newValue, forKey: "widgetButton1ML") }
    }

    static var widgetButton2ML: Int {
        get { d.object(forKey: "widgetButton2ML") as? Int ?? presets.last?.volumeML ?? 500 }
        set { d.set(newValue, forKey: "widgetButton2ML") }
    }

    static var reminders: ReminderSettings {
        get { decode(ReminderSettings.self, "reminderSettings") ?? ReminderSettings() }
        set { encode(newValue, "reminderSettings") }
    }

    static var onboardingCompleted: Bool {
        get { d.bool(forKey: "onboardingCompleted") }
        set { d.set(newValue, forKey: "onboardingCompleted") }
    }

    /// Health sync identifiers whose samples still need deleting.
    static var pendingHealthDeletes: [String] {
        get { d.stringArray(forKey: "pendingHealthDeletes.v2") ?? [] }
        set { d.set(Array(Set(newValue)), forKey: "pendingHealthDeletes.v2") }
    }

    private static func clampGoal(_ value: Int) -> Int {
        min(goalRange.upperBound, max(goalRange.lowerBound, value))
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, _ key: String) {
        d.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
