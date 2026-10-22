import Foundation
import SwiftData
import Testing

@testable import HalfUnitCore

@Suite("Model & Domain Conversion Tests")
@MainActor
struct ModelTests {
    private static func dec(_ string: String) -> Decimal {
        guard let value = Decimal(string: string) else {
            preconditionFailure("Invalid decimal string: \(string)")
        }
        return value
    }

    private static let fixedDate = Date(timeIntervalSince1970: 1_760_000_000)

    @Test(
        "Drink and Preset HU integer storage round-trip is exact",
        arguments: [
            ("0.5", 1),
            ("1", 2),
            ("1.5", 3),
            ("4", 8),
        ]
    )
    func huRoundTrip(huString: String, expectedHalfSteps: Int) {
        let expectedHU = Self.dec(huString)
        let drink = Drink(
            timestamp: Self.fixedDate,
            timeZoneIdentifier: "Europe/Berlin",
            logicalDayKey: 20_261_022,
            name: "Test",
            huHalfSteps: 1,
            centigrams: 1000,
            createdAt: Self.fixedDate,
            updatedAt: Self.fixedDate
        )
        drink.hu = expectedHU
        #expect(drink.huHalfSteps == expectedHalfSteps)
        #expect(drink.hu == expectedHU)

        let preset = Preset(
            name: "Preset",
            symbolName: "mug",
            huHalfSteps: 1,
            volumeMl: 330,
            abvTenths: 50,
            updatedAt: Self.fixedDate
        )
        preset.hu = expectedHU
        #expect(preset.huHalfSteps == expectedHalfSteps)
        #expect(preset.hu == expectedHU)
    }

    @Test(
        "Drink grams integer storage (centigrams) round-trip is exact",
        arguments: [
            ("19.2", 1920),
            ("25.6", 2560),
            ("13.2", 1320),
            ("12.8", 1280),
            ("20", 2000),
        ]
    )
    func gramsRoundTrip(gramsString: String, expectedCentigrams: Int) {
        let expectedGrams = Self.dec(gramsString)
        let drink = Drink(
            timestamp: Self.fixedDate,
            timeZoneIdentifier: "Europe/Berlin",
            logicalDayKey: 20_261_022,
            name: "Wine",
            huHalfSteps: 2,
            centigrams: 0,
            createdAt: Self.fixedDate,
            updatedAt: Self.fixedDate
        )
        drink.grams = expectedGrams
        #expect(drink.centigrams == expectedCentigrams)
        #expect(drink.grams == expectedGrams)
    }

    @Test(
        "Drink and Preset ABV integer storage (tenths) round-trip is exact",
        arguments: [
            ("4.9", 49),
            ("5", 50),
            ("12", 120),
            ("40", 400),
        ]
    )
    func abvRoundTrip(abvString: String, expectedTenths: Int) {
        let expectedABV = Self.dec(abvString)
        let drink = Drink(
            timestamp: Self.fixedDate,
            timeZoneIdentifier: "Europe/Berlin",
            logicalDayKey: 20_261_022,
            name: "Pils",
            huHalfSteps: 2,
            centigrams: 1960,
            createdAt: Self.fixedDate,
            updatedAt: Self.fixedDate
        )
        drink.abvPercent = expectedABV
        #expect(drink.abvTenths == expectedTenths)
        #expect(drink.abvPercent == expectedABV)

        drink.abvPercent = nil
        #expect(drink.abvTenths == nil)
        #expect(drink.abvPercent == nil)

        let preset = Preset(
            name: "Pils",
            symbolName: "mug",
            huHalfSteps: 2,
            volumeMl: 500,
            abvTenths: 0,
            updatedAt: Self.fixedDate
        )
        preset.abvPercent = expectedABV
        #expect(preset.abvTenths == expectedTenths)
        #expect(preset.abvPercent == expectedABV)
    }

    @Test("Preset computed grams uses Units.grams and matches 19.2 g and 25.6 g")
    func presetComputedGrams() {
        let wineGlass = Preset(
            key: "wineGlass",
            name: "wineGlass",
            symbolName: "wineglass.fill",
            huHalfSteps: 2,
            volumeMl: 200,
            abvTenths: 120,
            updatedAt: Self.fixedDate
        )
        #expect(wineGlass.grams == Self.dec("19.2"))

        let longDrink = Preset(
            key: "longDrink",
            name: "longDrink",
            symbolName: "takeoutbag.and.cup.and.straw.fill",
            huHalfSteps: 4,
            volumeMl: 80,
            abvTenths: 400,
            updatedAt: Self.fixedDate
        )
        #expect(longDrink.grams == Self.dec("25.6"))
    }

    @Test("Fallback behavior for unknown sourceRaw, unknown timeZoneIdentifier, and unknown displayUnitRaw")
    func fallbacksAndSnapshots() {
        let drink = Drink(
            timestamp: Self.fixedDate,
            timeZoneIdentifier: "Invalid/Zone_Name",
            logicalDayKey: 20_261_022,
            name: "Beer",
            huHalfSteps: 2,
            centigrams: 2000,
            sourceRaw: "unknown_future_source",
            createdAt: Self.fixedDate,
            updatedAt: Self.fixedDate
        )

        #expect(drink.source == .phone)
        #expect(drink.timeZone == TimeZone(identifier: "UTC"))
        #expect(drink.logicalDay == LogicalDay(year: 2026, month: 10, day: 22))

        let plainSnapshot = drink.snapshot()
        #expect(plainSnapshot.presetKey == nil)
        #expect(plainSnapshot.hu == Decimal(1))
        #expect(plainSnapshot.grams == Decimal(20))
        #expect(plainSnapshot.logicalDay == LogicalDay(year: 2026, month: 10, day: 22))

        let keyedSnapshot = drink.snapshot(presetKey: "beer")
        #expect(keyedSnapshot.presetKey == "beer")

        let settings = AppSettings(
            dayBoundaryHour: 7,
            displayUnitRaw: "unknown_unit",
            firstUseDayKey: 20_261_001,
            updatedAt: Self.fixedDate
        )
        #expect(settings.displayUnit == .hu)
        #expect(settings.firstUseDay == LogicalDay(year: 2026, month: 10, day: 1))

        settings.displayUnit = .ukUnits
        #expect(settings.displayUnitRaw == DisplayUnit.ukUnits.rawValue)
        #expect(settings.displayUnit == .ukUnits)
    }

    @Test("ModelContainerFactory creates functional in-memory container with SchemaV1")
    func inMemoryContainerPersistence() throws {
        let container = try ModelContainerFactory.make(
            storeURL: nil,
            cloudKitContainerIdentifier: nil,
            inMemory: true
        )
        let context = container.mainContext

        let drink = Drink(
            timestamp: Self.fixedDate,
            timeZoneIdentifier: "Europe/Berlin",
            logicalDayKey: 20_261_022,
            name: "Wine",
            huHalfSteps: 2,
            volumeMl: 200,
            abvTenths: 120,
            centigrams: 1920,
            createdAt: Self.fixedDate,
            updatedAt: Self.fixedDate
        )
        context.insert(drink)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Drink>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.grams == Self.dec("19.2"))
    }
}
