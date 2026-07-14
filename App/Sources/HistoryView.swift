import SwiftUI
import SwiftData
import Charts

enum HistoryPeriod: CaseIterable, Identifiable {
    case day, week, month, threeMonths, sixMonths, year
    var id: Self { self }

    var label: String {
        switch self {
        case .day: return String(localized: "D")
        case .week: return String(localized: "7D")
        case .month: return String(localized: "M")
        case .threeMonths: return String(localized: "3M")
        case .sixMonths: return String(localized: "6M")
        case .year: return String(localized: "Y")
        }
    }

    var calendarStep: (Calendar.Component, Int) {
        switch self {
        case .day: return (.day, 1)
        case .week: return (.weekOfYear, 1)
        case .month: return (.month, 1)
        case .threeMonths: return (.month, 3)
        case .sixMonths: return (.month, 6)
        case .year: return (.year, 1)
        }
    }

    var bucketUnit: Calendar.Component {
        switch self {
        case .day: return .hour
        case .week, .month: return .day
        case .threeMonths, .sixMonths: return .weekOfYear
        case .year: return .month
        }
    }
}

struct HistoryView: View {
    // Reactive: any change to entries re-renders this screen instantly
    @Query(sort: \WaterEntry.timestamp) private var allEntries: [WaterEntry]

