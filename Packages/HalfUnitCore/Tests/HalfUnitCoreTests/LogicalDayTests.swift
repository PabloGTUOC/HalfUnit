import Foundation
import Testing

@testable import HalfUnitCore

@Suite("LogicalDay Tests")
struct LogicalDayTests {
    private static let berlin = TimeZone(identifier: "Europe/Berlin")!
    private static let newYork = TimeZone(identifier: "America/New_York")!

    private static func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZone: TimeZone
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

    @Test(
        "Boundary 07:00 in Europe/Berlin maps 01:30 and 06:59 to previous day, 07:00 and 23:59 to same day",
        arguments: [
            (1, 30, LogicalDay(year: 2026, month: 6, day: 14)),
            (6, 59, LogicalDay(year: 2026, month: 6, day: 14)),
            (7, 0, LogicalDay(year: 2026, month: 6, day: 15)),
            (23, 59, LogicalDay(year: 2026, month: 6, day: 15)),
        ]
    )
    func boundaryHourSevenInBerlin(hour: Int, minute: Int, expected: LogicalDay) {
        let date = Self.makeDate(
            year: 2026,
            month: 6,
            day: 15,
            hour: hour,
            minute: minute,
            timeZone: Self.berlin
        )
        let actual = LogicalDay.of(date, boundaryHour: 7, timeZone: Self.berlin)
        #expect(actual == expected)
    }

    @Test(
        "Full week across Europe/Berlin spring DST change (2026-03-29)",
        arguments: 26...31
    )
    func springDSTWeekInBerlin(day: Int) {
        let calendarDay = LogicalDay(year: 2026, month: 3, day: day)
        let previousDay = calendarDay.adding(days: -1)

        let at0130 = Self.makeDate(year: 2026, month: 3, day: day, hour: 1, minute: 30, timeZone: Self.berlin)
        let at0659 = Self.makeDate(year: 2026, month: 3, day: day, hour: 6, minute: 59, timeZone: Self.berlin)
        let at0700 = Self.makeDate(year: 2026, month: 3, day: day, hour: 7, minute: 0, timeZone: Self.berlin)

        #expect(LogicalDay.of(at0130, boundaryHour: 7, timeZone: Self.berlin) == previousDay)
        #expect(LogicalDay.of(at0659, boundaryHour: 7, timeZone: Self.berlin) == previousDay)
        #expect(LogicalDay.of(at0700, boundaryHour: 7, timeZone: Self.berlin) == calendarDay)
    }

    @Test("Spring DST week April 1 continuation and days(to:) across transition")
    func springDSTApril1AndDaysBetween() {
        let apr1 = LogicalDay(year: 2026, month: 4, day: 1)
        let mar31 = LogicalDay(year: 2026, month: 3, day: 31)

        let at0130 = Self.makeDate(year: 2026, month: 4, day: 1, hour: 1, minute: 30, timeZone: Self.berlin)
        let at0659 = Self.makeDate(year: 2026, month: 4, day: 1, hour: 6, minute: 59, timeZone: Self.berlin)
        let at0700 = Self.makeDate(year: 2026, month: 4, day: 1, hour: 7, minute: 0, timeZone: Self.berlin)

        #expect(LogicalDay.of(at0130, boundaryHour: 7, timeZone: Self.berlin) == mar31)
        #expect(LogicalDay.of(at0659, boundaryHour: 7, timeZone: Self.berlin) == mar31)
        #expect(LogicalDay.of(at0700, boundaryHour: 7, timeZone: Self.berlin) == apr1)

        let satBeforeDST = LogicalDay(year: 2026, month: 3, day: 28)
        let monAfterDST = LogicalDay(year: 2026, month: 3, day: 30)
        #expect(satBeforeDST.days(to: monAfterDST) == 2)
    }

    @Test(
        "Full week across Europe/Berlin autumn DST change (2026-10-25)",
        arguments: 22...28
    )
    func autumnDSTWeekInBerlin(day: Int) {
        let calendarDay = LogicalDay(year: 2026, month: 10, day: day)
        let previousDay = calendarDay.adding(days: -1)

        let at0130 = Self.makeDate(year: 2026, month: 10, day: day, hour: 1, minute: 30, timeZone: Self.berlin)
        let at0659 = Self.makeDate(year: 2026, month: 10, day: day, hour: 6, minute: 59, timeZone: Self.berlin)
        let at0700 = Self.makeDate(year: 2026, month: 10, day: day, hour: 7, minute: 0, timeZone: Self.berlin)

        #expect(LogicalDay.of(at0130, boundaryHour: 7, timeZone: Self.berlin) == previousDay)
        #expect(LogicalDay.of(at0659, boundaryHour: 7, timeZone: Self.berlin) == previousDay)
        #expect(LogicalDay.of(at0700, boundaryHour: 7, timeZone: Self.berlin) == calendarDay)

        let satBeforeAutumnDST = LogicalDay(year: 2026, month: 10, day: 24)
        let monAfterAutumnDST = LogicalDay(year: 2026, month: 10, day: 26)
        #expect(satBeforeAutumnDST.days(to: monAfterAutumnDST) == 2)
    }

