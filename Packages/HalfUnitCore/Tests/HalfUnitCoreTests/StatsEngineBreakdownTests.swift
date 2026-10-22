import Foundation
import Testing

@testable import HalfUnitCore

@Suite("StatsEngine Breakdown Tests")
struct StatsEngineBreakdownTests {
    @Test("dailyTotals zero-fills alcohol-free tracked days in oldest-first order and clips to tracked history")
    func dailyTotalsZeroFillAndOrder() {
        let today = LogicalDay(year: 2026, month: 10, day: 10)
        // First use on Oct 7 -> only 4 tracked days in a 7-day period (Oct 7, 8, 9, 10)
        let firstUse = LogicalDay(year: 2026, month: 10, day: 7)
        let oct8 = LogicalDay(year: 2026, month: 10, day: 8)
        let oct10 = LogicalDay(year: 2026, month: 10, day: 10)

        let drinks = [
            SyntheticDrinks.drink(index: 1, on: oct8, hu: Decimal(1), grams: Decimal(20)),
            SyntheticDrinks.drink(
                index: 2,
                on: oct8,
                hu: Decimal(sign: .plus, exponent: -1, significand: 5),
                grams: Decimal(10)
            ),
            SyntheticDrinks.drink(index: 3, on: oct10, hu: Decimal(2), grams: Decimal(26)),
        ]

        let engine = StatsEngine(drinks: drinks, firstUseDay: firstUse, today: today)
        let daily = engine.dailyTotals(for: .last7Days)

        #expect(daily.count == 4)
        #expect(
            daily == [
                DayTotal(
                    day: LogicalDay(year: 2026, month: 10, day: 7), drinkCount: 0, hu: Decimal(0), grams: Decimal(0)),
                DayTotal(
                    day: oct8,
                    drinkCount: 2,
                    hu: Decimal(string: "1.5")!,
                    grams: Decimal(30)
                ),
                DayTotal(
                    day: LogicalDay(year: 2026, month: 10, day: 9), drinkCount: 0, hu: Decimal(0), grams: Decimal(0)),
                DayTotal(day: oct10, drinkCount: 1, hu: Decimal(2), grams: Decimal(26)),
            ]
        )
    }

    @Test("weeklyTotals week boundaries for Monday and Sunday starts, summing only tracked days inside range")
    func weeklyTotalsMondayAndSundayStarts() {
        // Range: Wed 2026-10-14 through Thu 2026-10-22 (9 days)
        let start = LogicalDay(year: 2026, month: 10, day: 14)  // Wednesday
        let end = LogicalDay(year: 2026, month: 10, day: 22)  // Thursday
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)

        // Drink BEFORE range on Tue Oct 13 (same Monday-week as Oct 14, but outside range -> must NOT be summed)
        let dOutsideBefore = SyntheticDrinks.drink(
            index: 1,
            on: LogicalDay(year: 2026, month: 10, day: 13),
            hu: Decimal(5),
            grams: Decimal(100)
        )
        // Drink on Fri Oct 16 (1 HU, 20 g)
        let dFri = SyntheticDrinks.drink(
            index: 2,
            on: LogicalDay(year: 2026, month: 10, day: 16),
            hu: Decimal(1),
            grams: Decimal(20)
        )
        // Drink on Sun Oct 18 (2 HU, 40 g)
        let dSun = SyntheticDrinks.drink(
            index: 3,
            on: LogicalDay(year: 2026, month: 10, day: 18),
            hu: Decimal(2),
            grams: Decimal(40)
        )
        // Drink on Wed Oct 21 (1.5 HU, 30 g)
        let dWed = SyntheticDrinks.drink(
            index: 4,
            on: LogicalDay(year: 2026, month: 10, day: 21),
            hu: Decimal(string: "1.5")!,
            grams: Decimal(30)
        )

        let engine = StatsEngine(
            drinks: [dOutsideBefore, dFri, dSun, dWed],
            firstUseDay: firstUse,
            today: end
        )
        let period = Period.custom(from: start, through: end)

        // 1. Monday week start:
        // Week 1 starts Mon Oct 12 (covers Oct 12..18; in range: Oct 14..18 -> Fri Oct 16 + Sun Oct 18 = 2 drinking days, 3 HU, 60 g)
        // Week 2 starts Mon Oct 19 (covers Oct 19..25; in range: Oct 19..22 -> Wed Oct 21 = 1 drinking day, 1.5 HU, 30 g)
        let mondayWeeks = engine.weeklyTotals(for: period, weekStartsOn: .monday)
        #expect(
            mondayWeeks == [
                WeekTotal(
                    weekStart: LogicalDay(year: 2026, month: 10, day: 12),
                    hu: Decimal(3),
                    grams: Decimal(60),
                    drinkingDays: 2
                ),
                WeekTotal(
                    weekStart: LogicalDay(year: 2026, month: 10, day: 19),
                    hu: Decimal(string: "1.5")!,
                    grams: Decimal(30),
                    drinkingDays: 1
                ),
            ]
        )

        // 2. Sunday week start:
        // Week 1 starts Sun Oct 11 (covers Oct 11..17; in range: Oct 14..17 -> Fri Oct 16 = 1 drinking day, 1 HU, 20 g)
        // Week 2 starts Sun Oct 18 (covers Oct 18..24; in range: Oct 18..22 -> Sun Oct 18 + Wed Oct 21 = 2 drinking days, 3.5 HU, 70 g)
        let sundayWeeks = engine.weeklyTotals(for: period, weekStartsOn: .sunday)
        #expect(
            sundayWeeks == [
                WeekTotal(
                    weekStart: LogicalDay(year: 2026, month: 10, day: 11),
                    hu: Decimal(1),
                    grams: Decimal(20),
                    drinkingDays: 1
                ),
                WeekTotal(
                    weekStart: LogicalDay(year: 2026, month: 10, day: 18),
                    hu: Decimal(string: "3.5")!,
                    grams: Decimal(70),
                    drinkingDays: 2
                ),
            ]
        )
    }

    @Test(
        "drinkTypeBreakdown groups by presetKey or custom name, uses latest drink name, and sorts by HU desc then name asc"
    )
    func drinkTypeBreakdownGroupingAndSorting() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)
        let today = LogicalDay(year: 2026, month: 10, day: 10)

        // Preset "beer" renamed over time: older drink named "Pils", newer drink named "Helles" -> group name must be "Helles"
        // Total HU = 1 + 1 = 2 HU
        let beerOld = SyntheticDrinks.drink(
            index: 1,
            on: LogicalDay(year: 2026, month: 10, day: 5),
            hour: 19,
            presetKey: "beer",
            name: "Pils",
            hu: Decimal(1),
            grams: Decimal(20)
        )
        let beerNew = SyntheticDrinks.drink(
            index: 2,
            on: LogicalDay(year: 2026, month: 10, day: 8),
            hour: 21,
            presetKey: "beer",
            name: "Helles",
            hu: Decimal(1),
            grams: Decimal(20)
        )

        // Two custom drinks (presetKey == nil) with same name "Craft IPA" -> grouped together, total HU = 1.5 + 1.5 = 3 HU
        let customIPA1 = SyntheticDrinks.drink(
            index: 3,
            on: LogicalDay(year: 2026, month: 10, day: 6),
            presetKey: nil,
            name: "Craft IPA",
            hu: Decimal(string: "1.5")!,
            grams: Decimal(25)
        )
        let customIPA2 = SyntheticDrinks.drink(
            index: 4,
            on: LogicalDay(year: 2026, month: 10, day: 7),
            presetKey: nil,
            name: "Craft IPA",
            hu: Decimal(string: "1.5")!,
            grams: Decimal(25)
        )

        // Another custom drink with 2 HU named "Aperol Spritz" -> ties with "Helles" (2 HU), sorted alphabetically before "Helles"
        let customAperol = SyntheticDrinks.drink(
            index: 5,
            on: LogicalDay(year: 2026, month: 10, day: 9),
            presetKey: nil,
            name: "Aperol Spritz",
            hu: Decimal(2),
            grams: Decimal(18)
        )

        let engine = StatsEngine(
            drinks: [beerOld, beerNew, customIPA1, customIPA2, customAperol],
            firstUseDay: firstUse,
            today: today
        )
        let breakdown = engine.drinkTypeBreakdown(for: .last7Days)

        #expect(
            breakdown == [
                DrinkTypeTotal(
                    presetKey: nil,
                    name: "Craft IPA",
                    drinkCount: 2,
                    hu: Decimal(3),
                    grams: Decimal(50)
                ),
                DrinkTypeTotal(
                    presetKey: nil,
                    name: "Aperol Spritz",
                    drinkCount: 1,
                    hu: Decimal(2),
                    grams: Decimal(18)
                ),
                DrinkTypeTotal(
                    presetKey: "beer",
                    name: "Helles",
                    drinkCount: 2,
                    hu: Decimal(2),
                    grams: Decimal(40)
                ),
            ]
        )
    }

    @Test(
        "weekdayBreakdown returns Monday..Sunday, counts drinking days not individual drinks, and handles 0 drinking days"
    )
    func weekdayBreakdownCountsDrinkingDaysNotDrinks() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)
        let today = LogicalDay(year: 2026, month: 10, day: 22)

        // Friday Oct 16 has 3 drinks (still 1 drinking day)
        // Friday Oct 9 has 1 drink (2nd Friday drinking day)
        // Saturday Oct 17 has 2 drinks (1 Saturday drinking day)
        // Total drinking days in 30d = 3 (2 Fridays, 1 Saturday)
        let fri1 = LogicalDay(year: 2026, month: 10, day: 9)
        let fri2 = LogicalDay(year: 2026, month: 10, day: 16)
        let sat = LogicalDay(year: 2026, month: 10, day: 17)

        let drinks = [
            SyntheticDrinks.drink(index: 1, on: fri1),
            SyntheticDrinks.drink(index: 2, on: fri2, hour: 19),
            SyntheticDrinks.drink(index: 3, on: fri2, hour: 20),
            SyntheticDrinks.drink(index: 4, on: fri2, hour: 21),
            SyntheticDrinks.drink(index: 5, on: sat, hour: 20),
            SyntheticDrinks.drink(index: 6, on: sat, hour: 22),
        ]

        let engine = StatsEngine(drinks: drinks, firstUseDay: firstUse, today: today)
        let weekdays = engine.weekdayBreakdown(for: .last30Days)

        #expect(weekdays.map(\.weekday) == [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])
        #expect(weekdays[0] == WeekdayTotal(weekday: .monday, drinkingDays: 0, shareOfDrinkingDays: Decimal(0)))
        #expect(
            weekdays[4] == WeekdayTotal(weekday: .friday, drinkingDays: 2, shareOfDrinkingDays: Decimal(2) / Decimal(3))
        )
        #expect(
            weekdays[5]
                == WeekdayTotal(weekday: .saturday, drinkingDays: 1, shareOfDrinkingDays: Decimal(1) / Decimal(3)))
        #expect(weekdays[6] == WeekdayTotal(weekday: .sunday, drinkingDays: 0, shareOfDrinkingDays: Decimal(0)))

        // Empty engine -> shareOfDrinkingDays is nil for all 7 weekdays
        let emptyEngine = StatsEngine(drinks: [], firstUseDay: firstUse, today: today)
        let emptyWeekdays = emptyEngine.weekdayBreakdown(for: .last7Days)
        #expect(emptyWeekdays.count == 7)
        for entry in emptyWeekdays {
            #expect(entry.drinkingDays == 0)
            #expect(entry.shareOfDrinkingDays == nil)
        }
    }

    @Test("heaviestDay tie-breaks by highest HU, then highest grams, then most recent day")
    func heaviestDayTieBreaking() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)
        let today = LogicalDay(year: 2026, month: 10, day: 10)

        let oct5 = LogicalDay(year: 2026, month: 10, day: 5)
        let oct6 = LogicalDay(year: 2026, month: 10, day: 6)
        let oct7 = LogicalDay(year: 2026, month: 10, day: 7)
        let oct8 = LogicalDay(year: 2026, month: 10, day: 8)

        // Oct 5: 1.5 HU, 35 g (lower HU)
        // Oct 6: 2.0 HU, 26 g (tied HU, lower grams)
        // Oct 7: 2.0 HU, 40 g (tied HU, highest grams, older day)
        // Oct 8: 2.0 HU, 40 g (tied HU, highest grams, more recent day -> winner!)
        let d5 = SyntheticDrinks.drink(index: 1, on: oct5, hu: Decimal(string: "1.5")!, grams: Decimal(35))
        let d6 = SyntheticDrinks.drink(index: 2, on: oct6, hu: Decimal(2), grams: Decimal(26))
        let d7 = SyntheticDrinks.drink(index: 3, on: oct7, hu: Decimal(2), grams: Decimal(40))
        let d8 = SyntheticDrinks.drink(index: 4, on: oct8, hu: Decimal(2), grams: Decimal(40))

        // First check tie-break by grams (without oct8): oct7 beats oct6 because 40 g > 26 g
        let engineGramsTieBreak = StatsEngine(drinks: [d5, d6, d7], firstUseDay: firstUse, today: today)
        let statsGramsTieBreak = engineGramsTieBreak.stats(for: .last7Days)
        #expect(
            statsGramsTieBreak.heaviestDay == DayTotal(day: oct7, drinkCount: 1, hu: Decimal(2), grams: Decimal(40)))

        // Next check tie-break by most recent day (with oct8): oct8 beats oct7 because oct8 > oct7
        let engineDateTieBreak = StatsEngine(drinks: [d5, d6, d7, d8], firstUseDay: firstUse, today: today)
        let statsDateTieBreak = engineDateTieBreak.stats(for: .last7Days)
        #expect(statsDateTieBreak.heaviestDay == DayTotal(day: oct8, drinkCount: 1, hu: Decimal(2), grams: Decimal(40)))
    }
}