    @State private var period: HistoryPeriod = .week
    @State private var anchor: Date = .now
    @AppStorage("goalML", store: BottleShared.defaults) private var goalML = 2000

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 18)
                .padding(.bottom, 14)

            periodPicker
                .padding(.bottom, 14)

            chartCard

            Text("TRENDS")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 18)
                .padding(.bottom, 8)

            trends

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Range & data

    private var range: DateInterval {
        switch period {
        case .day:
            let start = calendar.startOfDay(for: anchor)
            return DateInterval(start: start, duration: 86400)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: anchor)
                ?? DateInterval(start: anchor, duration: 7 * 86400)
        case .month:
            return calendar.dateInterval(of: .month, for: anchor)
                ?? DateInterval(start: anchor, duration: 30 * 86400)
        case .threeMonths, .sixMonths:
            let months = period == .threeMonths ? 3 : 6
            let thisMonth = calendar.dateInterval(of: .month, for: anchor)!
            let start = calendar.date(byAdding: .month, value: -(months - 1), to: thisMonth.start)!
            return DateInterval(start: start, end: thisMonth.end)
        case .year:
            return calendar.dateInterval(of: .year, for: anchor)
                ?? DateInterval(start: anchor, duration: 365 * 86400)
        }
    }

    private var entries: [WaterEntry] {
        let from = range.start, to = range.end
        return allEntries.filter { $0.timestamp >= from && $0.timestamp < to }
    }

    private struct Bucket: Identifiable {
        var id: Date { date }
        var date: Date
        var totalML: Int
    }

    private func buckets(for entries: [WaterEntry]) -> [Bucket] {
        var dict: [Date: Int] = [:]
        for e in entries {
            let key: Date
            if period == .threeMonths || period == .sixMonths {
                key = calendar.dateInterval(of: .weekOfYear, for: e.timestamp)?.start ?? e.timestamp
            } else {
                key = calendar.dateInterval(of: period.bucketUnit, for: e.timestamp)?.start ?? e.timestamp
            }
            dict[key, default: 0] += e.volumeML
        }
        return dict.map { Bucket(date: $0.key, totalML: $0.value) }.sorted { $0.date < $1.date }
    }

    private var loggedDays: Set<Date> {
        Set(entries.map { calendar.startOfDay(for: $0.timestamp) })
    }

    private var daysInPeriod: Int {
        let end = min(range.end, Date())
        guard end > range.start else { return 0 }
        return calendar.dateComponents([.day], from: range.start, to: end).day.map { $0 + (calendar.startOfDay(for: end) == end ? 0 : 1) } ?? 0
    }

    private var streak: Int {
        let today = calendar.startOfDay(for: .now)
        let lastDay = min(today, calendar.startOfDay(for: range.end.addingTimeInterval(-1)))
        var day = lastDay
        if !loggedDays.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while day >= range.start, loggedDays.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    private var totalInRange: Int { entries.reduce(0) { $0 + $1.volumeML } }

    private var averageDaily: Int {
        guard !loggedDays.isEmpty else { return 0 }
        return totalInRange / loggedDays.count
    }

    private var canGoForward: Bool { range.end <= Date() }

    // MARK: UI

    private var periodPicker: some View {
        HStack(spacing: 6) {
            ForEach(HistoryPeriod.allCases) { p in
                Button {
                    period = p
                    anchor = .now
                } label: {
                    Text(p.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(period == p ? Color(red: 0.016, green: 0.071, blue: 0.11) : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if period == p {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.primaryGradient)
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Theme.stroke, lineWidth: 1)
                            }
                        }
                }
            }
        }
    }

    private var rangeTitle: String {
        let f = DateFormatter()
        f.locale = Locale.current
        switch period {
        case .day:
            f.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
            return f.string(from: range.start)
        case .week:
            f.setLocalizedDateFormatFromTemplate("d MMM")
            let f2 = DateFormatter(); f2.locale = f.locale
            f2.setLocalizedDateFormatFromTemplate("d MMM yyyy")
            return "\(f.string(from: range.start)) – \(f2.string(from: range.end.addingTimeInterval(-1)))"
        case .month:
            f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
            return f.string(from: range.start).capitalized
        case .threeMonths, .sixMonths:
            f.setLocalizedDateFormatFromTemplate("LLL")
            let f2 = DateFormatter(); f2.locale = f.locale
            f2.setLocalizedDateFormatFromTemplate("LLL yyyy")
            return "\(f.string(from: range.start)) – \(f2.string(from: range.end.addingTimeInterval(-1)))"
        case .year:
            f.setLocalizedDateFormatFromTemplate("yyyy")
            return f.string(from: range.start)
        }
    }

    private var chartCard: some View {
        let data = buckets(for: entries)
        return VStack(spacing: 12) {
            HStack {
                Button { move(-1) } label: {
                    Image(systemName: "chevron.left").foregroundStyle(Theme.aqua)
                }
                Spacer()
                Text(rangeTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { move(1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(canGoForward ? Theme.aqua : Theme.textTertiary)
                }
                .disabled(!canGoForward)
            }

            if data.isEmpty {
                Text("No entries for this period")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(data) { bucket in
                    BarMark(
                        x: .value("Date", bucket.date, unit: period.bucketUnit),
                        y: .value("Volume", bucket.totalML)
                    )
                    .foregroundStyle(Theme.liquidGradient)
                    .cornerRadius(5)
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) {
                        AxisGridLine().foregroundStyle(Theme.stroke)
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks {
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 150)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(VolumeFormatter.string(ml: totalInRange))
                        .font(.headline.weight(.heavy)).monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text("total for period")
                        .font(.caption2).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(loggedDays.count) of \(max(daysInPeriod, loggedDays.count))")
                        .font(.headline.weight(.heavy)).monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text("days logged")
                        .font(.caption2).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .glassCard(radius: 24)
    }

    private var trends: some View {
        HStack(spacing: 10) {
            trendCard(value: "\(streak)", unit: String(localized: "d"),
                      label: String(localized: "Streak"),
                      sub: String(localized: "in this period"), color: Theme.warn)
            trendCard(value: "\(loggedDays.count)",
                      unit: String(localized: "of \(max(daysInPeriod, loggedDays.count))"),
                      label: String(localized: "Days logged"),
                      sub: String(localized: "in this period"), color: Theme.aqua)
            trendCard(value: VolumeFormatter.formatted(averageDaily),
                      unit: String(localized: "ml"),
                      label: String(localized: "Daily avg"),
                      sub: String(localized: "on logged days"), color: Theme.success)
        }
    }

    private func trendCard(value: String, unit: String, label: String, sub: String, color: Color) -> some View {
        VStack(spacing: 3) {
            (Text(value).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(color)
             + Text(verbatim: " \(unit)").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.textSecondary))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(sub)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassCard(radius: 20)
    }

    private func move(_ direction: Int) {
        let (component, value) = period.calendarStep
        if let newAnchor = calendar.date(byAdding: component, value: value * direction, to: anchor) {
            anchor = newAnchor
        }
    }
}
