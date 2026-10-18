import SwiftUI
import UserNotifications

struct RemindersScreen: View {
    @Environment(Preferences.self) private var preferences
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var authorized = true
    @State private var editingTime: ReminderTime?
    @State private var nextReminder: Date?

    var body: some View {
        @Bindable var preferences = preferences
        let settings = preferences.reminders

        Form {
            Section {
                Toggle("Remind me to drink", isOn: enabledBinding)
            } footer: {
                if !authorized && settings.isEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notifications are turned off for Bottle of Water.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.warn)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                        .fontWeight(.semibold)
                    }
                    .padding(.top, 4)
                }
            }

            if settings.isEnabled {
                Section {
                    Picker("Schedule", selection: $preferences.reminders.mode.animation()) {
                        Text("Interval").tag(ReminderSettings.Mode.interval)
                        Text("Specific times").tag(ReminderSettings.Mode.times)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                switch settings.mode {
                case .interval: intervalSection
                case .times: timesSection
                }

                Section {
                    Toggle(settings.mode == .interval ? "Count from my last drink" : "Skip if I just drank",
                           isOn: $preferences.reminders.skipIfRecentlyLogged)
                    Toggle("Pause after reaching my goal", isOn: $preferences.reminders.skipWhenGoalReached)
                } header: {
                    Text("Smart")
                } footer: {
                    Text(settings.mode == .interval
                         ? "Logging a drink restarts the interval, so you're never reminded right after a glass."
                         : "A reminder is skipped if you logged a drink in the 30 minutes before it.")
                }

                Section("Next reminder") {
                    if let nextReminder {
                        Label {
                            Text(nextReminder, format: .relative(presentation: .named))
                            + Text(verbatim: " · ")
                            + Text(nextReminder, format: .dateTime.weekday(.abbreviated).hour().minute())
                        } icon: {
                            Image(systemName: "bell.badge.fill").foregroundStyle(Theme.aqua)
                        }
                    } else {
                        Text("No upcoming reminders")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .themedList()
        .navigationTitle("Reminders")
        .sheet(item: $editingTime) { time in
            ReminderTimeEditor(time: time) { updated in
                var times = preferences.reminders.times
                if let index = times.firstIndex(where: { $0.id == updated.id }) {
                    times[index] = updated
                } else {
                    times.append(updated)
                }
                preferences.reminders.times = times.sorted { $0.minutes < $1.minutes }
            }
        }
        .task(id: settings) {
            authorized = await ReminderScheduler.isAuthorized()
            nextReminder = ReminderScheduler.nextReminder(for: settings)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { authorized = await ReminderScheduler.isAuthorized() }
            }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { preferences.reminders.isEnabled },
            set: { enabled in
                withAnimation { preferences.reminders.isEnabled = enabled }
                guard enabled else { return }
                Task {
                    authorized = await ReminderScheduler.requestAuthorization()
                    await ReminderScheduler.reschedule()
                }
            })
    }

    private var intervalSection: some View {
        @Bindable var preferences = preferences
        return Section {
            Stepper(value: $preferences.reminders.intervalMinutes, in: ReminderSettings.intervalRange, step: 15) {
                LabeledContent("Every") {
                    Text(Duration.seconds(preferences.reminders.intervalMinutes * 60),
                         format: .units(allowed: [.hours, .minutes], width: .abbreviated))
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.aqua)
                }
            }
            DatePicker("From", selection: minutesBinding(\.windowStart), displayedComponents: .hourAndMinute)
            DatePicker("Until", selection: minutesBinding(\.windowEnd), displayedComponents: .hourAndMinute)
        } footer: {
            if preferences.reminders.windowEnd <= preferences.reminders.windowStart {
                Text("“Until” must be later than “From”.")
                    .foregroundStyle(Theme.warn)
            } else {
                Text("No reminders outside this window.")
            }
        }
    }

    private var timesSection: some View {
        Section {
            ForEach(preferences.reminders.times) { time in
                Button {
                    editingTime = time
                } label: {
                    HStack {
                        Text(Self.date(from: time.minutes), format: .dateTime.hour().minute())
                            .font(.body.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                        VStack(alignment: .leading, spacing: 1) {
                            if !time.label.isEmpty {
                                Text(verbatim: time.label).foregroundStyle(Theme.textSecondary)
                            }
                            Text(verbatim: WeekdayFormat.summary(time.weekdays))
                                .font(.caption)
                                .foregroundStyle(Theme.aqua)
                        }
                        Spacer()
                    }
                }
            }
            .onDelete { preferences.reminders.times.remove(atOffsets: $0) }

            Button {
                editingTime = ReminderTime(minutes: 12 * 60)
            } label: {
                Label("Add time", systemImage: "plus.circle.fill")
            }
            .disabled(preferences.reminders.times.count >= ReminderSettings.maxTimes)
        }
    }

    private func minutesBinding(_ keyPath: WritableKeyPath<ReminderSettings, Int>) -> Binding<Date> {
        Binding(
            get: { Self.date(from: preferences.reminders[keyPath: keyPath]) },
            set: { preferences.reminders[keyPath: keyPath] = Self.minutes(from: $0) })
    }

    static func date(from minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

struct ReminderTimeEditor: View {
    @State var time: ReminderTime
    var onSave: (ReminderTime) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Time",
                           selection: Binding(
                               get: { RemindersScreen.date(from: time.minutes) },
                               set: { time.minutes = RemindersScreen.minutes(from: $0) }),
                           displayedComponents: .hourAndMinute)
                TextField("Label", text: $time.label, prompt: Text("Optional, e.g. Lunch"))
                Section("Repeat") {
                    HStack(spacing: 6) {
                        ForEach(WeekdayFormat.orderedWeekdays, id: \.self) { weekday in
                            let isOn = time.weekdays.contains(weekday)
                            Button {
                                if isOn {
                                    if time.weekdays.count > 1 { time.weekdays.remove(weekday) }
                                } else {
                                    time.weekdays.insert(weekday)
                                }
                            } label: {
                                Text(verbatim: WeekdayFormat.veryShort(weekday))
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .foregroundStyle(isOn ? Theme.ink : Theme.textSecondary)
                                    .background(isOn ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Theme.glassRaised),
                                                in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: WeekdayFormat.full(weekday)))
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .themedList()
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        time.label = time.label.trimmingCharacters(in: .whitespaces)
                        onSave(time)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium])
        .themedSheet()
    }
}

enum WeekdayFormat {
    /// Calendar weekdays (1 = Sunday) in the user's first-weekday order.
    static var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    static func veryShort(_ weekday: Int) -> String {
        Calendar.current.veryShortStandaloneWeekdaySymbols[weekday - 1]
    }

    static func full(_ weekday: Int) -> String {
        Calendar.current.standaloneWeekdaySymbols[weekday - 1]
    }

    static func summary(_ weekdays: Set<Int>) -> String {
        if weekdays.count == 7 { return String(localized: "Every day") }
        if weekdays == Set(2...6) { return String(localized: "Weekdays") }
        if weekdays == [1, 7] { return String(localized: "Weekends") }
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        return orderedWeekdays.filter(weekdays.contains).map { symbols[$0 - 1] }.formatted(.list(type: .and, width: .narrow))
    }
}
