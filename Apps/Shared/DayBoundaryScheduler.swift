import Foundation
import HalfUnitCore

typealias WatchDayBoundary = DayBoundaryScheduler

struct DayBoundaryScheduler: Sendable {
    let now: @Sendable () -> Date
    let timeZone: @Sendable () -> TimeZone

    init(
        now: @escaping @Sendable () -> Date,
        timeZone: @escaping @Sendable () -> TimeZone
    ) {
        self.now = now
        self.timeZone = timeZone
    }

    func nextBoundaryDate(boundaryHour: Int) -> Date {
        Self.nextBoundaryDate(
            now: now(),
            boundaryHour: boundaryHour,
            timeZone: timeZone()
        )
    }

    func nextBoundaryDate(after referenceDate: Date, boundaryHour: Int) -> Date {
        Self.nextBoundaryDate(
            now: referenceDate,
            boundaryHour: boundaryHour,
            timeZone: timeZone()
        )
    }

    func timelineEntryDates(boundaryHour: Int) -> [Date] {
        Self.timelineEntryDates(
            now: now(),
            boundaryHour: boundaryHour,
            timeZone: timeZone()
        )
    }

    func timelineEntryDates(after referenceDate: Date, boundaryHour: Int) -> [Date] {
        Self.timelineEntryDates(
            now: referenceDate,
            boundaryHour: boundaryHour,
            timeZone: timeZone()
        )
    }

    static func resolvedBoundaryHour(_ hour: Int) -> Int {
        (0...23).contains(hour) ? hour : LogicalDay.defaultBoundaryHour
    }

    static func currentLogicalDay(
        at now: Date,
        boundaryHour: Int = LogicalDay.defaultBoundaryHour,
        timeZone: TimeZone
    ) -> LogicalDay {
        let resolvedHour = resolvedBoundaryHour(boundaryHour)
        return LogicalDay.of(now, boundaryHour: resolvedHour, timeZone: timeZone)
    }

    static func nextBoundaryDate(
        now: Date,
        boundaryHour: Int = LogicalDay.defaultBoundaryHour,
        timeZone: TimeZone
    ) -> Date {
        let resolvedHour = resolvedBoundaryHour(boundaryHour)
        let currentLogical = LogicalDay.of(
            now,
            boundaryHour: resolvedHour,
            timeZone: timeZone
        )
        let nextLogical = currentLogical.adding(days: 1)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: nextLogical.year,
            month: nextLogical.month,
            day: nextLogical.day,
            hour: resolvedHour,
            minute: 0,
            second: 0
        )
        if let candidate = calendar.date(from: components),
            candidate > now,
            LogicalDay.of(candidate, boundaryHour: resolvedHour, timeZone: timeZone) >= nextLogical
        {
            return candidate
        }

        if let nextMatched = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: resolvedHour, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) {
            return nextMatched
        }

        return now.addingTimeInterval(3600)
    }

    static func nextBoundaryDate(
        after now: Date,
        boundaryHour: Int = LogicalDay.defaultBoundaryHour,
        timeZone: TimeZone
    ) -> Date {
        nextBoundaryDate(now: now, boundaryHour: boundaryHour, timeZone: timeZone)
    }

    static func secondsUntilNextBoundary(
        from now: Date,
        boundaryHour: Int = LogicalDay.defaultBoundaryHour,
        timeZone: TimeZone
    ) -> TimeInterval {
        let next = nextBoundaryDate(now: now, boundaryHour: boundaryHour, timeZone: timeZone)
        return max(1, next.timeIntervalSince(now))
    }

    static func timelineEntryDates(
        now: Date,
        boundaryHour: Int = LogicalDay.defaultBoundaryHour,
        timeZone: TimeZone
    ) -> [Date] {
        let nextBoundary = nextBoundaryDate(
            now: now,
            boundaryHour: boundaryHour,
            timeZone: timeZone
        )
        return [now, nextBoundary]
    }
}
