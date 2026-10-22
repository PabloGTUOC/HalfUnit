import AppIntents
import Foundation
import SwiftData

public enum IntentStatsPeriod: String, AppEnum, CaseIterable, Sendable {
    case last7Days = "7d"
    case last30Days = "30d"
    case last3Months = "3m"
    case last12Months = "12m"
    case last2Years = "2y"

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "intent.statsPeriod.typeName"
    )

    public static let caseDisplayRepresentations: [IntentStatsPeriod: DisplayRepresentation] = [
        .last7Days: DisplayRepresentation(title: "intent.statsPeriod.7d"),
        .last30Days: DisplayRepresentation(title: "intent.statsPeriod.30d"),
        .last3Months: DisplayRepresentation(title: "intent.statsPeriod.3m"),
        .last12Months: DisplayRepresentation(title: "intent.statsPeriod.12m"),
        .last2Years: DisplayRepresentation(title: "intent.statsPeriod.2y"),
    ]

    public var domainPeriod: Period {
        switch self {
        case .last7Days:
            return .last7Days
        case .last30Days:
            return .last30Days
        case .last3Months:
            return .last3Months
        case .last12Months:
            return .last12Months
        case .last2Years:
            return .last2Years
        }
    }
}

public struct GetStatsIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.getStats.title"
    public static let description = IntentDescription("intent.getStats.description")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "intent.getStats.parameter.period", default: .last3Months)
    public var period: IntentStatsPeriod

    public static var parameterSummary: some ParameterSummary {
        Summary("intent.getStats.summary \(\.$period)")
    }

    public init() {
        self.period = .last3Months
    }

    public init(period: IntentStatsPeriod) {
        self.period = period
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let (_, dialogText) = try await MainActor.run {
            let container = IntentStoreProvider.shared
            let service = LogService(
                context: container.mainContext,
                now: Date.init,
                timeZone: { TimeZone.autoupdatingCurrent }
            )
            return try Self.evaluateStats(period: period, logService: service)
        }
        return .result(value: dialogText, dialog: IntentDialog(stringLiteral: dialogText))
    }

    @MainActor
    public static func evaluateStats(
        period: IntentStatsPeriod,
        logService: LogService,
        locale: Locale = .current
    ) throws -> (stats: PeriodStats, dialogText: String) {
        let settings = try logService.settings()
        let today = try logService.today()
        let snapshots = try logService.snapshots()
        let engine = StatsEngine(
            drinks: snapshots,
            firstUseDay: settings.firstUseDay,
            today: today
        )
        let stats = engine.stats(for: period.domainPeriod)
        let dialogText = formatStatsResult(stats: stats, locale: locale)
        return (stats, dialogText)
    }

    public static func formatStatsResult(
        stats: PeriodStats,
        locale: Locale = .current
    ) -> String {
        let alcoholFreeText = IntentLocalization.plural(
            "insights.summary.alcoholFreeDays.value",
            count: stats.alcoholFreeDays,
            locale: locale
        )
        let totalHUText = IntentLocalization.formattedHU(stats.totalHU, locale: locale)

        if stats.trackedDays < stats.lengthDays {
            let format = IntentLocalization.string(
                "intent.getStats.result.trackedDays",
                locale: locale
            )
            return String(
                format: format,
                locale: locale,
                Int64(stats.drinkingDays),
                Int64(stats.trackedDays),
                alcoholFreeText,
                totalHUText
            )
        }

        let format = IntentLocalization.string("intent.getStats.result.days", locale: locale)
        return String(
            format: format,
            locale: locale,
            Int64(stats.drinkingDays),
            Int64(stats.lengthDays),
            alcoholFreeText,
            totalHUText
        )
    }
}