    @Test("Same instant in Europe/Berlin vs America/New_York yields expected logical days")
    func timeZoneComparison() {
        // 2026-06-15 08:00 in Berlin (CEST, UTC+2) is 2026-06-15 02:00 in New York (EDT, UTC-4).
        // With boundaryHour = 7:
        // - In Berlin (08:00 >= 7), logical day is 2026-06-15.
        // - In New York (02:00 < 7), logical day is 2026-06-14.
        let instant = Self.makeDate(
            year: 2026,
            month: 6,
            day: 15,
            hour: 8,
            minute: 0,
            timeZone: Self.berlin
        )
        #expect(
            LogicalDay.of(instant, boundaryHour: 7, timeZone: Self.berlin)
                == LogicalDay(year: 2026, month: 6, day: 15)
        )
        #expect(
            LogicalDay.of(instant, boundaryHour: 7, timeZone: Self.newYork)
                == LogicalDay(year: 2026, month: 6, day: 14)
        )
    }

    @Test("Custom boundary hours (4 and 0)")
    func customBoundaryHours() {
        let at0359 = Self.makeDate(year: 2026, month: 5, day: 10, hour: 3, minute: 59, timeZone: Self.berlin)
        let at0400 = Self.makeDate(year: 2026, month: 5, day: 10, hour: 4, minute: 0, timeZone: Self.berlin)
        let at0000 = Self.makeDate(year: 2026, month: 5, day: 10, hour: 0, minute: 0, timeZone: Self.berlin)

        #expect(
            LogicalDay.of(at0359, boundaryHour: 4, timeZone: Self.berlin)
                == LogicalDay(year: 2026, month: 5, day: 9)
        )
        #expect(
            LogicalDay.of(at0400, boundaryHour: 4, timeZone: Self.berlin)
                == LogicalDay(year: 2026, month: 5, day: 10)
        )
        #expect(
            LogicalDay.of(at0000, boundaryHour: 0, timeZone: Self.berlin)
                == LogicalDay(year: 2026, month: 5, day: 10)
        )
        #expect(
            LogicalDay.of(at0359, boundaryHour: 0, timeZone: Self.berlin)
                == LogicalDay(year: 2026, month: 5, day: 10)
        )
    }

    @Test("adding(days:) and days(to:) across month end, year end, and leap year Feb 29 2028")
    func dateArithmeticAndLeapYear() {
        // Month end
        let jan31 = LogicalDay(year: 2026, month: 1, day: 31)
        let feb1 = LogicalDay(year: 2026, month: 2, day: 1)
        #expect(jan31.adding(days: 1) == feb1)
        #expect(feb1.adding(days: -1) == jan31)
        #expect(jan31.days(to: feb1) == 1)
        #expect(feb1.days(to: jan31) == -1)

        // Year end
        let dec31 = LogicalDay(year: 2026, month: 12, day: 31)
        let jan1Next = LogicalDay(year: 2027, month: 1, day: 1)
        #expect(dec31.adding(days: 1) == jan1Next)
        #expect(dec31.days(to: jan1Next) == 1)

        // Non-leap year 2026 Feb 28 -> Mar 1
        let feb28NonLeap = LogicalDay(year: 2026, month: 2, day: 28)
        let mar1NonLeap = LogicalDay(year: 2026, month: 3, day: 1)
        #expect(feb28NonLeap.adding(days: 1) == mar1NonLeap)
        #expect(feb28NonLeap.days(to: mar1NonLeap) == 1)

        // Leap year 2028 Feb 28 -> Feb 29 -> Mar 1
        let feb28Leap = LogicalDay(year: 2028, month: 2, day: 28)
        let feb29Leap = LogicalDay(year: 2028, month: 2, day: 29)
        let mar1Leap = LogicalDay(year: 2028, month: 3, day: 1)
        #expect(feb28Leap.adding(days: 1) == feb29Leap)
        #expect(feb29Leap.adding(days: 1) == mar1Leap)
        #expect(feb28Leap.days(to: mar1Leap) == 2)
    }

    @Test("Comparable ordering")
    func comparableOrdering() {
        let d1 = LogicalDay(year: 2025, month: 12, day: 31)
        let d2 = LogicalDay(year: 2026, month: 1, day: 1)
        let d3 = LogicalDay(year: 2026, month: 1, day: 2)
        let d4 = LogicalDay(year: 2026, month: 2, day: 1)

        #expect(d1 < d2)
        #expect(d2 < d3)
        #expect(d3 < d4)
        #expect(!(d2 < d2))
    }

    @Test("PRODUCT.md acceptance: Last drink Saturday, today Monday -> 2 days")
    func saturdayToMondayIsTwoDays() {
        let saturday = LogicalDay(year: 2026, month: 10, day: 17)
        let monday = LogicalDay(year: 2026, month: 10, day: 19)
        #expect(saturday.days(to: monday) == 2)
    }
}
