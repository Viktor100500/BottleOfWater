import SwiftUI

struct PresetsEditor: View {
    @Environment(Preferences.self) private var preferences
    @State private var editing: VolumePreset?
    @State private var isAdding = false

    var body: some View {
        @Bindable var preferences = preferences

        List {
            Section {
                ForEach(preferences.presets) { preset in
                    Button {
                        editing = preset
                    } label: {
                        HStack(spacing: 12) {
                            Text(verbatim: preset.emoji).font(.title3)
                            Text(verbatim: preset.name).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(preferences.format(preset.volumeML))
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(Theme.aqua)
                        }
                    }
                }
                .onDelete { offsets in
                    guard preferences.presets.count - offsets.count >= 1 else { return }
                    preferences.presets.remove(atOffsets: offsets)
                }
                .onMove { preferences.presets.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Up to \(VolumePreset.maxCount) presets. Swipe to delete, tap Edit to reorder.")
            }

            Section {
                Button {
                    isAdding = true
                } label: {
                    Label("Add preset", systemImage: "plus.circle.fill")
                }
                .disabled(preferences.presets.count >= VolumePreset.maxCount)

                Button("Reset to defaults", role: .destructive) {
                    preferences.presets = VolumePreset.defaults(for: preferences.unit)
                }
            }
        }
        .themedList()
        .navigationTitle("Presets")
        .toolbar { EditButton() }
        .sheet(item: $editing) { preset in
            PresetEditorSheet(preset: preset) { updated in
                if let index = preferences.presets.firstIndex(where: { $0.id == updated.id }) {
                    preferences.presets[index] = updated
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            PresetEditorSheet(preset: nil) { preferences.presets.append($0) }
        }
    }
}

struct PresetEditorSheet: View {
    var preset: VolumePreset?
    var onSave: (VolumePreset) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(Preferences.self) private var preferences
    @State private var emoji = "💧"
    @State private var name = ""
    @State private var amount: Double?

    private var volumeML: Int? {
        guard let amount, amount > 0 else { return nil }
        let ml = preferences.unit.milliliters(from: amount)
        return (1...5000).contains(ml) ? ml : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Emoji", text: $emoji)
                        .onChange(of: emoji) { _, new in
                            if new.count > 1 { emoji = String(new.suffix(1)) }
                        }
                    TextField("Name", text: $name, prompt: Text("e.g. Mug"))
                    HStack {
                        TextField("Amount", value: $amount, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(preferences.unit.allowsDecimal ? .decimalPad : .numberPad)
                        Text(verbatim: preferences.unit.symbol)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .themedList()
            .navigationTitle(preset == nil ? "New Preset" : "Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let volumeML else { return }
                        var result = preset ?? VolumePreset(volumeML: volumeML, name: "", emoji: "💧")
                        result.volumeML = volumeML
                        result.emoji = emoji.isEmpty ? "💧" : emoji
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        result.name = trimmed.isEmpty ? String(localized: "Custom") : trimmed
                        onSave(result)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(volumeML == nil)
                }
            }
        }
        .presentationDetents([.medium])
        .themedSheet()
        .onAppear {
            if let preset {
                emoji = preset.emoji
                name = preset.name
                amount = (preferences.unit.value(fromML: preset.volumeML) * 10).rounded() / 10
            }
        }
    }
}
