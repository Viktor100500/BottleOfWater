import Charts
import SwiftUI

struct HistoryScreen: View {
    @Environment(WaterStore.self) private var store
    @Environment(Preferences.self) private var preferences

    @State private var range: HistoryRange = DemoData.initialRange
    @State private var anchor = Date.now

    private var calendar: Calendar { .current }

    var body: some View {
        _ = store.revision
        let totals = store.dailyTotals()
        let interval = range.interval(containing: anchor)
        let now = Date.now
        let goal = preferences.goalML
        let buckets = HistoryMath.buckets(totals, interval: interval, component: range.bucket, now: now)
        let goalDays = HistoryMath.goalDays(totals, interval: interval, goal: goal, now: now)

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Period", selection: $range.animation()) {
                        ForEach(HistoryRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    chartCard(buckets: buckets, interval: interval, goal: goal)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                              spacing: 10) {
                        StatCard(value: VolumeFormat.string(HistoryMath.averageOnLoggedDays(totals, interval: interval),
                                                            unit: preferences.unit),
                                 label: "Daily average", symbol: "chart.line.uptrend.xyaxis", color: Theme.aqua)
                        StatCard(value: "\(goalDays.met)/\(goalDays.elapsed)",
                                 label: "Goal days", symbol: "checkmark.seal.fill", color: Theme.success)
                        StatCard(value: String(localized: "\(HistoryMath.currentStreak(totals, goal: goal, now: now)) d"),
                                 label: "Current streak", symbol: "flame.fill", color: Theme.warn)
                        StatCard(value: String(localized: "\(HistoryMath.bestStreak(totals, goal: goal)) d"),
                                 label: "Best streak", symbol: "trophy.fill", color: Theme.indigoLight)
                    }

                    if range == .week || range == .month {
                        dayList(totals: totals, interval: interval, goal: goal, now: now)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("History")
            .navigationDestination(for: Date.self) { day in
                DayDetailView(day: day)
            }
            .onChange(of: range) { anchor = .now }
        }
    }

    // MARK: Chart

    private func chartCard(buckets: [HistoryMath.Bucket], interval: DateInterval, goal: Int) -> some View {
        let unit = preferences.unit
        let canGoForward = interval.end <= .now
        return VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation { anchor = range.shift(anchor, by: -1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(Text("Previous period"))
                Spacer()
                Text(verbatim: title(for: interval))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    withAnimation { anchor = range.shift(anchor, by: 1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 32)
                }
                .disabled(!canGoForward)
                .foregroundStyle(canGoForward ? Theme.aqua : Theme.textTertiary.opacity(0.5))
                .accessibilityLabel(Text("Next period"))
            }
            .foregroundStyle(Theme.aqua)

            Chart {
                ForEach(buckets) { bucket in
                    BarMark(x: .value("Date", bucket.start, unit: range.bucket),
                            y: .value("Volume", unit.value(fromML: bucket.averageML)))
                        .foregroundStyle(bucket.averageML >= goal ? Theme.goalGradient : Theme.liquidGradient)
                        .cornerRadius(range == .month ? 3 : 6)
                }
                RuleMark(y: .value("Goal", unit.value(fromML: goal)))
                    .foregroundStyle(Theme.success.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Text("Goal")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Theme.bg.opacity(0.85), in: Capsule())
                    }
            }
            .chartXScale(domain: interval.start...interval.end)
            .chartYScale(domain: 0...max(unit.value(fromML: goal) * 1.25,
                                         unit.value(fromML: buckets.map(\.averageML).max() ?? 0) * 1.1))
            .chartXAxis { xAxis }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(Theme.stroke)
                    AxisValueLabel().foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 180)
            .accessibilityLabel(Text("Water per day"))

            if range == .halfYear || range == .year {
                Text("Bars show the daily average for each \(range == .year ? String(localized: "month") : String(localized: "week")).")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .glassCard(radius: 24)
    }

