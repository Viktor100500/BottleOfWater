import SwiftUI

struct SettingsScreen: View {
    @Environment(Preferences.self) private var preferences
    @Environment(\.openURL) private var openURL
    @State private var path: [String] = DemoData.screen == "reminders" ? ["reminders"] : []

    var body: some View {
        @Bindable var preferences = preferences

        NavigationStack(path: $path) {
            Form {
                Section {
                    GoalStepper(goalML: $preferences.goalML, unit: preferences.unit)
                    NavigationLink("Suggest a goal") {
                        GoalCalculatorScreen()
                    }
                } header: {
                    Text("Daily goal")
                }

                Section("Units") {
                    Picker("Units", selection: $preferences.unit) {
                        Text(verbatim: VolumeUnit.milliliters.symbol).tag(VolumeUnit.milliliters)
                        Text(verbatim: VolumeUnit.fluidOunces.symbol).tag(VolumeUnit.fluidOunces)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("Logging") {
                    NavigationLink {
                        PresetsEditor()
                    } label: {
                        LabeledContent("Quick add presets") {
                            Text(verbatim: "\(preferences.presets.count)")
                        }
                    }
                    NavigationLink {
                        RemindersScreen()
                    } label: {
                        LabeledContent("Reminders") {
                            Text(preferences.reminders.isEnabled ? "On" : "Off")
                        }
                    }
                }

                Section {
                    volumePicker("Button 1", selection: $preferences.widgetButton1ML)
                    volumePicker("Button 2", selection: $preferences.widgetButton2ML)
                } header: {
                    Text("Quick buttons")
                } footer: {
                    Text("Used by Home Screen widgets, the Control Center button and actions on reminders.")
                }

                Section {
                    HealthStatusRow()
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Every drink you log is saved to Apple Health. Bottle of Water doesn't read your health data.")
                }

                Section("Support") {
                    Link(destination: AppInfo.supportURL) {
                        Label("Help & FAQ", systemImage: "questionmark.circle")
                    }
                    if let url = AppInfo.supportMailURL {
                        Link(destination: url) {
                            Label("Contact support", systemImage: "envelope")
                        }
                    }
                    if let id = AppInfo.appStoreID,
                       let url = URL(string: "https://apps.apple.com/app/id\(id)?action=write-review") {
                        Link(destination: url) {
                            Label("Rate Bottle of Water", systemImage: "star")
                        }
                    }
                    Link(destination: AppInfo.privacyPolicyURL) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                }

                Section {
                } footer: {
                    VStack(spacing: 6) {
                        Text(verbatim: "Bottle of Water \(AppInfo.version)")
                        Text("Not a medical device. Hydration needs vary with health, activity and climate — ask a doctor if you're unsure.")
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
            }
            .themedList()
            .navigationTitle("Settings")
            .navigationDestination(for: String.self) { _ in RemindersScreen() }
        }
    }

    private func volumePicker(_ title: LocalizedStringKey, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(Array(Set(preferences.presets.map(\.volumeML) + [selection.wrappedValue])).sorted(), id: \.self) { ml in
                Text(verbatim: preferences.format(ml)).tag(ml)
            }
        }
    }
}

struct GoalStepper: View {
    @Binding var goalML: Int
    var unit: VolumeUnit

    var body: some View {
        Stepper(value: Binding(
            get: { goalML },
            set: { goalML = unit.snapped($0) }),
                in: SettingsStore.goalRange, step: unit.goalStepML) {
            LabeledContent("Goal") {
                Text(VolumeFormat.string(goalML, unit: unit))
                    .font(.body.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.aqua)
                    .contentTransition(.numericText())
            }
        }
    }
}

struct HealthStatusRow: View {
    @State private var status = HealthSync.shared.status
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health")
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(status == .connected ? Theme.success : Theme.textSecondary)
                }
            } icon: {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
            }
            Spacer()
            switch status {
            case .notDetermined:
                Button("Connect") {
                    Task {
                        status = await HealthSync.shared.requestAuthorization()
                        await WaterStore.shared.flushPendingHealth()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.aqua)
                .foregroundStyle(Theme.ink)
            case .denied:
                Button("Open Health") {
                    if let url = URL(string: "x-apple-health://") { openURL(url) }
                }
                .buttonStyle(.bordered)
            default:
                EmptyView()
            }
        }
        .onAppear { status = HealthSync.shared.status }
    }

    private var statusText: LocalizedStringKey {
        switch status {
        case .connected: "Connected — drinks sync automatically"
        case .notDetermined: "Not connected"
        case .denied: "Access is off. Turn it on in Health → Sharing → Apps."
        case .unavailable: "Not available on this device"
        }
    }
}

struct GoalCalculatorScreen: View {
    @Environment(Preferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            GoalCalculatorSection { suggested in
                preferences.goalML = suggested
                dismiss()
            }
        }
        .themedList()
        .navigationTitle("Suggest a Goal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Weight → suggested goal. Shared by Settings and onboarding.
struct GoalCalculatorSection: View {
    @Environment(Preferences.self) private var preferences
    var onApply: (Int) -> Void

    @AppStorage("lastWeightKg", store: AppGroup.defaults) private var weightKg = 70.0

    private var usesPounds: Bool { preferences.unit == .fluidOunces }
    private var suggested: Int { GoalCalculator.suggestedML(weightKg: weightKg) }

    var body: some View {
        Section {
            Stepper(value: weightBinding, in: usesPounds ? 66...440 : 30...200, step: 1) {
                LabeledContent("Weight") {
                    Text(weightText).monospacedDigit()
                }
            }
            LabeledContent("Suggested goal") {
                Text(preferences.format(suggested))
                    .font(.body.weight(.heavy))
                    .foregroundStyle(Theme.aqua)
                    .monospacedDigit()
            }
            Button("Use this goal") { onApply(suggested) }
                .fontWeight(.semibold)
        } footer: {
            Text("About 30 mL per kg of body weight is a common starting point. Drink more in hot weather or when you exercise.")
        }
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { usesPounds ? (weightKg / GoalCalculator.kgPerPound).rounded() : weightKg.rounded() },
            set: { weightKg = usesPounds ? $0 * GoalCalculator.kgPerPound : $0 })
    }

    private var weightText: String {
        let value = usesPounds ? weightKg / GoalCalculator.kgPerPound : weightKg
        return Measurement(value: value.rounded(), unit: usesPounds ? UnitMass.pounds : UnitMass.kilograms)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
    }
}
