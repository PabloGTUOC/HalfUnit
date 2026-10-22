import Foundation
import Testing

@testable import HalfUnitCore

@Suite("StatsEngine Streak Tests")
struct StatsEngineStreakTests {
    @Test("No drinks at all counts from effective first-use day including today")
    func noDrinksCountsFromFirstUse() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)
        let today = LogicalDay(year: 2026, month: 10, day: 10)
        let engine = StatsEngine(drinks: [], firstUseDay: firstUse, today: today)
        let streaks = engine.streaks()

        #expect(streaks.lastDrinkingDay == nil)
        #expect(streaks.lastDrink == nil)
        #expect(streaks.isDrinkingToday == false)
        #expect(streaks.currentStreakDays == 10)
        #expect(streaks.previousStreakDays == nil)
        #expect(streaks.longestStreakEver == 10)
        #expect(streaks.longestStreakThisYear == 10)
    }

    @Test("PRODUCT.md acceptance: Last drink Saturday, today Monday = 2 days")
    func lastDrinkSaturdayTodayMondayIsTwoDays() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)
        let saturday = LogicalDay(year: 2026, month: 10, day: 17)
        let monday = LogicalDay(year: 2026, month: 10, day: 19)

        let drink = SyntheticDrinks.drink(index: 1, on: saturday)
        let engine = StatsEngine(drinks: [drink], firstUseDay: firstUse, today: monday)
        let streaks = engine.streaks()

        #expect(streaks.lastDrinkingDay == saturday)
        #expect(streaks.lastDrink == drink)
        #expect(streaks.isDrinkingToday == false)
        #expect(streaks.currentStreakDays == 2)
        #expect(streaks.previousStreakDays == nil)
        // Before Saturday Oct 17: Oct 1..16 = 16 days
        #expect(streaks.longestStreakEver == 16)
        #expect(streaks.longestStreakThisYear == 16)
    }

    @Test("Drink today sets isDrinkingToday=true, current=0, and previousStreakDays")
    func drinkTodaySetsPreviousStreakDays() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)
        let prevDrinkDay = LogicalDay(year: 2026, month: 10, day: 5)
        let today = LogicalDay(year: 2026, month: 10, day: 10)

        let d1 = SyntheticDrinks.drink(index: 1, on: prevDrinkDay, hour: 20)
        let d2 = SyntheticDrinks.drink(index: 2, on: today, hour: 19, name: "Wine glass")
        let d3 = SyntheticDrinks.drink(index: 3, on: today, hour: 21, name: "Beer")

        let engine = StatsEngine(drinks: [d1, d2, d3], firstUseDay: firstUse, today: today)
        let streaks = engine.streaks()

        #expect(streaks.lastDrinkingDay == today)
        #expect(streaks.lastDrink == d3)
        #expect(streaks.isDrinkingToday == true)
        #expect(streaks.currentStreakDays == 0)
        // Alcohol-free days between Oct 5 and Oct 10 = Oct 6, 7, 8, 9 -> 4 days
        #expect(streaks.previousStreakDays == 4)
        // Before Oct 5: Oct 1..4 = 4 days
        #expect(streaks.longestStreakEver == 4)
    }

    @Test("Drink today as the very first drink uses virtual drinking day for previousStreakDays")
    func drinkTodayWithNoPriorDrinkUsesFirstUseDay() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)
        let today = LogicalDay(year: 2026, month: 10, day: 5)

        let d1 = SyntheticDrinks.drink(index: 1, on: today)
        let engine = StatsEngine(drinks: [d1], firstUseDay: firstUse, today: today)
        let streaks = engine.streaks()

        #expect(streaks.isDrinkingToday == true)
        #expect(streaks.currentStreakDays == 0)
        // Oct 1, 2, 3, 4 were alcohol-free -> 4 days
        #expect(streaks.previousStreakDays == 4)
        #expect(streaks.longestStreakEver == 4)
    }

    @Test("Drinks on the 1st and 5th produce a run of 3 alcohol-free days between them")
    func drinksOnFirstAndFifthProduceRunOfThree() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)
        let day1 = LogicalDay(year: 2026, month: 10, day: 1)
        let day5 = LogicalDay(year: 2026, month: 10, day: 5)
        let today = LogicalDay(year: 2026, month: 10, day: 6)

        let drinks = [
            SyntheticDrinks.drink(index: 1, on: day1),
            SyntheticDrinks.drink(index: 2, on: day5),
        ]
        let engine = StatsEngine(drinks: drinks, firstUseDay: firstUse, today: today)
        let streaks = engine.streaks()

        #expect(streaks.currentStreakDays == 1)
        #expect(streaks.longestStreakEver == 3)
        #expect(streaks.longestStreakThisYear == 3)
    }

    @Test("Longest streak ever vs longest streak this year across Jan 1 boundary")
    func longestStreakEverAndThisYearCrossingJan1() {
        let firstUse = LogicalDay(year: 2025, month: 11, day: 1)
        // Run 1 in 2025: Nov 1 .. Nov 20 (20 days), drink on Nov 21
        let dNov21 = SyntheticDrinks.drink(index: 1, on: LogicalDay(year: 2025, month: 11, day: 21))
        // Drink on Dec 20, 2025
        let dDec20 = SyntheticDrinks.drink(index: 2, on: LogicalDay(year: 2025, month: 12, day: 20))
        // Next drink on Jan 11, 2026 -> Run from Dec 21, 2025 through Jan 10, 2026:
        // Total run = 11 days in Dec + 10 days in Jan = 21 days (longestEver = 21).
        // Days in 2026 = Jan 1 .. Jan 10 = 10 days.
        let dJan11 = SyntheticDrinks.drink(index: 3, on: LogicalDay(year: 2026, month: 1, day: 11))
        // Today is Jan 18, 2026 -> current streak is Jan 12 .. Jan 18 = 7 days.
        let today = LogicalDay(year: 2026, month: 1, day: 18)

        let engine = StatsEngine(
            drinks: [dNov21, dDec20, dJan11],
            firstUseDay: firstUse,
            today: today
        )
        let streaks = engine.streaks()

        #expect(streaks.currentStreakDays == 7)
        #expect(streaks.longestStreakEver == 28)  // Wait: Nov 22..Dec 19 is 28 days!
        // Let's verify: Nov 22..Nov 30 (9) + Dec 1..Dec 19 (19) = 28 days in 2025!
        // And in 2026: Dec 21..Jan 10 has 10 days in 2026 (Jan 1..10), while Jan 12..18 has 7 days.
        #expect(streaks.longestStreakThisYear == 10)
    }

    @Test("Back-dated drink before firstUseDay shifts effectiveFirstUseDay earlier")
    func backDatedDrinkShiftsEffectiveFirstUse() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 10)
        let backDated = LogicalDay(year: 2026, month: 10, day: 1)
        let today = LogicalDay(year: 2026, month: 10, day: 12)

        let d1 = SyntheticDrinks.drink(index: 1, on: backDated)
        let d2 = SyntheticDrinks.drink(index: 2, on: firstUse)

        let engine = StatsEngine(drinks: [d1, d2], firstUseDay: firstUse, today: today)
        let streaks = engine.streaks()

        // Between Oct 1 and Oct 10 is Oct 2..9 = 8 days
        #expect(streaks.longestStreakEver == 8)
        #expect(streaks.currentStreakDays == 2)
    }

    @Test("Deleted drinks and future drinks after today are ignored")
    func deletedAndFutureDrinksIgnored() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 1)
        let oct5 = LogicalDay(year: 2026, month: 10, day: 5)
        let oct8 = LogicalDay(year: 2026, month: 10, day: 8)
        let today = LogicalDay(year: 2026, month: 10, day: 10)
        let future = LogicalDay(year: 2026, month: 10, day: 12)

        let validDrink = SyntheticDrinks.drink(index: 1, on: oct5)
        let deletedDrink = SyntheticDrinks.drink(
            index: 2,
            on: oct8,
            deletedAt: SyntheticDrinks.makeDate(year: 2026, month: 10, day: 8, hour: 22)
        )
        let futureDrink = SyntheticDrinks.drink(index: 3, on: future)

        let engine = StatsEngine(
            drinks: [validDrink, deletedDrink, futureDrink],
            firstUseDay: firstUse,
            today: today
        )
        let streaks = engine.streaks()

        #expect(streaks.lastDrinkingDay == oct5)
        #expect(streaks.lastDrink == validDrink)
        #expect(streaks.currentStreakDays == 5)
    }

    @Test("Day boundary 07:00: Fri 22:00 + Sat 01:30 count as one drinking day (Friday)")
    func dayBoundaryFriNightAndSatEarlyMorningOneDrinkingDay() {
        let firstUse = LogicalDay(year: 2026, month: 10, day: 15)
        // Friday 2026-10-16 22:00 and Saturday 2026-10-17 01:30 in Europe/Berlin (boundary 7)
        let friNight = SyntheticDrinks.drinkAtTimestamp(
            index: 1,
            year: 2026,
            month: 10,
            day: 16,
            hour: 22,
            minute: 0,
            timeZone: SyntheticDrinks.berlin,
            boundaryHour: 7
        )
        let satEarly = SyntheticDrinks.drinkAtTimestamp(
            index: 2,
            year: 2026,
            month: 10,
            day: 17,
            hour: 1,
            minute: 30,
            timeZone: SyntheticDrinks.berlin,
            boundaryHour: 7
        )

        let friday = LogicalDay(year: 2026, month: 10, day: 16)
        let sunday = LogicalDay(year: 2026, month: 10, day: 18)

        #expect(friNight.logicalDay == friday)
        #expect(satEarly.logicalDay == friday)

        let engine = StatsEngine(
            drinks: [friNight, satEarly],
            firstUseDay: firstUse,
            today: sunday
        )
        let streaks = engine.streaks()
        let stats = engine.stats(for: .last7Days)

        #expect(streaks.lastDrinkingDay == friday)
        #expect(streaks.lastDrink == satEarly)
        #expect(streaks.currentStreakDays == 2)
        #expect(stats.drinkingDays == 1)
        #expect(stats.totalHU == Decimal(2))
    }

    @Test("DST spring (2026-03-29) and autumn (2026-10-25) weeks: one evening drink per night = 7 drinking days")
    func dstSpringAndAutumnWeeksOneDrinkingDayPerEvening() {
        // Spring DST week in Berlin: 2026-03-26 through 2026-04-01 (7 evenings, mix of 22:30 and 01:30 next morning)
        let springStart = LogicalDay(year: 2026, month: 3, day: 26)
        let springEnd = LogicalDay(year: 2026, month: 4, day: 1)
        var springDrinks: [DrinkSnapshot] = []
        for offset in 0..<7 {
            let day = springStart.adding(days: offset)
            // Log at 01:30 on the next calendar morning -> belongs to `day`
            let nextMorning = day.adding(days: 1)
            springDrinks.append(
                SyntheticDrinks.drinkAtTimestamp(
                    index: offset + 1,
                    year: nextMorning.year,
                    month: nextMorning.month,
                    day: nextMorning.day,
                    hour: 1,
                    minute: 30,
                    timeZone: SyntheticDrinks.berlin,
                    boundaryHour: 7
                )
            )
        }
        let springEngine = StatsEngine(drinks: springDrinks, firstUseDay: springStart, today: springEnd)
        let springStats = springEngine.stats(for: .last7Days)
        #expect(springStats.drinkingDays == 7)
        #expect(springStats.alcoholFreeDays == 0)

        // Autumn DST week in Berlin: 2026-10-22 through 2026-10-28 (7 evenings at 01:30 next morning)
        let autumnStart = LogicalDay(year: 2026, month: 10, day: 22)
        let autumnEnd = LogicalDay(year: 2026, month: 10, day: 28)
        var autumnDrinks: [DrinkSnapshot] = []
        for offset in 0..<7 {
            let day = autumnStart.adding(days: offset)
            let nextMorning = day.adding(days: 1)
            autumnDrinks.append(
                SyntheticDrinks.drinkAtTimestamp(
                    index: 100 + offset,
                    year: nextMorning.year,
                    month: nextMorning.month,
                    day: nextMorning.day,
                    hour: 1,
                    minute: 30,
                    timeZone: SyntheticDrinks.berlin,
                    boundaryHour: 7
                )
            )
        }
        let autumnEngine = StatsEngine(drinks: autumnDrinks, firstUseDay: autumnStart, today: autumnEnd)
        let autumnStats = autumnEngine.stats(for: .last7Days)
        #expect(autumnStats.drinkingDays == 7)
        #expect(autumnStats.alcoholFreeDays == 0)
    }

    @Test("Time-zone change: drink logged in New York keeps its New York logical day when today is in Berlin")
    func timeZoneChangePreservesDrinkLogicalDay() {
        // 2026-06-15 02:00 in America/New_York (08:00 in Europe/Berlin).
        // With boundary 07:00:
        // In New York (where the drink was logged), 02:00 < 07:00 -> logical day is 2026-06-14.
        // Even though in Berlin that instant was 08:00 (2026-06-15), the drink keeps 2026-06-14.
        let nyDrink = SyntheticDrinks.drinkAtTimestamp(
            index: 1,
            year: 2026,
            month: 6,
            day: 15,
            hour: 2,
            minute: 0,
            timeZone: SyntheticDrinks.newYork,
            boundaryHour: 7
        )
        #expect(nyDrink.logicalDay == LogicalDay(year: 2026, month: 6, day: 14))

        // User travels to Berlin and checks app on 2026-06-15 at 12:00 Berlin time -> today is 2026-06-15.
        let berlinNow = SyntheticDrinks.makeDate(
            year: 2026,
            month: 6,
            day: 15,
            hour: 12,
            minute: 0,
            timeZone: SyntheticDrinks.berlin
        )
        let todayInBerlin = LogicalDay.of(berlinNow, boundaryHour: 7, timeZone: SyntheticDrinks.berlin)
        #expect(todayInBerlin == LogicalDay(year: 2026, month: 6, day: 15))

        let engine = StatsEngine(
            drinks: [nyDrink],
            firstUseDay: LogicalDay(year: 2026, month: 6, day: 1),
            today: todayInBerlin
        )
        let streaks = engine.streaks()
        #expect(streaks.lastDrinkingDay == LogicalDay(year: 2026, month: 6, day: 14))
        #expect(streaks.currentStreakDays == 1)
    }
}
