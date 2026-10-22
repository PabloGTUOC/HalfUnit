import AppIntents
import Foundation
import SwiftData
import WidgetKit

public struct LogDrinkIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.logDrink.title"
    public static let description = IntentDescription("intent.logDrink.description")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "intent.logDrink.parameter.preset")
    public var preset: PresetEntity

    @Parameter(title: "intent.logDrink.parameter.time")
    public var time: Date?

    public var source: DrinkSource = .siri

    public init() {}

    public init(
        preset: PresetEntity,
        time: Date? = nil,
        source: DrinkSource = .siri
    ) {
        self.source = source
        self.preset = preset
        self.time = time
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("intent.logDrink.summary \(\.$preset)") {
            \.$time
        }
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let dialogText = try await Self.executeWithSharedStore(
            preset: preset,
            time: time,
            source: source
        )
        return .result(value: dialogText, dialog: IntentDialog(stringLiteral: dialogText))
    }

    @MainActor
    @discardableResult
    public static func performLog(
        preset entity: PresetEntity,
        time: Date? = nil,
        source: DrinkSource = .siri,
        logService: LogService,
        locale: Locale = .current
    ) throws -> (drink: Drink, dialogText: String) {
        try logService.seedDefaultPresetsIfNeeded()
        let presets = try logService.presets()
        let matchedPreset =
            presets.first(where: { $0.id == entity.id })
            ?? presets.first(where: { $0.key != nil && $0.key == entity.key })
            ?? presets.first(where: { $0.name == entity.name })

        let drink: Drink
        if let matchedPreset {
            drink = try logService.log(preset: matchedPreset, at: time, source: source)
        } else {
            drink = try logService.logCustom(
                name: entity.name,
                hu: entity.hu,
                volumeMl: entity.volumeMl,
                abvPercent: entity.abvPercent,
                at: time,
                source: source
            )
        }

        let localizedName = entity.localizedName(locale: locale)
        let huText = entity.formattedHU(locale: locale)
        let format = IntentLocalization.string("intent.logDrink.result", locale: locale)
        let dialogText = String(format: format, locale: locale, localizedName, huText)
        return (drink, dialogText)
    }

    @MainActor
    static func executeWithSharedStore(
        preset entity: PresetEntity,
        time: Date?,
        source: DrinkSource
    ) throws -> String {
        let container = IntentStoreProvider.shared
        let service = LogService(
            context: container.mainContext,
            now: Date.init,
            timeZone: { TimeZone.autoupdatingCurrent }
        )
        let (_, dialogText) = try performLog(
            preset: entity,
            time: time,
            source: source,
            logService: service
        )
        WidgetCenter.shared.reloadAllTimelines()
        return dialogText
    }
}

public struct WidgetLogDrinkIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.logDrink.widget.title"
    public static let description = IntentDescription("intent.logDrink.description")
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = false

    @Parameter(title: "intent.logDrink.parameter.preset")
    public var preset: PresetEntity

    public init() {}

    public init(preset: PresetEntity) {
        self.preset = preset
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let dialogText = try await LogDrinkIntent.executeWithSharedStore(
            preset: preset,
            time: nil,
            source: .widget
        )
        return .result(value: dialogText, dialog: IntentDialog(stringLiteral: dialogText))
    }
}