    private var xAxis: some AxisContent {
        AxisMarks(values: axisValues) { _ in
            AxisValueLabel(format: axisFormat, centered: true)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var axisValues: AxisMarkValues {
        switch range {
        case .week: .stride(by: .day)
        case .month: .stride(by: .day, count: 7)
        case .halfYear, .year: .stride(by: .month)
        }
    }

    private var axisFormat: Date.FormatStyle {
        switch range {
        case .week: .dateTime.weekday(.narrow)
        case .month: .dateTime.day()
        case .halfYear: .dateTime.month(.abbreviated)
        case .year: .dateTime.month(.narrow)
        }
    }

    private func title(for interval: DateInterval) -> String {
        let last = interval.end.addingTimeInterval(-1)
        switch range {
        case .week:
            return (interval.start..<last).formatted(.interval.day().month(.abbreviated).year())
        case .month:
            return interval.start.formatted(.dateTime.month(.wide).year())
        case .halfYear:
            return (interval.start..<last).formatted(.interval.month(.abbreviated).year())
        case .year:
            return interval.start.formatted(.dateTime.year())
        }
    }

    // MARK: Days

    private func dayList(totals: [Date: Int], interval: DateInterval, goal: Int, now: Date) -> some View {
        let days = HistoryMath.elapsedDays(in: interval, now: now).reversed()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Days")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 6)
            VStack(spacing: 0) {
                ForEach(Array(days), id: \.self) { day in
                    NavigationLink(value: day) {
                        DayRow(day: day, totalML: totals[day] ?? 0, goalML: goal, unit: preferences.unit)
                    }
                    .buttonStyle(.plain)
                    if day != days.last {
                        Divider().overlay(Theme.stroke).padding(.leading, 16)
                    }
                }
            }
            .glassCard()
        }
    }
}

struct StatCard: View {
    var value: String
    var label: LocalizedStringKey
    var symbol: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(verbatim: value)
                .font(.rounded(.title3))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(radius: 20)
        .accessibilityElement(children: .combine)
    }
}

struct DayRow: View {
    var day: Date
    var totalML: Int
    var goalML: Int
    var unit: VolumeUnit

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(day, format: .dateTime.weekday(.wide).day().month())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                ProgressView(value: ProgressMath.fraction(total: totalML, goal: goalML))
                    .tint(totalML >= goalML ? Theme.success : Theme.aqua)
            }
            Text(totalML > 0 ? VolumeFormat.string(totalML, unit: unit) : "—")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(totalML > 0 ? Theme.textPrimary : Theme.textTertiary)
                .frame(minWidth: 70, alignment: .trailing)
            Image(systemName: totalML >= goalML ? "checkmark.circle.fill" : "chevron.right")
                .font(totalML >= goalML ? .body : .caption.weight(.bold))
                .foregroundStyle(totalML >= goalML ? Theme.success : Theme.textTertiary)
                .frame(width: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// One day's entries: edit, delete, add forgotten drinks.
struct DayDetailView: View {
    var day: Date

    @Environment(WaterStore.self) private var store
    @Environment(Preferences.self) private var preferences
    @State private var sheet: EntrySheet?

    var body: some View {
        _ = store.revision
        let entries = store.entries(on: day)
        let total = entries.reduce(0) { $0 + $1.volumeML }

        return ScrollView {
            VStack(spacing: 18) {
                LiquidGauge(totalML: total, goalML: preferences.goalML, unit: preferences.unit,
                            size: CGSize(width: 150, height: 176))
                    .padding(.top, 8)
                TodayLog(entries: entries, unit: preferences.unit, title: "Entries",
                         emptyHint: "Forgot to log something? Tap + to add it.") { entry in
                    sheet = .edit(entry)
                } onDelete: { entry in
                    Task { await store.delete(entry) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle(day.formatted(.dateTime.weekday(.abbreviated).day().month()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sheet = .add(day: day)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("Add entry"))
            }
        }
        .sheet(item: $sheet) { sheet in
            EntryEditorSheet(mode: sheet)
        }
    }
}
