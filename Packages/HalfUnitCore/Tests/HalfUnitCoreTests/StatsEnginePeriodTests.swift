import Foundation
import Testing

@testable import HalfUnitCore

@Suite("StatsEngine Period Tests")
struct StatsEnginePeriodTests {
    @Test(
        "PRODUCT.md acceptance: Insights for 7d / 30d / 3m / 12m / 2y show exact drinking-day counts against 850-day seeded dataset"
    )
    func fixedPeriodsAgainst850DaySeededDataset() {
        let fixture = SyntheticDrinks.make850DayDataset()
        let engine = StatsEngine(
            drinks: fixture.drinks,
            firstUseDay: fixture.firstUseDay,
            today: fixture.today
        )

        // 1. 7 days (2026-10-16 .. 2026-10-22):
        // Contains 1 Friday (Oct 16) + 1 Saturday (Oct 17) = 2 drinking days.
        // (Extra drink at -6 is Fri Oct 16, already a Friday; extra drink at -7 is Thu Oct 15, just outside 7d.)
        let stats7d = engine.stats(for: .last7Days)
        #expect(stats7d.range == fixture.today.adding(days: -6)...fixture.today)
        #expect(stats7d.lengthDays == 7)
        #expect(stats7d.trackedDays == 7)
        #expect(stats7d.drinkingDays == 2)
        #expect(stats7d.alcoholFreeDays == 5)
        #expect(stats7d.drinkingDayShare == Decimal(2) / Decimal(7))
        #expect(stats7d.totalHU == Decimal(3))
        #expect(stats7d.totalGrams == Decimal(string: "58.4")!)
        #expect(stats7d.averageHUPerDrinkingDay == Decimal(3) / Decimal(2))
        #expect(stats7d.heaviestDay?.day == LogicalDay(year: 2026, month: 10, day: 17))
        #expect(stats7d.heaviestDay?.hu == Decimal(2))

        // 2. 30 days (2026-09-23 .. 2026-10-22):
        // 4 Fridays + 4 Saturdays + 2 non-Fri/Sat extra days (-29 Wed Sep 23, -7 Thu Oct 15) = 10 drinking days.
        // (-30 Tue Sep 22 is just outside 30d.)
        let stats30d = engine.stats(for: .last30Days)
        #expect(stats30d.lengthDays == 30)
        #expect(stats30d.trackedDays == 30)
        #expect(stats30d.drinkingDays == 10)
        #expect(stats30d.alcoholFreeDays == 20)
        #expect(stats30d.drinkingDayShare == Decimal(10) / Decimal(30))
        #expect(stats30d.totalHU == Decimal(13))
        #expect(stats30d.totalGrams == Decimal(260))
        #expect(stats30d.averageHUPerDrinkingDay == Decimal(13) / Decimal(10))

        // 3. 3 months / 91 days (2026-07-24 .. 2026-10-22):
        // 13 Fridays + 13 Saturdays + 3 non-Fri/Sat extra days (-30, -29, -7; -90 is Fri Jul 24; -91 is outside) = 29 drinking days.
        let stats3m = engine.stats(for: .last3Months)
        #expect(stats3m.lengthDays == 91)
        #expect(stats3m.trackedDays == 91)
        #expect(stats3m.drinkingDays == 29)
        #expect(stats3m.alcoholFreeDays == 62)
        #expect(stats3m.drinkingDayShare == Decimal(29) / Decimal(91))
        #expect(stats3m.totalHU == Decimal(string: "40.5")!)
        #expect(stats3m.totalGrams == Decimal(string: "798.8")!)
        #expect(stats3m.averageHUPerDrinkingDay == Decimal(string: "40.5")! / Decimal(29))

        // 4. 12 months / 365 days (2025-10-23 .. 2026-10-22):
        // 52 Fridays + 52 Saturdays + 5 non-Fri/Sat extra days (-364, -91, -30, -29, -7; -365 is outside) = 109 drinking days.
        let stats12m = engine.stats(for: .last12Months)
        #expect(stats12m.lengthDays == 365)
        #expect(stats12m.trackedDays == 365)
        #expect(stats12m.drinkingDays == 109)
        #expect(stats12m.alcoholFreeDays == 256)
        #expect(stats12m.drinkingDayShare == Decimal(109) / Decimal(365))
        #expect(stats12m.totalHU == Decimal(string: "158.5")!)
        #expect(stats12m.totalGrams == Decimal(string: "3102.8")!)
        #expect(stats12m.averageHUPerDrinkingDay == Decimal(string: "158.5")! / Decimal(109))

        // 5. 2 years / 730 days (2024-10-23 .. 2026-10-22):
        // 104 Fridays + 104 Saturdays + 7 non-Fri/Sat extra days (-729, -365, -364, -91, -30, -29, -7; -730 is outside) = 215 drinking days.
        let stats2y = engine.stats(for: .last2Years)
        #expect(stats2y.lengthDays == 730)
        #expect(stats2y.trackedDays == 730)
        #expect(stats2y.drinkingDays == 215)
        #expect(stats2y.alcoholFreeDays == 515)
        #expect(stats2y.drinkingDayShare == Decimal(215) / Decimal(730))
        #expect(stats2y.totalHU == Decimal(string: "315.5")!)
        #expect(stats2y.totalGrams == Decimal(6166))
        #expect(stats2y.averageHUPerDrinkingDay == Decimal(string: "315.5")! / Decimal(215))
    }

