import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var goalML = SettingsStore.goalML
    @State private var useOunces = SettingsStore.useOunces
    @State private var presets = SettingsStore.presets
    @State private var widgetLogging = SettingsStore.widgetLoggingEnabled
    @State private var button1ML = SettingsStore.widgetButton1ML
    @State private var button2ML = SettingsStore.widgetButton2ML

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Bottle of Water v\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {

                Section("Daily goal") {
                    Stepper(value: $goalML, in: 500...6000, step: 100) {
                        HStack {
                            Text("Goal")
                            Spacer()
                            Text(VolumeFormatter.string(ml: goalML, ounces: useOunces))
                                .fontWeight(.heavy).monospacedDigit()
                                .foregroundStyle(Theme.aqua)
                        }
                    }
                    .listRowBackground(Theme.glass)
                }

                Section("Units") {
                    Toggle("Show ounces (oz)", isOn: $useOunces)
                        .listRowBackground(Theme.glass)
                }

                Section {
                    NavigationLink {
                        PresetsEditorView(presets: $presets)
                    } label: {
                        HStack {
                            Text("Volume presets")
                            Spacer()
                            Text(presets.map { "\($0.volumeML)" }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    .listRowBackground(Theme.glass)
                } header: {
                    Text("Quick add")
                }

                Section("Widget") {
                    Toggle("Log buttons on the widget", isOn: $widgetLogging)
                        .listRowBackground(Theme.glass)
                    Picker("Button 1", selection: $button1ML) {
                        ForEach(presets) { p in
                            Text(verbatim: "\(p.volumeML) — \(p.name)").tag(p.volumeML)
                        }
                    }
                    .listRowBackground(Theme.glass)
                    Picker("Button 2", selection: $button2ML) {
                        ForEach(presets) { p in
                            Text(verbatim: "\(p.volumeML) — \(p.name)").tag(p.volumeML)
                        }
                    }
                    .listRowBackground(Theme.glass)
                }

                Section("Help & support") {
                    NavigationLink("Help") { HelpView() }
                        .listRowBackground(Theme.glass)
                    Link("Send feedback", destination: URL(string: "mailto:support@bottleofwater.app?subject=Bottle%20of%20Water%20Feedback")!)
                        .listRowBackground(Theme.glass)
                    Link("Rate Bottle of Water", destination: URL(string: "https://apps.apple.com")!)
                        .listRowBackground(Theme.glass)
                    NavigationLink("Changelog") { ChangelogView() }
                        .listRowBackground(Theme.glass)
                }

                Section {
                    Text(verbatim: version)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }

                Section("About") {
                    Text("Bottle of Water helps you drink regularly: quick logging, live progress, widgets and Apple Health sync. Nothing extra.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .listRowBackground(Theme.glass)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.aqua)
        .onChange(of: goalML) { persist() }
        .onChange(of: useOunces) { persist() }
        .onChange(of: presets) { persistPresets() }
        .onChange(of: widgetLogging) { persist() }
        .onChange(of: button1ML) { persist() }
        .onChange(of: button2ML) { persist() }
    }

    private func persist() {
        SettingsStore.goalML = goalML
        SettingsStore.useOunces = useOunces
        SettingsStore.widgetLoggingEnabled = widgetLogging
        SettingsStore.widgetButton1ML = button1ML
        SettingsStore.widgetButton2ML = button2ML
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func persistPresets() {
        SettingsStore.presets = presets
        // If a preset used by a widget button was removed, fall back to an existing one
        if !presets.contains(where: { $0.volumeML == button1ML }) {
            button1ML = presets.first?.volumeML ?? 200
        }
        if !presets.contains(where: { $0.volumeML == button2ML }) {
            button2ML = presets.last?.volumeML ?? 330
        }
        persist()
    }
}

// MARK: - Presets editor (fix #4)

struct PresetsEditorView: View {
    @Binding var presets: [VolumePreset]
    @State private var showAdd = false

    var body: some View {
        Form {
            Section {
                ForEach(presets) { preset in
                    HStack {
                        Text(preset.emoji)
                        Text(preset.name).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(VolumeFormatter.string(ml: preset.volumeML, ounces: false))
                            .fontWeight(.bold).monospacedDigit()
                            .foregroundStyle(Theme.aqua)
                    }
                    .listRowBackground(Theme.glass)
                }
                .onDelete { offsets in
                    if presets.count > 1 { presets.remove(atOffsets: offsets) }
                }
                .onMove { presets.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("1 to 9 presets. Swipe to delete; drag to reorder.")
            }

            Section {
                Button {
                    showAdd = true
                } label: {
                    Label("Add preset", systemImage: "plus.circle.fill")
                        .foregroundStyle(Theme.aqua)
                }
                .disabled(presets.count >= 9)
                .listRowBackground(Theme.glass)

                Button("Reset to defaults", role: .destructive) {
                    presets = VolumePreset.defaults
                }
                .listRowBackground(Theme.glass)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Presets")
        .toolbar { EditButton() }
        .sheet(isPresented: $showAdd) {
            NewPresetSheet { presets.append($0) }
                .presentationDetents([.medium])
        }
    }
}

struct NewPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (VolumePreset) -> Void

    @State private var emoji = "💧"
    @State private var name = ""
    @State private var volumeText = ""

    private var volume: Int? {
        guard let v = Int(volumeText), v > 0, v <= 5000 else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Emoji", text: $emoji)
                    .listRowBackground(Theme.glass)
                TextField("Name (e.g. Mug)", text: $name)
                    .listRowBackground(Theme.glass)
                TextField("Volume, ml", text: $volumeText)
                    .keyboardType(.numberPad)
                    .listRowBackground(Theme.glass)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("New preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(VolumePreset(
                            volumeML: volume ?? 250,
                            name: name.isEmpty ? String(localized: "Custom volume") : name,
                            emoji: emoji.isEmpty ? "💧" : String(emoji.prefix(2))))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(volume == nil)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.aqua)
    }
}

// MARK: - Help & changelog

struct HelpView: View {
    var body: some View {
        List {
            helpRow(String(localized: "How do I log water?"),
                    String(localized: "Tap a preset on the home screen or enter a custom volume. The entry lands in Apple Health instantly."))
            helpRow(String(localized: "How does the widget work?"),
                    String(localized: "Add the Bottle of Water widget to your Home Screen or Lock Screen. Widget buttons log water without opening the app."))
            helpRow(String(localized: "What are quiet hours?"),
                    String(localized: "During that window (at night, for example) reminders are not delivered."))
            helpRow(String(localized: "How do I change the goal?"),
                    String(localized: "Settings → Daily goal. Rule of thumb: 30 ml per kg of body weight."))
            helpRow(String(localized: "Where is my data stored?"),
                    String(localized: "Locally on your device and in Apple Health. No analytics, no servers."))
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Help")
    }

    private func helpRow(_ q: String, _ a: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(q).font(.subheadline.weight(.bold)).foregroundStyle(Theme.textPrimary)
            Text(a).font(.footnote).foregroundStyle(Theme.textSecondary)
        }
        .listRowBackground(Theme.glass)
    }
}

struct ChangelogView: View {
    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: "v1.0 (1)").font(.subheadline.weight(.bold)).foregroundStyle(Theme.textPrimary)
                Text("• First release: water tracking, history, trends\n• Home Screen and Lock Screen widgets\n• Apple Health sync\n• Reminders: auto modes, custom interval, quiet hours\n• Customizable volume presets")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
            .listRowBackground(Theme.glass)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Changelog")
    }
}
