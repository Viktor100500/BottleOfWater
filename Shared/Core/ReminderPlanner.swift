import Foundation

/// Pure reminder planning: settings + today's state → concrete fire dates.
/// Side effects (UNUserNotificationCenter) live in `ReminderScheduler`.
enum ReminderPlanner {
    struct Context: Sendable {
        var now: Date
        var lastLog: Date?
        var todayTotalML: Int
        var goalML: Int
    }

    /// How close before a fixed-time reminder a drink makes it redundant.
    static let recentWindow: TimeInterval = 30 * 60

    static func plan(_ settings: ReminderSettings,
                     context: Context,
                     calendar: Calendar = .current,
                     horizonDays: Int = 7,
                     limit: Int = 60) -> [Date] {
        guard settings.isEnabled else { return [] }
        let today = calendar.startOfDay(for: context.now)
        let goalReachedToday = context.goalML > 0 && context.todayTotalML >= context.goalML
        var result: [Date] = []

        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let isToday = offset == 0
            if isToday && settings.skipWhenGoalReached && goalReachedToday { continue }

            switch settings.mode {
            case .interval:
                result += intervalSlots(settings, day: day, isToday: isToday,
                                        context: context, calendar: calendar)
            case .times:
                result += timeSlots(settings, day: day, isToday: isToday,
                                    context: context, calendar: calendar)
            }
        }

        return Array(Set(result).filter { $0 > context.now }.sorted().prefix(limit))
    }

    private static func intervalSlots(_ s: ReminderSettings, day: Date, isToday: Bool,
                                      context: Context, calendar: Calendar) -> [Date] {
        let interval = max(ReminderSettings.intervalRange.lowerBound, s.intervalMinutes)
        guard s.windowEnd > s.windowStart,
              let start = calendar.date(byAdding: .minute, value: s.windowStart, to: day),
              let end = calendar.date(byAdding: .minute, value: s.windowEnd, to: day)
        else { return [] }

        var cursor = start
        // The interval restarts from the last drink: no nagging right after a glass.
        if isToday, s.skipIfRecentlyLogged, let last = context.lastLog,
           let afterLast = calendar.date(byAdding: .minute, value: interval, to: last),
           afterLast > cursor {
            cursor = afterLast
        }

        var slots: [Date] = []
        while cursor <= end {
            slots.append(cursor)
            guard let next = calendar.date(byAdding: .minute, value: interval, to: cursor) else { break }
            cursor = next
        }
        return slots
    }

    private static func timeSlots(_ s: ReminderSettings, day: Date, isToday: Bool,
                                  context: Context, calendar: Calendar) -> [Date] {
        let weekday = calendar.component(.weekday, from: day)
        return s.times.compactMap { time in
            guard time.weekdays.contains(weekday),
                  let date = calendar.date(byAdding: .minute, value: time.minutes, to: day)
            else { return nil }
            if isToday, s.skipIfRecentlyLogged, let last = context.lastLog,
               last <= date, date.timeIntervalSince(last) < recentWindow {
                return nil
            }
            return date
        }
    }
}
