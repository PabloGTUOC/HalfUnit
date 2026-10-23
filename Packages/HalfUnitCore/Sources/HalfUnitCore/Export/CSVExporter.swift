import Foundation
import SwiftData

public enum CSVExporter {
    public static let utf8BOMBytes: [UInt8] = [0xEF, 0xBB, 0xBF]
    public static let utf8BOMString = "\u{FEFF}"
    public static let lineEnding = "\r\n"

    public static let columns: [String] = [
        "date",
        "time",
        "logical_day",
        "name",
        "preset_key",
        "hu",
        "grams",
        "standard_drinks",
        "volume_ml",
        "abv_percent",
        "note",
        "source",
        "time_zone",
        "id",
    ]

    public static var headerLine: String {
        columns.joined(separator: ",")
    }

    @MainActor
    public static func exportString(
        from logService: LogService,
        nameResolver: ((_ presetKey: String?, _ storedName: String) -> String)? = nil
    ) throws -> String {
        let activeDrinks = try logService.drinks(includeDeleted: false)
        let allPresets = try logService.presets(includeHidden: true)
        var presetKeyById: [UUID: String] = [:]
        for preset in allPresets {
            if let key = preset.key {
                presetKeyById[preset.id] = key
            }
        }
        return exportString(drinks: activeDrinks, presetKeyById: presetKeyById, nameResolver: nameResolver)
    }

    @MainActor
    public static func exportData(
        from logService: LogService,
        nameResolver: ((_ presetKey: String?, _ storedName: String) -> String)? = nil
    ) throws -> Data {
        let csvString = try exportString(from: logService, nameResolver: nameResolver)
        return Data(csvString.utf8)
    }

    public static func exportString(
        drinks: [Drink],
        presetKeyById: [UUID: String] = [:],
        nameResolver: ((_ presetKey: String?, _ storedName: String) -> String)? = nil
    ) -> String {
        let nonDeleted = drinks.filter { $0.deletedAt == nil }
        var lines: [String] = []
        lines.reserveCapacity(nonDeleted.count + 1)
        lines.append(headerLine)

        for drink in nonDeleted {
            let fields = rowFields(for: drink, presetKeyById: presetKeyById, nameResolver: nameResolver)
            let encodedLine = fields.map(escapeField).joined(separator: ",")
            lines.append(encodedLine)
        }

        return utf8BOMString + lines.joined(separator: lineEnding) + lineEnding
    }

    public static func exportData(
        drinks: [Drink],
        presetKeyById: [UUID: String] = [:],
        nameResolver: ((_ presetKey: String?, _ storedName: String) -> String)? = nil
    ) -> Data {
        Data(exportString(drinks: drinks, presetKeyById: presetKeyById, nameResolver: nameResolver).utf8)
    }

    public static func sanitizeTextFieldForSpreadsheetFormulaInjection(_ value: String) -> String {
        guard let first = value.first else {
            return value
        }
        if first == "=" || first == "+" || first == "-" || first == "@" || first == "\t" || first == "\r" {
            return "'" + value
        }
        return value
    }

    public static func escapeField(_ value: String) -> String {
        let needsQuoting = value.contains { character in
            character == "," || character == "\"" || character == "\n" || character == "\r"
        }
        guard needsQuoting else {
            return value
        }
        let escapedQuotes = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedQuotes)\""
    }

    public static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    public static func formatLogicalDay(_ day: LogicalDay) -> String {
        String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
    }

    public static func formatLocalDateAndTime(
        timestamp: Date,
        timeZone: TimeZone
    ) -> (date: String, time: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: timestamp
        )
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let dateString = String(format: "%04d-%02d-%02d", year, month, day)
        let timeString = String(format: "%02d:%02d", hour, minute)
        return (dateString, timeString)
    }

    private static func rowFields(
        for drink: Drink,
        presetKeyById: [UUID: String],
        nameResolver: ((_ presetKey: String?, _ storedName: String) -> String)? = nil
    ) -> [String] {
        let (dateString, timeString) = formatLocalDateAndTime(
            timestamp: drink.timestamp,
            timeZone: drink.timeZone
        )
        let logicalDayString = formatLogicalDay(drink.logicalDay)
        let resolvedPresetKey = drink.presetId.flatMap { presetKeyById[$0] }
        let presetKeyColumn = resolvedPresetKey ?? ""
        let resolvedName = nameResolver?(resolvedPresetKey, drink.name) ?? drink.name
        let sanitizedName = sanitizeTextFieldForSpreadsheetFormulaInjection(resolvedName)
        let huString = formatDecimal(drink.hu)
        let gramsString = formatDecimal(drink.grams)
        let standardDrinksString = formatDecimal(Units.standardDrinks(grams: drink.grams))
        let volumeString = drink.volumeMl.map(String.init) ?? ""
        let abvString = drink.abvPercent.map(formatDecimal) ?? ""
        let noteString = drink.note ?? ""
        let sanitizedNote = sanitizeTextFieldForSpreadsheetFormulaInjection(noteString)

        return [
            dateString,
            timeString,
            logicalDayString,
            sanitizedName,
            presetKeyColumn,
            huString,
            gramsString,
            standardDrinksString,
            volumeString,
            abvString,
            sanitizedNote,
            drink.sourceRaw,
            drink.timeZoneIdentifier,
            drink.id.uuidString,
        ]
    }
}
