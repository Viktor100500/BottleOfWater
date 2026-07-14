import Foundation

enum BottleShared {
    static let appGroupID = "group.com.vlasov.bottleofwater"
    static let defaults: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard
}

// MARK: - Volume presets

struct VolumePreset: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var volumeML: Int
    var name: String
    var emoji: String

    static var defaults: [VolumePreset] {
        [
            VolumePreset(volumeML: 100, name: String(localized: "Small glass"), emoji: "🥃"),
            VolumePreset(volumeML: 200, name: String(localized: "Glass"), emoji: "🥛"),
            VolumePreset(volumeML: 250, name: String(localized: "Cup"), emoji: "☕️"),
            VolumePreset(volumeML: 300, name: String(localized: "Big cup"), emoji: "🍵"),
            VolumePreset(volumeML: 330, name: String(localized: "Can"), emoji: "🥫"),
            VolumePreset(volumeML: 500, name: String(localized: "Bottle"), emoji: "🍶"),
        ]
    }
}

// MARK: - Reminders

enum AutoSchedule: String, Codable, CaseIterable {
    case every2h, meals, custom

    var title: String {
        switch self {
        case .every2h: return String(localized: "Every 2 hours")
        case .meals: return String(localized: "Meals")
        case .custom: return String(localized: "Custom interval")
        }
    }

    var subtitle: String? {
        switch self {
        case .meals: return String(localized: "your meal times, editable")
        case .custom: return String(localized: "interval and time window of your choice")
        default: return nil
        }
    }
}

/// A meal (or snack) slot for the "Meals" auto schedule. Fully user-editable.
struct MealTime: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var minutesFromMidnight: Int   // 0...1439
    var label: String

    static var defaults: [MealTime] {
        [
            MealTime(minutesFromMidnight: 8 * 60, label: String(localized: "Breakfast")),
            MealTime(minutesFromMidnight: 13 * 60, label: String(localized: "Lunch")),
            MealTime(minutesFromMidnight: 19 * 60, label: String(localized: "Dinner")),
        ]
    }
}

struct ManualReminder: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var minutesFromMidnight: Int   // 0...1439
    var label: String = ""
    var weekdaysOnly: Bool = false
}

// MARK: - Settings (App Group UserDefaults)

enum SettingsStore {
    private static var d: UserDefaults { BottleShared.defaults }

    static var goalML: Int {
        get { max(500, d.object(forKey: "goalML") as? Int ?? 2000) }
        set { d.set(min(6000, max(500, newValue)), forKey: "goalML") }
    }

    static var useOunces: Bool {
        get { d.bool(forKey: "useOunces") }
        set { d.set(newValue, forKey: "useOunces") }
    }

    static var presets: [VolumePreset] {
        get {
            guard let data = d.data(forKey: "presets"),
                  let list = try? JSONDecoder().decode([VolumePreset].self, from: data),
                  !list.isEmpty else { return VolumePreset.defaults }
            return list
        }
        set { d.set((try? JSONEncoder().encode(newValue)) ?? Data(), forKey: "presets") }
    }

