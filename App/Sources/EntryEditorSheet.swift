import SwiftUI

/// Add a custom amount, add to a past day, or edit / delete an entry.
/// Uses its own keypad: no system keyboard, so no keyboard-avoidance relayout
/// of the screen underneath and no first-show keyboard lag.
struct EntryEditorSheet: View {
    var mode: EntrySheet
    var onAdded: (WaterEntry) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(WaterStore.self) private var store
    @Environment(Preferences.self) private var preferences

    @State private var digits = ""
    @State private var time = Date.now
    @State private var confirmDelete = false

    private var unit: VolumeUnit { preferences.unit }

    private var day: Date {
        switch mode {
        case .add(let day): day ?? .now
        case .edit(let entry): entry.timestamp
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var amountML: Int? {
        let normalized = digits.replacingOccurrences(of: decimalSeparator, with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        let ml = unit.milliliters(from: value)
        return (1...5000).contains(ml) ? ml : nil
    }

    private var decimalSeparator: String { Locale.current.decimalSeparator ?? "." }

    /// Time picker range: the chosen day, never in the future.
    private var timeRange: ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: day)
        let end = min(Calendar.current.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-60), .now)
        return start...max(start, end)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                amountDisplay

                HStack {
                    Label("Time", systemImage: "clock")
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    DatePicker("Time", selection: $time, in: timeRange, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassCard(radius: 16)

                Keypad(allowsDecimal: unit.allowsDecimal, decimalSeparator: decimalSeparator, text: $digits)

                Button(isEditing ? "Save" : "Add") {
                    Task { await save() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(amountML == nil)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(Theme.danger)
                        .accessibilityLabel(Text("Delete entry"))
                    }
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { await delete() }
                }
            } message: {
                Text("It will also be removed from Apple Health.")
            }
        }
        .presentationDetents([.height(580), .large])
        .presentationDragIndicator(.visible)
        .themedSheet()
        .onAppear(perform: setUp)
    }

    private var navigationTitle: LocalizedStringKey {
        switch mode {
        case .edit: "Edit Entry"
        case .add(let day):
            if let day, !Calendar.current.isDateInToday(day) { "Add to \(day.formatted(.dateTime.day().month()))" }
            else { "Add Water" }
        }
    }

    private var amountDisplay: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: digits.isEmpty ? "0" : digits)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(digits.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(verbatim: unit.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .animation(.snappy(duration: 0.15), value: digits)
            Text(amountML == nil && !digits.isEmpty ? "Up to 5 liters at a time" : " ")
                .font(.caption)
                .foregroundStyle(Theme.warn)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    private func setUp() {
        switch mode {
        case .edit(let entry):
            digits = VolumeFormat.number(entry.volumeML, unit: unit)
                .filter { $0.isNumber || String($0) == decimalSeparator }
            time = entry.timestamp
        case .add(let day):
            if let day, !Calendar.current.isDateInToday(day) {
                // Past day: default to noon of that day.
                time = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            } else {
                time = .now
            }
        }
    }

    private func save() async {
        guard let ml = amountML else { return }
        switch mode {
        case .edit(let entry):
            await store.update(entry, ml: ml, date: time)
        case .add:
            if let entry = await store.add(ml: ml, at: time, source: .app) {
                onAdded(entry)
            }
        }
        dismiss()
    }

    private func delete() async {
        if case .edit(let entry) = mode {
            await store.delete(entry)
        }
        dismiss()
    }
}

struct Keypad: View {
    var allowsDecimal: Bool
    var decimalSeparator: String
    @Binding var text: String

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "dot", "0", "back"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(keys, id: \.self) { key in
                switch key {
                case "dot":
                    if allowsDecimal {
                        keyButton(Text(verbatim: decimalSeparator)) { append(decimalSeparator) }
                    } else {
                        Color.clear.frame(height: 54)
                    }
                case "back":
                    keyButton(Image(systemName: "delete.left")) {
                        if !text.isEmpty { text.removeLast() }
                    }
                    .accessibilityLabel(Text("Delete"))
                default:
                    keyButton(Text(verbatim: key)) { append(key) }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: text)
    }

    private func keyButton(_ label: some View, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Theme.glassRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func append(_ character: String) {
        if character == decimalSeparator {
            guard !text.contains(decimalSeparator) else { return }
            text = (text.isEmpty ? "0" : text) + character
            return
        }
        if let separator = text.range(of: decimalSeparator) {
            guard text[separator.upperBound...].count < 1 else { return }
        } else {
            guard text.count < 4 else { return }
            if text == "0" { text = "" }
        }
        text += character
    }
}
