import Foundation
import UserNotifications

/// Notification scheduler. Auto and custom reminders are independent toggles
/// that can run in parallel. Quiet hours apply to auto reminders only.
/// When an auto reminder collides with a custom one (same hh:mm), only the
/// custom one is delivered.
enum ReminderPlanner {

    static var messages: [String] {
        [
            String(localized: "Time for a couple of sips 💧"),
            String(localized: "A quick water break?"),
            String(localized: "Your body will thank you for a glass of water"),
            String(localized: "Time to top up your fluids"),
            String(localized: "One sip of water — and back to it 🚀"),
        ]
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func rescheduleAll() {
        Task { await reschedule() }
    }

    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        if SettingsStore.autoRemindersEnabled {
            await scheduleAuto(center)
        }
        if SettingsStore.manualRemindersEnabled {
            await scheduleManual(center)
        }
    }

    // MARK: Auto reminders

    /// Minute marks across the day for the selected auto schedule.
    /// Quiet hours are auto-only and applied here.
    static func autoMinuteMarks() -> [Int] {
        let marks: [Int]
        switch SettingsStore.autoSchedule {
        case .every2h:
            marks = Array(stride(from: SettingsStore.activeWindowStart,
                                 through: SettingsStore.activeWindowEnd, by: 120))
        case .meals:
            marks = SettingsStore.meals.map(\.minutesFromMidnight).sorted()
        case .custom:
            marks = Array(stride(from: SettingsStore.activeWindowStart,
                                 through: SettingsStore.activeWindowEnd,
                                 by: SettingsStore.customIntervalMinutes))
        }
        return marks.filter { !SettingsStore.isQuiet(minutes: $0) }
    }

    /// Does an enabled custom reminder fire at the same hh:mm on this date?
    /// Such auto slots are skipped — the custom reminder wins.
    private static func collidesWithManual(_ date: Date, calendar: Calendar) -> Bool {
        guard SettingsStore.manualRemindersEnabled else { return false }
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let isWeekend = comps.weekday == 1 || comps.weekday == 7
        return SettingsStore.manualReminders.contains { reminder in
            reminder.minutesFromMidnight == minutes && !(reminder.weekdaysOnly && isWeekend)
        }
    }

    /// Concrete auto-notification dates for the next 3 days.
    static func autoDates(from now: Date = .now) -> [Date] {
        let calendar = Calendar.current
        let marks = autoMinuteMarks()
        var result: [Date] = []
        for dayOffset in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset,
                                          to: calendar.startOfDay(for: now)) else { continue }
            for minutes in marks {
                if let date = calendar.date(byAdding: .minute, value: minutes, to: day),
                   date > now,
                   !collidesWithManual(date, calendar: calendar) {
                    result.append(date)
                }
            }
        }
        return result.sorted()
    }

    private static func scheduleAuto(_ center: UNUserNotificationCenter) async {
        let calendar = Calendar.current
        for (index, date) in autoDates().prefix(40).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Bottle of Water"
            content.body = messages[index % messages.count]
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "auto-\(index)",
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    // MARK: Custom (manual) reminders

    private static func scheduleManual(_ center: UNUserNotificationCenter) async {
        for reminder in SettingsStore.manualReminders {
            let content = UNMutableNotificationContent()
            content.title = "Bottle of Water"
            content.body = reminder.label.isEmpty
                ? String(localized: "Time for some water 💧")
                : reminder.label
            content.sound = .default

            let hour = reminder.minutesFromMidnight / 60
            let minute = reminder.minutesFromMidnight % 60

            if reminder.weekdaysOnly {
                for weekday in 2...6 { // Mon–Fri (1 = Sunday)
                    var components = DateComponents()
                    components.hour = hour
                    components.minute = minute
                    components.weekday = weekday
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let request = UNNotificationRequest(
                        identifier: "manual-\(reminder.id.uuidString)-\(weekday)",
                        content: content, trigger: trigger)
                    try? await center.add(request)
                }
            } else {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "manual-\(reminder.id.uuidString)",
                    content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    // MARK: Next reminder

    private static func nextManualDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var candidates: [Date] = []
        for reminder in SettingsStore.manualReminders {
            for dayOffset in 0...7 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset,
                                              to: calendar.startOfDay(for: now)),
                      let date = calendar.date(byAdding: .minute,
                                               value: reminder.minutesFromMidnight, to: day),
                      date > now else { continue }
                let weekday = calendar.component(.weekday, from: date)
                if reminder.weekdaysOnly && (weekday == 1 || weekday == 7) { continue }
                candidates.append(date)
                break
            }
        }
        return candidates.min()
    }

    static func nextReminderDate() -> Date? {
        var candidates: [Date] = []
        if SettingsStore.autoRemindersEnabled, let auto = autoDates().first {
            candidates.append(auto)
        }
        if SettingsStore.manualRemindersEnabled, let manual = nextManualDate() {
            candidates.append(manual)
        }
        return candidates.min()
    }
}
