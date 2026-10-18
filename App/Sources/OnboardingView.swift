import SwiftUI

/// Three steps: what the app does → daily goal → permissions.
struct OnboardingView: View {
    @Environment(Preferences.self) private var preferences
    @State private var step = 0

    var body: some View {
        ZStack {
            Theme.background
            VStack(spacing: 0) {
                Group {
                    switch step {
                    case 0: WelcomeStep()
                    case 1: GoalStep()
                    default: PermissionsStep()
                    }
                }
                .frame(maxHeight: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)

                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index == step ? Theme.aqua : Theme.stroke)
                            .frame(width: index == step ? 22 : 8, height: 8)
                    }
                }
                .padding(.bottom, 18)
                .accessibilityHidden(true)

                Button(step < 2 ? "Continue" : "Get started") {
                    if step < 2 {
                        withAnimation(.spring(duration: 0.45)) { step += 1 }
                    } else {
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
    }

    private func finish() {
        // Presets follow the chosen unit unless the user already customised them.
        if AppGroup.defaults.data(forKey: "presets") == nil {
            preferences.presets = VolumePreset.defaults(for: preferences.unit)
            preferences.widgetButton1ML = preferences.presets[1].volumeML
            preferences.widgetButton2ML = preferences.presets[3].volumeML
        }
        withAnimation(.easeInOut(duration: 0.4)) {
            preferences.onboardingCompleted = true
        }
    }
}

private struct WelcomeStep: View {
    @State private var demoTotal = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                LiquidGauge(totalML: demoTotal, goalML: 2000, unit: .milliliters,
                            size: CGSize(width: 150, height: 178))
                    .padding(.top, 40)
                    .accessibilityHidden(true)
                    .task {
                        try? await Task.sleep(for: .milliseconds(400))
                        demoTotal = 1300
                    }

                VStack(spacing: 8) {
                    Text(verbatim: "Bottle of Water")
                        .font(.rounded(.largeTitle))
                        .foregroundStyle(Theme.primaryGradient)
                    Text("Drink a little more water, without thinking about it.")
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 18) {
                    Feature(symbol: "hand.tap.fill", title: "One tap, anywhere",
                            text: "Log from the app, widgets, Control Center, Siri or right from a reminder.")
                    Feature(symbol: "bell.badge.fill", title: "Reminders that get you",
                            text: "They stay quiet after a glass and stop once you hit your goal.")
                    Feature(symbol: "heart.fill", title: "Apple Health built in",
                            text: "Every drink is saved to Health. No accounts, no tracking.")
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct Feature: View {
    var symbol: String
    var title: LocalizedStringKey
    var text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.aqua)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
                Text(text).font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GoalStep: View {
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences

        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Your daily goal")
                    .font(.rounded(.largeTitle))
                    .foregroundStyle(Theme.textPrimary)
                Text("You can change it any time in Settings.")
                    .foregroundStyle(Theme.textSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 40)
            .padding(.horizontal, 24)

            Form {
                Section {
                    Picker("Units", selection: $preferences.unit) {
                        Text(verbatim: VolumeUnit.milliliters.symbol).tag(VolumeUnit.milliliters)
                        Text(verbatim: VolumeUnit.fluidOunces.symbol).tag(VolumeUnit.fluidOunces)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                GoalCalculatorSection { preferences.goalML = $0 }
                Section {
                    GoalStepper(goalML: $preferences.goalML, unit: preferences.unit)
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
}

private struct PermissionsStep: View {
    @Environment(Preferences.self) private var preferences
    @State private var healthStatus = HealthSync.shared.status
    @State private var remindersOn = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Stay in sync")
                        .font(.rounded(.largeTitle))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Both are optional — the app works fine without them.")
                        .foregroundStyle(Theme.textSecondary)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                .padding(.bottom, 12)

                PermissionCard(symbol: "heart.fill", tint: .pink,
                               title: "Apple Health",
                               text: "Save every drink to Health, so all your data stays in one place.",
                               done: healthStatus == .connected,
                               buttonTitle: "Connect") {
                    healthStatus = await HealthSync.shared.requestAuthorization()
                }
                .opacity(healthStatus == .unavailable ? 0.5 : 1)
                .disabled(healthStatus == .unavailable || healthStatus == .denied)

                PermissionCard(symbol: "bell.badge.fill", tint: Theme.aqua,
                               title: "Reminders",
                               text: "A gentle nudge every 90 minutes during the day. Fine-tune it later in Settings.",
                               done: remindersOn,
                               buttonTitle: "Turn on") {
                    if await ReminderScheduler.requestAuthorization() {
                        preferences.reminders.isEnabled = true
                        remindersOn = true
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct PermissionCard: View {
    var symbol: String
    var tint: Color
    var title: LocalizedStringKey
    var text: LocalizedStringKey
    var done: Bool
    var buttonTitle: LocalizedStringKey
    var action: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !done {
                Button {
                    Task { await action() }
                } label: {
                    Text(buttonTitle)
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .tint(tint)
            }
        }
        .padding(18)
        .glassCard()
        .animation(.spring(duration: 0.3), value: done)
    }
}
