import Foundation
import HalfUnitCore

enum SyntheticDrinks {
    static let berlin = TimeZone(identifier: "Europe/Berlin")!
    static let newYork = TimeZone(identifier: "America/New_York")!
    static let utc = TimeZone(identifier: "UTC")!

    static func makeUUID(_ index: Int) -> UUID {
        let hex = String(format: "%012x", index)
        return UUID(uuidString: "00000000-0000-4000-8000-\(hex)")!
    }

    static func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 20,
        minute: Int = 0,
        timeZone: TimeZone = berlin
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: 0
        )
        guard let date = calendar.date(from: components) else {
            preconditionFailure("Invalid date components: \(components)")
        }
        return date
    }

    static func drink(
        index: Int,
        on logicalDay: LogicalDay,
        hour: Int = 20,
        minute: Int = 0,
        presetKey: String? = "beer",
        name: String = "Beer",
        hu: Decimal = Decimal(1),
        grams: Decimal = Decimal(20),
        deletedAt: Date? = nil
    ) -> DrinkSnapshot {
        let timestamp = makeDate(
            year: logicalDay.year,
            month: logicalDay.month,
            day: logicalDay.day,
            hour: hour,
            minute: minute,
            timeZone: utc
        )
        return DrinkSnapshot(
            id: makeUUID(index),
            timestamp: timestamp,
            logicalDay: logicalDay,
            presetKey: presetKey,
            name: name,
            hu: hu,
            grams: grams,
            deletedAt: deletedAt
        )
    }

    static func drinkAtTimestamp(
        index: Int,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZone: TimeZone = berlin,
        boundaryHour: Int = LogicalDay.defaultBoundaryHour,
        presetKey: String? = "beer",
        name: String = "Beer",
        hu: Decimal = Decimal(1),
        grams: Decimal = Decimal(20),
        deletedAt: Date? = nil
    ) -> DrinkSnapshot {
        let timestamp = makeDate(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            timeZone: timeZone
        )
        return DrinkSnapshot(
            id: makeUUID(index),
            timestamp: timestamp,
            timeZone: timeZone,
            boundaryHour: boundaryHour,
            presetKey: presetKey,
            name: name,
            hu: hu,
            grams: grams,
            deletedAt: deletedAt
        )
    }

    struct LongHistoryFixture {
        let today: LogicalDay
        let firstUseDay: LogicalDay
        let drinks: [DrinkSnapshot]
    }

    /// Generates an 850-day synthetic dataset ending on `today` (2026-10-22, Thursday).
    /// Pattern:
    /// - Every Friday (1 Beer: 1 HU, 20 g) and every Saturday (2 Wine glasses: 2 HU, 38.4 g total)
    /// - Plus extra drinks on the exact start day and day-before-start of each fixed window
    ///   (7d, 30d, 3m/91d, 12m/365d, 2y/730d) so boundary inclusion/exclusion is tested.
    static func make850DayDataset() -> LongHistoryFixture {
        let today = LogicalDay(year: 2026, month: 10, day: 22)  // Thursday
        let firstUseDay = today.adding(days: -849)  // 850 days total including today

        // Window start offsets from today:
        // 7d: -6 (Fri Oct 16), day before: -7 (Thu Oct 15)
        // 30d: -29 (Wed Sep 23), day before: -30 (Tue Sep 22)
        // 91d: -90 (Fri Jul 24), day before: -91 (Thu Jul 23)
        // 365d: -364 (Thu Oct 23, 2025), day before: -365 (Wed Oct 22, 2025)
        // 730d: -729 (Wed Oct 23, 2024), day before: -730 (Tue Oct 22, 2024)
        let extraOffsets: Set<Int> = [-6, -7, -29, -30, -90, -91, -364, -365, -729, -730]
        let extraDays: Set<LogicalDay> = Set(extraOffsets.map { today.adding(days: $0) })

        var drinks: [DrinkSnapshot] = []
        var nextIndex = 1

        var day = firstUseDay
        while day <= today {
            if day.weekday == .friday {
                drinks.append(
                    drink(
                        index: nextIndex,
                        on: day,
                        hour: 19,
                        presetKey: "beer",
                        name: "Beer",
                        hu: Decimal(1),
                        grams: Decimal(20)
                    )
                )
                nextIndex += 1
            } else if day.weekday == .saturday {
                drinks.append(
                    drink(
                        index: nextIndex,
                        on: day,
                        hour: 20,
                        presetKey: "wineGlass",
                        name: "Wine glass",
                        hu: Decimal(1),
                        grams: Decimal(string: "19.2")!
                    )
                )
                nextIndex += 1
                drinks.append(
                    drink(
                        index: nextIndex,
                        on: day,
                        hour: 21,
                        presetKey: "wineGlass",
                        name: "Wine glass",
                        hu: Decimal(1),
                        grams: Decimal(string: "19.2")!
                    )
                )
                nextIndex += 1
            } else if extraDays.contains(day) {
                drinks.append(
                    drink(
                        index: nextIndex,
                        on: day,
                        hour: 18,
                        presetKey: "smallBeer",
                        name: "Small beer",
                        hu: Decimal(sign: .plus, exponent: -1, significand: 5),
                        grams: Decimal(string: "13.2")!
                    )
                )
                nextIndex += 1
            }
            day = day.adding(days: 1)
        }

        return LongHistoryFixture(today: today, firstUseDay: firstUseDay, drinks: drinks)
    }
}
