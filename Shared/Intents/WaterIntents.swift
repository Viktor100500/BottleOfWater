import AppIntents
import Foundation

/// Siri / Shortcuts / Spotlight: "Log water in Bottle of Water".
struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Adds water to today's total and to Apple Health.")
    static let openAppWhenRun = false

    @Parameter(title: "Amount", unit: .milliliters, unitAdjustForLocale: true,
               supportsNegativeNumbers: false,
               requestValueDialog: IntentDialog("How much water?"))
    var amount: Measurement<UnitVolume>

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) of water")
    }

    init() {}

    init(ml: Int) {
        amount = Measurement(value: Double(ml), unit: .milliliters)
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ml = Int(amount.converted(to: .milliliters).value.rounded())
        guard (1...5000).contains(ml) else {
            throw $amount.needsValueError("Enter an amount up to 5 liters.")
        }
        let store = WaterStore.shared
        await store.add(ml: ml, source: .shortcut)
        return .result(dialog: IntentDialog(stringLiteral: TodaySummary.sentence(store: store, added: ml)))
    }
}

/// Widget and Control Center buttons. Hidden from Shortcuts — `LogWaterIntent` covers that.
struct QuickLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Log Water"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Milliliters")
    var volumeML: Int

    @Parameter(title: "Source")
    var sourceRaw: String

    init() {}

    init(ml: Int, source: EntrySource) {
        volumeML = ml
        sourceRaw = source.rawValue
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await WaterStore.shared.add(ml: volumeML, source: EntrySource(rawValue: sourceRaw) ?? .widget)
        return .result()
    }
}

struct UndoLastWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Undo Last Water"
    static let description = IntentDescription("Removes today's most recent water entry, also from Apple Health.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = WaterStore.shared
        guard let ml = await store.undoLast() else {
            return .result(dialog: "Nothing to undo today.")
        }
        let removed = VolumeFormat.string(ml, unit: SettingsStore.unit)
        return .result(dialog: IntentDialog(stringLiteral: String(localized: "Removed \(removed).")))
    }
}

struct TodayWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Water"
    static let description = IntentDescription("Tells how much water you've had today, in milliliters.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let store = WaterStore.shared
        let total = store.total(on: .now)
        return .result(value: total,
                       dialog: IntentDialog(stringLiteral: TodaySummary.sentence(store: store, added: nil)))
    }
}

@MainActor
enum TodaySummary {
    static func sentence(store: WaterStore, added: Int?) -> String {
        let unit = SettingsStore.unit
        let total = store.total(on: .now)
        let goal = SettingsStore.goalML
        let progress = String(localized: "\(VolumeFormat.string(total, unit: unit)) of \(VolumeFormat.string(goal, unit: unit)) today.")
        guard let added else { return progress }
        let logged = String(localized: "Logged \(VolumeFormat.string(added, unit: unit)).")
        return logged + " " + progress
    }
}
