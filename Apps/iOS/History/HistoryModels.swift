import Foundation
import HalfUnitCore

struct HistoryPresetOption: Identifiable, Equatable, Sendable {
    let id: UUID
    let key: String?
    let name: String
    let localizedName: String
    let symbolName: String
    let hu: Decimal
    let volumeMl: Int
    let abvPercent: Decimal
}

struct HistoryDrinkItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let presetId: UUID?
    let presetKey: String?
    let rawName: String
    let localizedName: String
    let symbolName: String
    let timestamp: Date
    let timeZone: TimeZone
    let logicalDay: LogicalDay
    let timeText: String
    let hu: Decimal
    let grams: Decimal
    let volumeMl: Int?
    let abvPercent: Decimal?
    let note: String?
    let primaryAmountText: String
    let gramsText: String
    let accessibilityLabel: String
    let deleteAccessibilityLabel: String

    init(
        id: UUID,
        presetId: UUID?,
        presetKey: String?,
        rawName: String,
        symbolName: String?,
        timestamp: Date,
        timeZone: TimeZone,
        logicalDay: LogicalDay,
        hu: Decimal,
        grams: Decimal,
        volumeMl: Int?,
        abvPercent: Decimal?,
        note: String?,
        displayUnit: DisplayUnit,
        locale: Locale = .current
    ) {
        self.id = id
        self.presetId = presetId
        self.presetKey = presetKey
        self.rawName = rawName
        let localized = PresetPresentation.localizedName(
            presetKey: presetKey,
            fallbackName: rawName,
            locale: locale
        )
        self.localizedName = localized
        self.symbolName = PresetPresentation.symbolName(
            presetKey: presetKey,
            fallbackSymbol: symbolName ?? "wineglass"
        )
        self.timestamp = timestamp
        self.timeZone = timeZone
        self.logicalDay = logicalDay
        let timeText = TodayDrinkRowModel.formatTime(
            timestamp,
            timeZone: timeZone,
            locale: locale
        )
        self.timeText = timeText
        self.hu = hu
        self.grams = grams
        self.volumeMl = volumeMl
        self.abvPercent = abvPercent
        self.note = note

        let primaryAmount = AmountFormatting.formattedValue(
            grams: grams,
            hu: hu,
            in: displayUnit,
            locale: locale
        )
        self.primaryAmountText = primaryAmount
        self.gramsText = AmountFormatting.formattedGrams(grams, locale: locale)

        let rowFormat = AppLocalization.string("history.row.accessibility", locale: locale)
        self.accessibilityLabel = String(
            format: rowFormat,
            locale: locale,
            localized,
            timeText,
            primaryAmount
        )

        let deleteFormat = AppLocalization.string("history.delete.accessibility", locale: locale)
        self.deleteAccessibilityLabel = String(format: deleteFormat, locale: locale, localized)
    }

    func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return true
        }
        if localizedName.localizedStandardContains(trimmed) {
            return true
        }
        if rawName.localizedStandardContains(trimmed) {
            return true
        }
        if let note, note.localizedStandardContains(trimmed) {
            return true
        }
        return false
    }
}

struct HistoryDaySection: Identifiable, Equatable, Sendable {
    let day: LogicalDay
    let title: String
    let totalHU: Decimal
    let totalGrams: Decimal
    let totalDisplayText: String
    let items: [HistoryDrinkItem]

    var id: Int { day.key }
}

struct HistoryScreenSnapshot: Equatable, Sendable {
    let isEmptyStore: Bool
    let isSearchEmpty: Bool
    let displayUnit: DisplayUnit
    let sections: [HistoryDaySection]
    let presetOptions: [HistoryPresetOption]

    init(
        items: [HistoryDrinkItem],
        presetOptions: [HistoryPresetOption] = [],
        searchQuery: String = "",
        displayUnit: DisplayUnit,
        locale: Locale = .current
    ) {
        self.isEmptyStore = items.isEmpty
        self.displayUnit = displayUnit
        self.presetOptions = presetOptions

        let filtered = items.filter { $0.matches(query: searchQuery) }
        self.isSearchEmpty = !items.isEmpty && filtered.isEmpty
        self.sections = Self.groupIntoSections(
            items: filtered,
            displayUnit: displayUnit,
            locale: locale
        )
    }

