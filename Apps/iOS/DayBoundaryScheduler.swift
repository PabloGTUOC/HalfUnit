import Foundation
import HalfUnitCore

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

    static func nextBoundaryDate(
        now: Date,
        boundaryHour: Int,
        timeZone: TimeZone
    ) -> Date {
        let resolvedBoundaryHour =
            (0...23).contains(boundaryHour)
            ? boundaryHour
            : LogicalDay.defaultBoundaryHour

        let currentLogicalDay = LogicalDay.of(
            now,
            boundaryHour: resolvedBoundaryHour,
            timeZone: timeZone
        )
        let nextLogicalDay = currentLogicalDay.adding(days: 1)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: nextLogicalDay.year,
            month: nextLogicalDay.month,
            day: nextLogicalDay.day,
            hour: resolvedBoundaryHour,
            minute: 0,
            second: 0
        )
        if let boundaryDate = calendar.date(from: components), boundaryDate > now {
            return boundaryDate
        }
        return now.addingTimeInterval(3600)
    }
}
