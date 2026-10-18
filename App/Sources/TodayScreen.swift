import SwiftUI

enum EntrySheet: Identifiable {
    case add(day: Date?)
    case edit(WaterEntry)

    var id: String {
        switch self {
        case .add(let day): "add-\(day?.timeIntervalSince1970 ?? 0)"
        case .edit(let entry): "edit-\(entry.id)"
        }
    }
}

struct TodayScreen: View {
    @Environment(WaterStore.self) private var store
    @Environment(Preferences.self) private var preferences

    @State private var sheet: EntrySheet?
    @State private var toast: Toast?
    @State private var logCount = 0
    @State private var goalCelebration = 0

    private var entries: [WaterEntry] {
        _ = store.revision
        return store.entries(on: .now)
    }

    var body: some View {
        let entries = self.entries
        let total = entries.reduce(0) { $0 + $1.volumeML }

        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    LiquidGauge(totalML: total, goalML: preferences.goalML, unit: preferences.unit)
                        .padding(.top, 4)

                    remainingLine(total: total)

                    presetGrid

                    TodayLog(entries: entries, unit: preferences.unit) { entry in
                        sheet = .edit(entry)
                    } onDelete: { entry in
                        Task { await store.delete(entry) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 90)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                if let toast {
                    ToastView(toast: toast) {
                        Task { await undo(toast) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
                }
            }
            .background(Theme.background)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sheet = .add(day: nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Add custom amount"))
                }
            }
            .sheet(item: $sheet) { sheet in
                EntryEditorSheet(mode: sheet) { entry in
                    showToast(for: entry)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: logCount)
        .sensoryFeedback(.success, trigger: goalCelebration)
        .onChange(of: total) { old, new in
            if old < preferences.goalML && new >= preferences.goalML { goalCelebration += 1 }
        }
    }

    private func remainingLine(total: Int) -> some View {
        let left = preferences.goalML - total
        return Group {
            if left > 0 {
                Text("\(VolumeFormat.string(left, unit: preferences.unit)) to go")
            } else {
                Text("Daily goal done. Nice work!")
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
        .contentTransition(.numericText())
    }

    private var presetGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(preferences.presets) { preset in
                Button {
                    Task { await log(preset.volumeML) }
                } label: {
                    PresetTile(emoji: preset.emoji,
                               value: VolumeFormat.number(preset.volumeML, unit: preferences.unit),
                               caption: preset.displayName)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text("Add \(VolumeFormat.string(preset.volumeML, unit: preferences.unit)), \(preset.displayName)"))
            }
            Button {
                sheet = .add(day: nil)
            } label: {
                PresetTile(emoji: nil, value: String(localized: "Other"), caption: String(localized: "amount"))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(Text("Add custom amount"))
        }
    }

    private func log(_ ml: Int) async {
        logCount += 1
        if let entry = await store.add(ml: ml, source: .app) {
            showToast(for: entry)
        }
    }

    private func showToast(for entry: WaterEntry) {
        let new = Toast(entryID: entry.id,
                        text: String(localized: "Added \(VolumeFormat.string(entry.volumeML, unit: preferences.unit))"))
        withAnimation(.spring(duration: 0.35)) { toast = new }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if toast?.id == new.id {
                withAnimation(.easeOut) { toast = nil }
            }
        }
    }

    private func undo(_ toast: Toast) async {
        withAnimation { self.toast = nil }
        guard let entry = store.entry(id: toast.entryID) else { return }
        await store.delete(entry)
    }
}

struct PresetTile: View {
    var emoji: String?
    var value: String
    var caption: String

    var body: some View {
        VStack(spacing: 3) {
            Group {
                if let emoji {
                    Text(verbatim: emoji)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.aqua)
                }
            }
            .font(.title3)
            Text(verbatim: value)
                .font(.rounded(.headline))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(verbatim: caption)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(.vertical, 6)
        .background(LinearGradient(colors: [Theme.glassRaised, Theme.glass], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Entries of one day, newest first. Tap to edit, long-press for more.
struct TodayLog: View {
    var entries: [WaterEntry]
    var unit: VolumeUnit
    var title: LocalizedStringKey = "Today's log"
    var emptyHint: LocalizedStringKey = "Tap a preset above, or use the widget."
    var onEdit: (WaterEntry) -> Void
    var onDelete: (WaterEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !entries.isEmpty {
                    Text("\(entries.count) drinks")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            if entries.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "drop")
                        .font(.title2)
                        .foregroundStyle(Theme.aqua)
                    Text("Nothing logged yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(emptyHint)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .glassCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        Button {
                            onEdit(entry)
                        } label: {
                            EntryRow(entry: entry, unit: unit)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { onEdit(entry) }
                            Button("Delete", systemImage: "trash", role: .destructive) { onDelete(entry) }
                        }
                        if entry.id != entries.last?.id {
                            Divider().overlay(Theme.stroke).padding(.leading, 60)
                        }
                    }
                }
                .glassCard()
            }
        }
    }
}

struct EntryRow: View {
    var entry: WaterEntry
    var unit: VolumeUnit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.source.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.aqua)
                .frame(width: 34, height: 34)
                .background(Theme.aqua.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel(Text(entry.source.label))
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.timestamp, format: .dateTime.hour().minute())
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(entry.source.label)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Text(VolumeFormat.string(entry.volumeML, unit: unit))
                .font(.rounded(.body))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

struct Toast: Equatable {
    var id = UUID()
    var entryID: UUID
    var text: String
}

struct ToastView: View {
    var toast: Toast
    var onUndo: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.success)
            Text(verbatim: toast.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.aqua)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}