    static var widgetLoggingEnabled: Bool {
        get { d.object(forKey: "widgetLoggingEnabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "widgetLoggingEnabled") }
    }

    static var widgetButton1ML: Int {
        get { d.object(forKey: "widgetButton1ML") as? Int ?? 200 }
        set { d.set(newValue, forKey: "widgetButton1ML") }
    }

    static var widgetButton2ML: Int {
        get { d.object(forKey: "widgetButton2ML") as? Int ?? 330 }
        set { d.set(newValue, forKey: "widgetButton2ML") }
    }

    // Reminders: auto and custom work independently and can run in parallel
    static var autoRemindersEnabled: Bool {
        get { d.bool(forKey: "autoRemindersEnabled") }
        set { d.set(newValue, forKey: "autoRemindersEnabled") }
    }

    static var manualRemindersEnabled: Bool {
        get { d.bool(forKey: "manualRemindersEnabled") }
        set { d.set(newValue, forKey: "manualRemindersEnabled") }
    }

    static var autoSchedule: AutoSchedule {
        get { AutoSchedule(rawValue: d.string(forKey: "autoSchedule") ?? "") ?? .every2h }
        set { d.set(newValue.rawValue, forKey: "autoSchedule") }
    }

    /// Meal slots for the "Meals" schedule. 1...10, times editable.
    static var meals: [MealTime] {
        get {
            guard let data = d.data(forKey: "mealTimes"),
                  let list = try? JSONDecoder().decode([MealTime].self, from: data),
                  !list.isEmpty else { return MealTime.defaults }
            return list
        }
        set { d.set((try? JSONEncoder().encode(newValue)) ?? Data(), forKey: "mealTimes") }
    }

    /// Custom interval in minutes (fix #3). 15 min … 6 h, step 15.
    static var customIntervalMinutes: Int {
        get { min(360, max(15, d.object(forKey: "customIntervalMinutes") as? Int ?? 90)) }
        set { d.set(min(360, max(15, newValue)), forKey: "customIntervalMinutes") }
    }

    static var activeWindowStart: Int {  // minutes from midnight
        get { d.object(forKey: "activeWindowStart") as? Int ?? 8 * 60 }
        set { d.set(newValue, forKey: "activeWindowStart") }
    }

    static var activeWindowEnd: Int {
        get { d.object(forKey: "activeWindowEnd") as? Int ?? 22 * 60 }
        set { d.set(newValue, forKey: "activeWindowEnd") }
    }

    static var quietHoursEnabled: Bool {
        get { d.object(forKey: "quietHoursEnabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "quietHoursEnabled") }
    }

    static var quietStart: Int {
        get { d.object(forKey: "quietStart") as? Int ?? 22 * 60 }
        set { d.set(newValue, forKey: "quietStart") }
    }

    static var quietEnd: Int {
        get { d.object(forKey: "quietEnd") as? Int ?? 7 * 60 }
        set { d.set(newValue, forKey: "quietEnd") }
    }

    static var manualReminders: [ManualReminder] {
        get {
            guard let data = d.data(forKey: "manualReminders"),
                  let list = try? JSONDecoder().decode([ManualReminder].self, from: data) else { return [] }
            return list
        }
        set { d.set((try? JSONEncoder().encode(newValue)) ?? Data(), forKey: "manualReminders") }
    }

    /// Is this minute inside quiet hours? (handles the over-midnight case)
    static func isQuiet(minutes: Int) -> Bool {
        guard quietHoursEnabled else { return false }
        let s = quietStart, e = quietEnd
        if s == e { return false }
        if s < e { return minutes >= s && minutes < e }
        return minutes >= s || minutes < e
    }
}

// MARK: - Volume formatting

enum VolumeFormatter {
    static let mlPerOz = 29.5735

    static func string(ml: Int, ounces: Bool? = nil) -> String {
        let oz = ounces ?? SettingsStore.useOunces
        if oz {
            let value = Double(ml) / mlPerOz
            return String(localized: "\(value, specifier: "%.1f") oz")
        }
        return String(localized: "\(formatted(ml)) ml")
    }

    static func formatted(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Tips

enum HydrationTips {
    static var all: [String] {
        [
            String(localized: "Thirst is a late warning. Sip regularly, don't wait for it."),
            String(localized: "A glass of water right after waking up kick-starts your metabolism."),
            String(localized: "Coffee and tea count too, but plain water works best."),
            String(localized: "Keep a bottle where you can see it — it makes remembering easy."),
            String(localized: "Sip every 15–20 minutes instead of gulping once a day."),
            String(localized: "Mild fatigue and headaches are often signs of dehydration."),
            String(localized: "Cool water is absorbed faster than warm water."),
            String(localized: "A glass of water 30 minutes before a meal helps digestion."),
            String(localized: "In heat or during workouts you need 1.5–2× more water."),
            String(localized: "Pale straw-colored urine is a sign of good hydration."),
            String(localized: "Don't drink a lot right before bed — better an hour earlier."),
            String(localized: "Add a slice of lemon or cucumber if plain water gets boring."),
            String(localized: "Every cup of coffee — one extra glass of water for balance."),
            String(localized: "Dry skin and lips? Start with water, not creams."),
            String(localized: "The rule is simple: small portions, but often."),
            String(localized: "Water helps you focus: your brain is 75% water."),
            String(localized: "Flights dehydrate you — bring water on the plane."),
            String(localized: "Workouts: 200–300 ml about 20 minutes before you start."),
            String(localized: "Anchor sips to habits: checked your email — took a sip."),
            String(localized: "The goal is a guide, not a punishment. Just keep going."),
        ]
    }

    /// A stable tip for the current hour.
    static var current: String {
        let hour = Calendar.current.ordinality(of: .hour, in: .era, for: Date()) ?? 0
        let tips = all
        return tips[hour % tips.count]
    }
}
