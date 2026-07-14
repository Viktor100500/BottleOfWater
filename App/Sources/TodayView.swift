import SwiftUI
import SwiftData

/// Today's log. Every entry is synced with Apple Health.
struct TodayView: View {
    @Query private var todayEntries: [WaterEntry]
    @AppStorage("goalML", store: BottleShared.defaults) private var goalML = 2000

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        _todayEntries = Query(
            filter: #Predicate<WaterEntry> { $0.timestamp >= start },
            sort: [SortDescriptor(\WaterEntry.timestamp, order: .reverse)]
        )
    }

    private var total: Int { todayEntries.reduce(0) { $0 + $1.volumeML } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 18)

            HStack(spacing: 6) {
                Image(systemName: "heart.fill").foregroundStyle(.pink).font(.caption)
                Text("Entries sync to Apple Health instantly")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 6)
            .padding(.bottom, 16)

            if todayEntries.isEmpty {
                emptyState
            } else {
                entriesList
            }

            Spacer(minLength: 0)

            totalBar
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text(verbatim: "💧")
                .font(.system(size: 44))
            Text("No entries yet")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Add your first glass on the home screen\nor right from the widget")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .glassCard()
    }

    private var entriesList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(todayEntries) { entry in
                    row(entry)
                    if entry.id != todayEntries.last?.id {
                        Divider().overlay(Theme.stroke.opacity(0.6))
                    }
                }
            }
            .glassCard()
        }
    }

    private func row(_ entry: WaterEntry) -> some View {
        HStack(spacing: 13) {
            Text(verbatim: "💧")
                .font(.system(size: 16))
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(colors: [Theme.aqua.opacity(0.2), Theme.indigo.opacity(0.2)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1))

            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(.body.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)

            sourceTag(entry.source)

            Spacer()

            Text(VolumeFormatter.string(ml: entry.volumeML))
                .font(.body.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)

            Button {
                Task { await HydrationService.shared.delete(entry) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.danger)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func sourceTag(_ source: EntrySource) -> some View {
        let isWidget = source == .widget
        let color = isWidget ? Theme.aqua : Color(red: 0.655, green: 0.545, blue: 0.980)
        return Text(source.label.uppercased())
            .font(.system(size: 9.5, weight: .bold))
            .kerning(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
    }

    private var totalBar: some View {
        HStack {
            Text("Total today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(verbatim: "\(VolumeFormatter.string(ml: total)) · \(Int((Double(total) / Double(max(1, goalML)) * 100).rounded()))%")
                .font(.title3.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Theme.glassRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Theme.stroke, lineWidth: 1))
    }
}
