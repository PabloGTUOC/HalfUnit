import AppIntents
import Foundation
import SwiftData

public struct GetStreakIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.getStreak.title"
    public static let description = IntentDescription("intent.getStreak.description")
    public static let openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
        let (summary, dialogText) = try await MainActor.run {
            let container = IntentStoreProvider.makeModelContainer()
            let service = LogService(
                context: container.mainContext,
                now: Date.init,
                timeZone: { TimeZone.autoupdatingCurrent }
            )
            return try Self.evaluateStreak(logService: service)
        }
        return .result(
            value: summary.currentStreakDays,
            dialog: IntentDialog(stringLiteral: dialogText)
        )
    }

    @MainActor
    public static func evaluateStreak(
        logService: LogService,
        locale: Locale = .current
    ) throws -> (summary: StreakSummary, dialogText: String) {
        let settings = try logService.settings()
        let today = try logService.today()
        let snapshots = try logService.snapshots()
        let engine = StatsEngine(
            drinks: snapshots,
            firstUseDay: settings.firstUseDay,
            today: today
        )
        let summary = engine.streaks()
        let dialogText = formatStreakResult(summary: summary, locale: locale)
        return (summary, dialogText)
    }

    public static func formatStreakResult(
        summary: StreakSummary,
        locale: Locale = .current
    ) -> String {
        if summary.isDrinkingToday {
            if let previousDays = summary.previousStreakDays {
                let previousText = IntentLocalization.plural(
                    "streak.previousStreak",
                    count: previousDays,
                    locale: locale
                )
                let format = IntentLocalization.string(
                    "intent.getStreak.result.drinkingTodayWithPrevious",
                    locale: locale
                )
                return String(format: format, locale: locale, previousText)
            }
            return IntentLocalization.string("intent.getStreak.result.drinkingToday", locale: locale)
        }

        let daysText = IntentLocalization.plural(
            "streak.daysWithoutAlcohol",
            count: summary.currentStreakDays,
            locale: locale
        )
        return "\(daysText)."
    }
}
