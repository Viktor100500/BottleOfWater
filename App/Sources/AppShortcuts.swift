import AppIntents

/// Zero-setup Siri phrases and Spotlight actions.
struct BottleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Add water in \(.applicationName)",
                "I drank water with \(.applicationName)",
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill")
        AppShortcut(
            intent: TodayWaterIntent(),
            phrases: [
                "How much water did I drink in \(.applicationName)",
                "Show today's water in \(.applicationName)",
            ],
            shortTitle: "Today's Water",
            systemImageName: "chart.bar.fill")
        AppShortcut(
            intent: UndoLastWaterIntent(),
            phrases: [
                "Undo last water in \(.applicationName)",
            ],
            shortTitle: "Undo Last Water",
            systemImageName: "arrow.uturn.backward")
    }

    static let shortcutTileColor: ShortcutTileColor = .teal
}
