import AppIntents
import Foundation
import SwiftData

public struct PresetEntity: AppEntity, Equatable, Sendable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "intent.preset.typeName"
    )
    public static let defaultQuery = PresetEntityQuery()

    public let id: UUID
    public let key: String?
    public let name: String
    public let symbolName: String
    public let hu: Decimal
    public let volumeMl: Int
    public let abvPercent: Decimal

    public init(
        id: UUID,
        key: String?,
        name: String,
        symbolName: String,
        hu: Decimal,
        volumeMl: Int,
        abvPercent: Decimal
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.symbolName = symbolName
        self.hu = hu
        self.volumeMl = volumeMl
        self.abvPercent = abvPercent
    }

    public init(preset: Preset) {
        self.init(
            id: preset.id,
            key: preset.key,
            name: preset.name,
            symbolName: preset.symbolName,
            hu: preset.hu,
            volumeMl: preset.volumeMl,
            abvPercent: preset.abvPercent
        )
    }

    public func localizedName(locale: Locale = .current) -> String {
        IntentLocalization.localizedPresetName(
            presetKey: key,
            fallbackName: name,
            locale: locale
        )
    }

    public func formattedHU(locale: Locale = .current) -> String {
        IntentLocalization.formattedHU(hu, locale: locale)
    }

    public var resolvedSymbolName: String {
        IntentLocalization.symbolName(presetKey: key, fallbackSymbol: symbolName)
    }

    public var displayRepresentation: DisplayRepresentation {
        let titleText = localizedName()
        let subtitleText = formattedHU()
        return DisplayRepresentation(
            title: "\(titleText)",
            subtitle: "\(subtitleText)",
            image: .init(systemName: resolvedSymbolName)
        )
    }

    public static let fallbackDefaultIDsByKey: [String: UUID] = [
        "smallBeer": UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        "smallWine": UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        "beer": UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        "wineGlass": UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        "shot": UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        "longDrink": UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
    ]

    public static var fallbackDefaultEntities: [PresetEntity] {
        DefaultPresets.all.map { definition in
            let fallbackID = fallbackDefaultIDsByKey[definition.key] ?? UUID()
            return PresetEntity(
                id: fallbackID,
                key: definition.key,
                name: definition.key,
                symbolName: definition.symbolName,
                hu: definition.hu,
                volumeMl: definition.volumeMl,
                abvPercent: definition.abvPercent
            )
        }
    }
}

public struct PresetEntityQuery: EntityQuery, EnumerableEntityQuery {
    public init() {}

    public func entities(for identifiers: [PresetEntity.ID]) async throws -> [PresetEntity] {
        try await MainActor.run {
            let container = IntentStoreProvider.shared
            let service = LogService(
                context: container.mainContext,
                now: Date.init,
                timeZone: { TimeZone.autoupdatingCurrent }
            )
            return try Self.entities(for: identifiers, from: service)
        }
    }

    public func suggestedEntities() async throws -> [PresetEntity] {
        try await allEntities()
    }

    public func allEntities() async throws -> [PresetEntity] {
        try await MainActor.run {
            let container = IntentStoreProvider.shared
            let service = LogService(
                context: container.mainContext,
                now: Date.init,
                timeZone: { TimeZone.autoupdatingCurrent }
            )
            return try Self.allEntities(from: service)
        }
    }

    @MainActor
    public static func allEntities(from logService: LogService) throws -> [PresetEntity] {
        try logService.seedDefaultPresetsIfNeeded()
        return try logService.presets().map(PresetEntity.init(preset:))
    }

    @MainActor
    public static func entities(
        for identifiers: [PresetEntity.ID],
        from logService: LogService
    ) throws -> [PresetEntity] {
        let available = try allEntities(from: logService)
        let byID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        let byKey: [String: PresetEntity] = Dictionary(
            uniqueKeysWithValues: available.compactMap { entity in
                guard let key = entity.key else {
                    return nil
                }
                return (key, entity)
            }
        )
        let fallbackKeyByID: [UUID: String] = Dictionary(
            uniqueKeysWithValues: PresetEntity.fallbackDefaultIDsByKey.map { ($0.value, $0.key) }
        )

        var resolved: [PresetEntity] = []
        resolved.reserveCapacity(identifiers.count)

        for id in identifiers {
            if let match = byID[id] {
                resolved.append(match)
            } else if let fallbackKey = fallbackKeyByID[id], let match = byKey[fallbackKey] {
                resolved.append(match)
            }
        }
        return resolved
    }
}
