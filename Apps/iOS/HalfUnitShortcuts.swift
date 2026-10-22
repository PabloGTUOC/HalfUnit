import AppIntents
import HalfUnitCore

struct HalfUnitShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor {
        .teal
    }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogDrinkIntent(),
            phrases: [
                "Log a \(\.$preset) in \(.applicationName)",
                "Log \(\.$preset) in \(.applicationName)",
            ],
            shortTitle: "shortcut.logDrink.shortTitle",
            systemImageName: "mug.fill"
        )
        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "How many days without alcohol in \(.applicationName)",
                "Days without alcohol in \(.applicationName)",
            ],
            shortTitle: "shortcut.getStreak.shortTitle",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: GetStatsIntent(),
            phrases: [
                "Drinking stats in \(.applicationName)",
                "How often did I drink in \(.applicationName)",
            ],
            shortTitle: "shortcut.getStats.shortTitle",
            systemImageName: "chart.bar.xaxis"
        )
    }
}
