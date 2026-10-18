import Foundation
import UserNotifications

/// Turns `ReminderPlanner` output into local notifications. Rescheduled after every
/// log (from any process), on app activation and from background refresh — so the
/// rolling window never runs dry and reminders adapt to what you actually drank.
@MainActor
enum ReminderScheduler {
    static let categoryID = "WATER_REMINDER"
    private static let idPrefix = "reminder."
    nonisolated private static let actionPrefix = "log."

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let settings = SettingsStore.reminders
        guard settings.isEnabled, await isAuthorized() else { return }
        registerCategories()

        let context = WaterStore.shared.reminderContext()
        let dates = ReminderPlanner.plan(settings, context: context)
        let calendar = Calendar.current
        let titles = messages
        let unit = SettingsStore.unit

        for (index, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = titles[index % titles.count]
            if calendar.isDate(date, inSameDayAs: context.now) {
                let left = max(0, context.goalML - context.todayTotalML)
                content.body = String(localized: "\(VolumeFormat.string(left, unit: unit)) left to reach today's goal.")
            } else {
                content.body = String(localized: "Today's goal: \(VolumeFormat.string(context.goalML, unit: unit)).")
            }
            content.sound = .default
            content.categoryIdentifier = categoryID
            content.threadIdentifier = "reminders"
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: idPrefix + String(Int(date.timeIntervalSince1970)),
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// "+200 mL" / "+500 mL" actions right on the notification.
    static func registerCategories() {
        let unit = SettingsStore.unit
        let volumes = [SettingsStore.widgetButton1ML, SettingsStore.widgetButton2ML]
        let actions = Array(Set(volumes)).sorted().map { ml in
            UNNotificationAction(identifier: actionPrefix + String(ml),
                                 title: "+" + VolumeFormat.string(ml, unit: unit),
                                 options: [],
                                 icon: UNNotificationActionIcon(systemImageName: "drop.fill"))
        }
        let category = UNNotificationCategory(identifier: categoryID, actions: actions,
                                              intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Volume encoded in a notification action identifier.
    nonisolated static func volume(fromAction identifier: String) -> Int? {
        guard identifier.hasPrefix(actionPrefix) else { return nil }
        return Int(identifier.dropFirst(actionPrefix.count))
    }

    private static var messages: [String] {
        [
            String(localized: "Time for a few sips 💧"),
            String(localized: "Quick water break?"),
            String(localized: "Your bottle misses you"),
            String(localized: "A glass of water, then back to it"),
            String(localized: "Stay on track — have some water"),
        ]
    }

    /// Next fire date for the settings preview.
    static func nextReminder(for settings: ReminderSettings) -> Date? {
        ReminderPlanner.plan(settings, context: WaterStore.shared.reminderContext(), limit: 1).first
    }
}