    @MainActor
    static func load(
        from logService: LogService,
        searchQuery: String = "",
        locale: Locale = .current
    ) throws -> HistoryScreenSnapshot {
        let currentSettings = try logService.settings()
        let displayUnit = currentSettings.displayUnit

        let presets = try logService.presets()
        var presetById: [UUID: Preset] = [:]
        var presetOptions: [HistoryPresetOption] = []
        presetOptions.reserveCapacity(presets.count)

        for preset in presets {
            presetById[preset.id] = preset
            presetOptions.append(
                HistoryPresetOption(
                    id: preset.id,
                    key: preset.key,
                    name: preset.name,
                    localizedName: PresetPresentation.localizedName(for: preset, locale: locale),
                    symbolName: PresetPresentation.symbolName(for: preset),
                    hu: preset.hu,
                    volumeMl: preset.volumeMl,
                    abvPercent: preset.abvPercent
                )
            )
        }

        let drinks = try logService.drinks(includeDeleted: false)
        var items: [HistoryDrinkItem] = []
        items.reserveCapacity(drinks.count)

        for drink in drinks {
            let matchedPreset = drink.presetId.flatMap { presetById[$0] }
            items.append(
                HistoryDrinkItem(
                    id: drink.id,
                    presetId: drink.presetId,
                    presetKey: matchedPreset?.key,
                    rawName: drink.name,
                    symbolName: matchedPreset?.symbolName,
                    timestamp: drink.timestamp,
                    timeZone: drink.timeZone,
                    logicalDay: drink.logicalDay,
                    hu: drink.hu,
                    grams: drink.grams,
                    volumeMl: drink.volumeMl,
                    abvPercent: drink.abvPercent,
                    note: drink.note,
                    displayUnit: displayUnit,
                    locale: locale
                )
            )
        }

        return HistoryScreenSnapshot(
            items: items,
            presetOptions: presetOptions,
            searchQuery: searchQuery,
            displayUnit: displayUnit,
            locale: locale
        )
    }

    static func groupIntoSections(
        items: [HistoryDrinkItem],
        displayUnit: DisplayUnit,
        locale: Locale = .current
    ) -> [HistoryDaySection] {
        let sortedItems = items.sorted { lhs, rhs in
            if lhs.logicalDay != rhs.logicalDay {
                return lhs.logicalDay > rhs.logicalDay
            }
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp > rhs.timestamp
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }

        var groupedByDay: [LogicalDay: [HistoryDrinkItem]] = [:]
        var orderedDays: [LogicalDay] = []

        for item in sortedItems {
            if groupedByDay[item.logicalDay] == nil {
                orderedDays.append(item.logicalDay)
                groupedByDay[item.logicalDay] = [item]
            } else {
                groupedByDay[item.logicalDay]?.append(item)
            }
        }

        return orderedDays.map { day in
            let dayItems = groupedByDay[day] ?? []
            var totalHU = Decimal(0)
            var totalGrams = Decimal(0)
            for item in dayItems {
                totalHU += item.hu
                totalGrams += item.grams
            }

            let title = StreakCardModel.formatLogicalDay(day, locale: locale)
            let formattedAmount = AmountFormatting.formattedValue(
                grams: totalGrams,
                hu: totalHU,
                in: displayUnit,
                locale: locale
            )
            let totalFormat = AppLocalization.string("history.section.total", locale: locale)
            let totalDisplayText = String(format: totalFormat, locale: locale, formattedAmount)

            return HistoryDaySection(
                day: day,
                title: title,
                totalHU: totalHU,
                totalGrams: totalGrams,
                totalDisplayText: totalDisplayText,
                items: dayItems
            )
        }
    }
}

