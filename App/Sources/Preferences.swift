import SwiftUI
import WidgetKit

/// Observable view of `SettingsStore` for the UI. Every change is persisted to the
/// app group immediately and propagated to widgets, controls and reminders.
@MainActor
@Observable
final class Preferences {
    var goalML = SettingsStore.goalML {
        didSet { SettingsStore.goalML = goalML; propagate(reminders: true) }
    }

    var unit = SettingsStore.unit {
        didSet {
            guard unit != oldValue else { return }
            SettingsStore.unit = unit
            goalML = unit.snapped(goalML)
            // Untouched default presets follow the unit (250 ml ↔ 8 fl oz).
            if presets.map(\.volumeML) == VolumePreset.defaults(for: oldValue).map(\.volumeML) {
                let defaults = VolumePreset.defaults(for: unit)
                presets = defaults
                widgetButton1ML = defaults[1].volumeML
                widgetButton2ML = defaults[3].volumeML
            }
            propagate(reminders: true)
        }
    }

    var presets = SettingsStore.presets {
        didSet {
            SettingsStore.presets = presets
            // Keep widget buttons pointing at volumes that still exist.
            let volumes = presets.map(\.volumeML)
            if !volumes.contains(widgetButton1ML) { widgetButton1ML = volumes.first ?? 250 }
            if !volumes.contains(widgetButton2ML) { widgetButton2ML = volumes.last ?? 500 }
        }
    }

    var widgetButton1ML = SettingsStore.widgetButton1ML {
        didSet { SettingsStore.widgetButton1ML = widgetButton1ML; propagate(reminders: true) }
    }

    var widgetButton2ML = SettingsStore.widgetButton2ML {
        didSet { SettingsStore.widgetButton2ML = widgetButton2ML; propagate(reminders: true) }
    }

    var reminders = SettingsStore.reminders {
        didSet { SettingsStore.reminders = reminders; propagate(reminders: true) }
    }

    var onboardingCompleted = SettingsStore.onboardingCompleted {
        didSet { SettingsStore.onboardingCompleted = onboardingCompleted }
    }

    private func propagate(reminders: Bool) {
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        if reminders {
            Task { await ReminderScheduler.reschedule() }
        }
    }

    func format(_ ml: Int) -> String {
        VolumeFormat.string(ml, unit: unit)
    }
}