    @Test("Period longer than history reports x of n tracked days")
    func periodExceedingHistoryReportsTrackedDays() {
        let today = LogicalDay(year: 2026, month: 10, day: 22)
        // First use 39 days before today -> 40 tracked days inclusive
        let firstUse = today.adding(days: -39)

        // Add 18 drinking days within those 40 tracked days
        var drinks: [DrinkSnapshot] = []
        for index in 0..<18 {
            let day = firstUse.adding(days: index * 2)
            drinks.append(SyntheticDrinks.drink(index: index + 1, on: day))
        }

        let engine = StatsEngine(drinks: drinks, firstUseDay: firstUse, today: today)
        let stats3m = engine.stats(for: .last3Months)

        #expect(stats3m.lengthDays == 91)
        #expect(stats3m.trackedDays == 40)
        #expect(stats3m.drinkingDays == 18)
        #expect(stats3m.alcoholFreeDays == 22)
        #expect(stats3m.drinkingDayShare == Decimal(18) / Decimal(40))
    }

    @Test("Period with 0 drinking days returns nil averageHUPerDrinkingDay and nil heaviestDay")
    func zeroDrinkingDaysInPeriod() {
        let today = LogicalDay(year: 2026, month: 10, day: 22)
        let firstUse = today.adding(days: -10)
        let engine = StatsEngine(drinks: [], firstUseDay: firstUse, today: today)

        let stats = engine.stats(for: .last7Days)
        #expect(stats.trackedDays == 7)
        #expect(stats.drinkingDays == 0)
        #expect(stats.alcoholFreeDays == 7)
        #expect(stats.drinkingDayShare == Decimal(0))
        #expect(stats.totalHU == Decimal(0))
        #expect(stats.totalGrams == Decimal(0))
        #expect(stats.averageHUPerDrinkingDay == nil)
        #expect(stats.heaviestDay == nil)
    }

    @Test("Comparison: delta for 3m against previous 3m window")
    func comparisonForThreeMonths() {
        let fixture = SyntheticDrinks.make850DayDataset()
        let engine = StatsEngine(
            drinks: fixture.drinks,
            firstUseDay: fixture.firstUseDay,
            today: fixture.today
        )

        let comp = engine.comparison(for: .last3Months)
        // Current 3m: -90..0 -> 29 drinking days
        // Previous 3m: -181..-91 (91 days) -> 13 Fridays + 13 Saturdays + 1 extra day (-91 Thu Jul 23) = 27 drinking days
        #expect(comp.current.drinkingDays == 29)
        #expect(comp.previous.range == fixture.today.adding(days: -181)...fixture.today.adding(days: -91))
        #expect(comp.previous.lengthDays == 91)
        #expect(comp.previous.trackedDays == 91)
        #expect(comp.previous.drinkingDays == 27)
        #expect(comp.drinkingDaysDelta == 2)
    }

    @Test("Comparison: nil delta when previous window is completely untracked")
    func comparisonNilWhenPreviousWindowUntracked() {
        let today = LogicalDay(year: 2026, month: 10, day: 22)
        // Only 20 days of tracked history -> current 30d has 20 tracked days, previous 30d has 0 tracked days
        let firstUse = today.adding(days: -19)
        let drink = SyntheticDrinks.drink(index: 1, on: today.adding(days: -2))
        let engine = StatsEngine(drinks: [drink], firstUseDay: firstUse, today: today)

        let comp = engine.comparison(for: .last30Days)
        #expect(comp.current.trackedDays == 20)
        #expect(comp.current.drinkingDays == 1)
        #expect(comp.previous.trackedDays == 0)
        #expect(comp.previous.drinkingDayShare == nil)
        #expect(comp.drinkingDaysDelta == nil)
    }

    @Test("Custom period range and comparison")
    func customPeriodAndComparison() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)
        let today = LogicalDay(year: 2026, month: 10, day: 20)

        // Custom range: Oct 11 .. Oct 15 (5 days), previous range: Oct 6 .. Oct 10 (5 days)
        let dPrev1 = SyntheticDrinks.drink(index: 1, on: LogicalDay(year: 2026, month: 10, day: 6))
        let dPrev2 = SyntheticDrinks.drink(index: 2, on: LogicalDay(year: 2026, month: 10, day: 8))
        let dPrev3 = SyntheticDrinks.drink(index: 3, on: LogicalDay(year: 2026, month: 10, day: 10))
        let dCurr1 = SyntheticDrinks.drink(index: 4, on: LogicalDay(year: 2026, month: 10, day: 12))

        let engine = StatsEngine(
            drinks: [dPrev1, dPrev2, dPrev3, dCurr1],
            firstUseDay: firstUse,
            today: today
        )
        let customPeriod = Period.custom(
            from: LogicalDay(year: 2026, month: 10, day: 11),
            through: LogicalDay(year: 2026, month: 10, day: 15)
        )
        let comp = engine.comparison(for: customPeriod)

        #expect(comp.current.lengthDays == 5)
        #expect(comp.current.drinkingDays == 1)
        #expect(
            comp.previous.range == LogicalDay(
                year: 2026, month: 10, day: 6)...LogicalDay(year: 2026, month: 10, day: 10))
        #expect(comp.previous.drinkingDays == 3)
        #expect(comp.drinkingDaysDelta == -2)
    }
}
