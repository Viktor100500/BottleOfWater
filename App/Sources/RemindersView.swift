import SwiftUI

/// iOS-style notification controls: two independent toggles (Auto / Custom)
/// that expand their settings in place and can be enabled in parallel.
struct RemindersView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var autoEnabled = SettingsStore.autoRemindersEnabled
    @State private var manualEnabled = SettingsStore.manualRemindersEnabled
    @State private var schedule: AutoSchedule = SettingsStore.autoSchedule
    @State private var meals = SettingsStore.meals
    @State private var intervalMinutes = SettingsStore.customIntervalMinutes
    @State private var windowStart = SettingsStore.activeWindowStart
    @State private var windowEnd = SettingsStore.activeWindowEnd
    @State private var quietEnabled = SettingsStore.quietHoursEnabled
    @State private var quietStart = SettingsStore.quietStart
    @State private var quietEnd = SettingsStore.quietEnd
    @State private var manualReminders = SettingsStore.manualReminders
    @State private var editorReminder: ManualReminder?
    @State private var nextDate: Date?
    @State private var authDenied = false

    private var anyEnabled: Bool { autoEnabled || manualEnabled }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Auto reminders
                Section {
                    Toggle("Auto reminders", isOn: $autoEnabled.animation())
                        .listRowBackground(Theme.glass)
                    if autoEnabled {
                        autoScheduleRows
                    }
                }

                if autoEnabled && schedule == .meals {
                    Section {
                        mealRows
                    } header: {
                        Text("Meals")
                    } footer: {
                        Text("From 1 to 10 meals a day.")
                    }
                }

                if autoEnabled && schedule == .custom {
                    Section("Custom interval") {
                        Stepper(value: $intervalMinutes, in: 15...360, step: 15) {
                            HStack {
                                Text("Every")
                                Spacer()
                                Text(intervalTitle).fontWeight(.bold).monospacedDigit()
                                    .foregroundStyle(Theme.aqua)
                            }
                        }
                        .listRowBackground(Theme.glass)
                        minutePicker(String(localized: "Window from"), minutes: $windowStart)
                        minutePicker(String(localized: "Window until"), minutes: $windowEnd)
                    }
                }

                if autoEnabled {
                    Section {
                        Toggle("Enable quiet hours", isOn: $quietEnabled.animation())
                            .listRowBackground(Theme.glass)
                        if quietEnabled {
                            minutePicker(String(localized: "Start"), minutes: $quietStart)
                            minutePicker(String(localized: "End"), minutes: $quietEnd)
                        }
                    } header: {
                        Text("Quiet hours")
                    } footer: {
                        Text("Quiet hours apply to auto reminders only.")
                    }
                }

                // MARK: Custom reminders
                Section {
                    Toggle("Custom reminders", isOn: $manualEnabled.animation())
                        .listRowBackground(Theme.glass)
                    if manualEnabled {
                        manualRows
                    }
                } footer: {
                    if autoEnabled && manualEnabled {
                        Text("If an auto reminder and a custom one collide, only the custom one is delivered.")
                    }
                }

                if !anyEnabled {
                    Section {
                        Text("Notifications are off")
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Theme.glass)
                    }
                }

                if authDenied && anyEnabled {
                    Section {
                        Label("Notifications are disabled in iOS Settings. Open Settings → Bottle of Water → Notifications.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.warn)
                            .listRowBackground(Theme.glass)
                    }
                }

                if anyEnabled, let nextDate {
                    Section("Next reminder") {
                        Label {
                            Text(nextDate, format: .dateTime.weekday(.wide).hour().minute())
                                .foregroundStyle(Theme.textPrimary)
                        } icon: {
                            Image(systemName: "bell.badge.fill").foregroundStyle(Theme.aqua)
                        }
                        .listRowBackground(Theme.glass)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
            .sheet(item: $editorReminder) { reminder in
                ReminderEditSheet(
                    reminder: reminder,
                    isNew: !manualReminders.contains { $0.id == reminder.id }
                ) { result in
                    if let idx = manualReminders.firstIndex(where: { $0.id == result.id }) {
                        manualReminders[idx] = result
                    } else {
                        manualReminders.append(result)
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.aqua)
        .onAppear { refreshNext() }
        .onChange(of: autoEnabled) { persist() }
        .onChange(of: manualEnabled) { persist() }
        .onChange(of: schedule) { persist() }
        .onChange(of: meals) { persist() }
        .onChange(of: intervalMinutes) { persist() }
        .onChange(of: windowStart) { persist() }
        .onChange(of: windowEnd) { persist() }
        .onChange(of: quietEnabled) { persist() }
        .onChange(of: quietStart) { persist() }
        .onChange(of: quietEnd) { persist() }
        .onChange(of: manualReminders) { persist() }
    }

    // MARK: Rows

    @ViewBuilder
    private var autoScheduleRows: some View {
        ForEach(AutoSchedule.allCases, id: \.self) { option in
            Button {
                withAnimation { schedule = option }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.title).foregroundStyle(Theme.textPrimary)
                        if let subtitle = option.subtitle {
                            Text(subtitle).font(.caption).foregroundStyle(Theme.textTertiary)
                        }
                    }
                    Spacer()
                    if schedule == option {
                        Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Theme.aqua)
                    }
                }
            }
            .listRowBackground(Theme.glass)
        }
    }

    @ViewBuilder
    private var mealRows: some View {
        ForEach($meals) { $meal in
            HStack {
                TextField("Meal name", text: $meal.label)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                DatePicker("",
                           selection: Binding(
                            get: { dateFrom(minutes: meal.minutesFromMidnight) },
                            set: { meal.minutesFromMidnight = minutesFrom(date: $0) }),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            .listRowBackground(Theme.glass)
        }
        .onDelete { offsets in
            if meals.count > 1 { meals.remove(atOffsets: offsets) }
        }

        Button {
            withAnimation {
                meals.append(MealTime(minutesFromMidnight: 16 * 60,
                                      label: String(localized: "Snack")))
            }
        } label: {
            Label("Add meal", systemImage: "plus.circle.fill")
                .foregroundStyle(Theme.aqua)
        }
        .listRowBackground(Theme.glass)
        .disabled(meals.count >= 10)
    }

    @ViewBuilder
    private var manualRows: some View {
        if manualReminders.isEmpty {
            Text("No reminders yet")
                .foregroundStyle(Theme.textTertiary)
                .listRowBackground(Theme.glass)
        }
        ForEach(manualReminders) { reminder in
            Button {
                editorReminder = reminder
            } label: {
                HStack {
                    Text(timeString(reminder.minutesFromMidnight))
                        .font(.body.weight(.bold)).monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    VStack(alignment: .leading, spacing: 1) {
                        if !reminder.label.isEmpty {
                            Text(reminder.label).font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                        if reminder.weekdaysOnly {
                            Text("weekdays only").font(.caption2).foregroundStyle(Theme.aqua)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .listRowBackground(Theme.glass)
        }
        .onDelete { manualReminders.remove(atOffsets: $0) }

        Button {
            editorReminder = ManualReminder(minutesFromMidnight: nowMinutes())
        } label: {
            Label("Add reminder", systemImage: "plus.circle.fill")
                .foregroundStyle(Theme.aqua)
        }
        .listRowBackground(Theme.glass)
        .disabled(manualReminders.count >= 16)
    }

    private func minutePicker(_ title: String, minutes: Binding<Int>) -> some View {
        DatePicker(title,
                   selection: Binding(
                    get: { dateFrom(minutes: minutes.wrappedValue) },
                    set: { minutes.wrappedValue = minutesFrom(date: $0) }),
                   displayedComponents: .hourAndMinute)
        .listRowBackground(Theme.glass)
    }

    // MARK: Logic

    private var intervalTitle: String {
        let h = intervalMinutes / 60, m = intervalMinutes % 60
        if h == 0 { return String(localized: "\(m) min") }
        if m == 0 { return String(localized: "\(h) h") }
        return String(localized: "\(h) h \(m) m")
    }

    private func timeString(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func dateFrom(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes,
                              to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    private func minutesFrom(date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func nowMinutes() -> Int {
        minutesFrom(date: .now)
    }

    private func persist() {
        SettingsStore.autoRemindersEnabled = autoEnabled
        SettingsStore.manualRemindersEnabled = manualEnabled
        SettingsStore.autoSchedule = schedule
        SettingsStore.meals = meals
        SettingsStore.customIntervalMinutes = intervalMinutes
        SettingsStore.activeWindowStart = windowStart
        SettingsStore.activeWindowEnd = windowEnd
        SettingsStore.quietHoursEnabled = quietEnabled
        SettingsStore.quietStart = quietStart
        SettingsStore.quietEnd = quietEnd
        SettingsStore.manualReminders = manualReminders

        Task {
            if anyEnabled {
                let granted = await ReminderPlanner.requestAuthorization()
                authDenied = !granted
            }
            await ReminderPlanner.reschedule()
            refreshNext()
        }
    }

    private func refreshNext() {
        nextDate = ReminderPlanner.nextReminderDate()
    }
}

// MARK: - Reminder editor (create & edit)

struct ReminderEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let reminder: ManualReminder
    let isNew: Bool
    var onSave: (ManualReminder) -> Void

    @State private var time: Date
    @State private var label: String
    @State private var weekdaysOnly: Bool

    init(reminder: ManualReminder, isNew: Bool, onSave: @escaping (ManualReminder) -> Void) {
        self.reminder = reminder
        self.isNew = isNew
        self.onSave = onSave
        let start = Calendar.current.startOfDay(for: .now)
        _time = State(initialValue: Calendar.current.date(
            byAdding: .minute, value: reminder.minutesFromMidnight, to: start) ?? .now)
        _label = State(initialValue: reminder.label)
        _weekdaysOnly = State(initialValue: reminder.weekdaysOnly)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .listRowBackground(Theme.glass)
                TextField("Label (optional)", text: $label)
                    .listRowBackground(Theme.glass)
                Toggle("Weekdays only", isOn: $weekdaysOnly)
                    .listRowBackground(Theme.glass)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(isNew ? "New reminder" : "Edit reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                        var updated = reminder
                        updated.minutesFromMidnight = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                        updated.label = label.trimmingCharacters(in: .whitespaces)
                        updated.weekdaysOnly = weekdaysOnly
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.aqua)
    }
}