struct HistoryDrinkEditDraft: Equatable, Sendable {
    private let originalItem: HistoryDrinkItem

    var timestamp: Date
    var selectedPresetId: UUID?
    var huHalfSteps: Int
    var volumeMlText: String
    var abvPercentText: String
    var noteText: String

    init(item: HistoryDrinkItem, locale: Locale = .current) {
        self.originalItem = item
        self.timestamp = item.timestamp
        self.selectedPresetId = item.presetId
        self.huHalfSteps = Self.halfSteps(from: item.hu)
        self.volumeMlText = item.volumeMl.map(String.init) ?? ""
        self.abvPercentText = Self.formatDecimalField(item.abvPercent, locale: locale)
        self.noteText = item.note ?? ""
    }

    var hu: Decimal {
        Self.hu(fromHalfSteps: huHalfSteps)
    }

    mutating func stepHU(by deltaHalfSteps: Int) {
        huHalfSteps = max(1, huHalfSteps + deltaHalfSteps)
    }

    mutating func applyPreset(_ preset: HistoryPresetOption, locale: Locale = .current) {
        selectedPresetId = preset.id
        huHalfSteps = Self.halfSteps(from: preset.hu)
        volumeMlText = String(preset.volumeMl)
        abvPercentText = Self.formatDecimalField(preset.abvPercent, locale: locale)
    }

    var parsedVolumeMl: Int? {
        let trimmed = volumeMlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), value > 0 else {
            return nil
        }
        return value
    }

    var parsedAbvPercent: Decimal? {
        let trimmed = abvPercentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized), !value.isNaN, value > Decimal(0) else {
            return nil
        }
        return value
    }

    func buildDrinkEdit(presets: [HistoryPresetOption]) -> DrinkEdit {
        let presetChanged = selectedPresetId != originalItem.presetId
        let newPreset =
            presetChanged
            ? presets.first(where: { $0.id == selectedPresetId })
            : nil

        let timestampEdit: Date? = (timestamp != originalItem.timestamp) ? timestamp : nil

        let baseHU = newPreset?.hu ?? originalItem.hu
        let huEdit: Decimal? = (hu != baseHU) ? hu : nil

        let baseVolume = newPreset.map { Optional($0.volumeMl) } ?? originalItem.volumeMl
        let currentVolume = parsedVolumeMl
        let volumeEdit: DrinkEdit.NullableField<Int> =
            if currentVolume == baseVolume {
                .unchanged
            } else if let currentVolume {
                .set(currentVolume)
            } else {
                .clear
            }

        let baseAbv = newPreset.map { Optional($0.abvPercent) } ?? originalItem.abvPercent
        let currentAbv = parsedAbvPercent
        let abvEdit: DrinkEdit.NullableField<Decimal> =
            if currentAbv == baseAbv {
                .unchanged
            } else if let currentAbv {
                .set(currentAbv)
            } else {
                .clear
            }

        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentNote: String? = trimmedNote.isEmpty ? nil : trimmedNote
        let noteEdit: DrinkEdit.NullableField<String> =
            if currentNote == originalItem.note {
                .unchanged
            } else if let currentNote {
                .set(currentNote)
            } else {
                .clear
            }

        return DrinkEdit(
            timestamp: timestampEdit,
            presetId: newPreset?.id,
            name: nil,
            hu: huEdit,
            volumeMl: volumeEdit,
            abvPercent: abvEdit,
            note: noteEdit
        )
    }

    private static func halfSteps(from hu: Decimal) -> Int {
        var scaled = hu * Decimal(2)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return max(1, NSDecimalNumber(decimal: rounded).intValue)
    }

    private static func hu(fromHalfSteps halfSteps: Int) -> Decimal {
        let clamped = max(1, halfSteps)
        return Decimal(
            sign: .plus,
            exponent: -1,
            significand: Decimal(clamped) * Decimal(5)
        )
    }

    private static func formatDecimalField(_ value: Decimal?, locale: Locale) -> String {
        guard let value else {
            return ""
        }
        return value.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(0...1))
        )
    }
}
