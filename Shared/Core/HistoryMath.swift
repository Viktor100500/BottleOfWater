import Foundation

enum HistoryRange: String, CaseIterable, Identifiable, Sendable {
    case week, month, halfYear, year

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .halfYear: "6 Months"
        case .year: "Year"
        }
    }

    /// Bucket size on the chart.
    var bucket: Calendar.Component {
        switch self {
        case .week, .month: .day
        case .halfYear: .weekOfYear
        case .year: .month
        }
    }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)!
        case .month:
            return calendar.dateInterval(of: .month, for: date)!
        case .halfYear:
            let month = calendar.dateInterval(of: .month, for: date)!
            let start = calendar.date(byAdding: .month, value: -5, to: month.start)!
            return DateInterval(start: start, end: month.end)
        case .year:
            return calendar.dateInterval(of: .year, for: date)!
        }
    }

    func shift(_ date: Date, by direction: Int, calendar: Calendar = .current) -> Date {
        switch self {
        case .week: calendar.date(byAdding: .weekOfYear, value: direction, to: date)!
        case .month: calendar.date(byAdding: .month, value: direction, to: date)!
        case .halfYear: calendar.date(byAdding: .month, value: 6 * direction, to: date)!
        case .year: calendar.date(byAdding: .year, value: direction, to: date)!
        }
    }
}

/// Pure statistics over per-day totals (keys are start-of-day dates).
enum HistoryMath {
    struct Bucket: Identifiable, Equatable, Sendable {
        var start: Date
        var totalML: Int
        /// Average per elapsed day inside the bucket (equals total for day buckets).
        var averageML: Int
        var id: Date { start }
    }

    static func dailyTotals(_ entries: [(date: Date, ml: Int)],
                            calendar: Calendar = .current) -> [Date: Int] {
        entries.reduce(into: [:]) { result, entry in
            result[calendar.startOfDay(for: entry.date), default: 0] += entry.ml
        }
    }

    /// Days of `interval` that have already started (≤ today).
    static func elapsedDays(in interval: DateInterval, now: Date,
                            calendar: Calendar = .current) -> [Date] {
        var days: [Date] = []
        var day = calendar.startOfDay(for: interval.start)
        let today = calendar.startOfDay(for: now)
        while day < interval.end && day <= today {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }

    static func buckets(_ totals: [Date: Int], interval: DateInterval, component: Calendar.Component,
                        now: Date, calendar: Calendar = .current) -> [Bucket] {
        let days = elapsedDays(in: interval, now: now, calendar: calendar)
        var grouped: [Date: (total: Int, days: Int)] = [:]
        for day in days {
            let key = calendar.dateInterval(of: component, for: day)?.start ?? day
            let current = grouped[key] ?? (0, 0)
            grouped[key] = (current.total + (totals[day] ?? 0), current.days + 1)
        }
        return grouped
            .map { Bucket(start: $0.key, totalML: $0.value.total,
                          averageML: $0.value.days > 0 ? $0.value.total / $0.value.days : 0) }
            .sorted { $0.start < $1.start }
    }

    /// Average over days that have at least one entry.
    static func averageOnLoggedDays(_ totals: [Date: Int], interval: DateInterval) -> Int {
        let values = totals.filter { interval.contains($0.key) && $0.value > 0 }.map(\.value)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    static func goalDays(_ totals: [Date: Int], interval: DateInterval, goal: Int,
                         now: Date, calendar: Calendar = .current) -> (met: Int, elapsed: Int) {
        let days = elapsedDays(in: interval, now: now, calendar: calendar)
        let met = days.filter { (totals[$0] ?? 0) >= goal }.count
        return (met, days.count)
    }

    /// Consecutive goal days ending today — or yesterday, while today is still in progress.
    static func currentStreak(_ totals: [Date: Int], goal: Int, now: Date,
                              calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: now)
        if (totals[day] ?? 0) < goal {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while (totals[day] ?? 0) >= goal, goal > 0 {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    static func bestStreak(_ totals: [Date: Int], goal: Int, calendar: Calendar = .current) -> Int {
        guard goal > 0 else { return 0 }
        let metDays = totals.filter { $0.value >= goal }.keys.sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in metDays {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }
}
