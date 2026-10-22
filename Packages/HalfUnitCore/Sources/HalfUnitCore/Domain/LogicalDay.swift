import Foundation

public enum Weekday: Int, CaseIterable, Codable, Sendable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
}

public struct LogicalDay: Hashable, Comparable, Codable, Sendable {
    public static let defaultBoundaryHour = 7

    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public var key: Int {
        year * 10_000 + month * 100 + day
    }

    public init?(key: Int) {
        guard key > 0 else {
            return nil
        }
        let year = key / 10_000
        let remainder = key % 10_000
        let month = remainder / 100
        let day = remainder % 100

        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }

        let calendar = Self.utcCalendar
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else {
            return nil
        }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day else {
            return nil
        }

        self.year = year
        self.month = month
        self.day = day
    }

    public var weekday: Weekday {
        let calendar = Self.utcCalendar
        let date = toUTCDate(using: calendar)
        let gregorianWeekday = calendar.component(.weekday, from: date)
        let isoNumber = ((gregorianWeekday + 5) % 7) + 1
        guard let result = Weekday(rawValue: isoNumber) else {
            preconditionFailure("Invalid ISO weekday \(isoNumber)")
        }
        return result
    }

    public static func of(
        _ date: Date,
        boundaryHour: Int = defaultBoundaryHour,
        timeZone: TimeZone
    ) -> LogicalDay {
        precondition((0...23).contains(boundaryHour), "boundaryHour must be in 0...23")

        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone

        let components = localCalendar.dateComponents([.year, .month, .day, .hour], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day,
            let hour = components.hour
        else {
            preconditionFailure("Failed to extract calendar components from date")
        }

        let calendarDay = LogicalDay(year: year, month: month, day: day)
        if hour < boundaryHour {
            return calendarDay.adding(days: -1)
        }
        return calendarDay
    }

    public func adding(days: Int) -> LogicalDay {
        let calendar = Self.utcCalendar
        let startDate = toUTCDate(using: calendar)
        guard let targetDate = calendar.date(byAdding: .day, value: days, to: startDate) else {
            preconditionFailure("Failed to add \(days) days to \(self)")
        }
        let components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            preconditionFailure("Failed to extract calendar components after adding days")
        }
        return LogicalDay(year: year, month: month, day: day)
    }

    public func days(to other: LogicalDay) -> Int {
        let calendar = Self.utcCalendar
        let start = toUTCDate(using: calendar)
        let end = other.toUTCDate(using: calendar)
        guard let diff = calendar.dateComponents([.day], from: start, to: end).day else {
            preconditionFailure("Failed to compute days between \(self) and \(other)")
        }
        return diff
    }

    public static func < (lhs: LogicalDay, rhs: LogicalDay) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        if lhs.month != rhs.month {
            return lhs.month < rhs.month
        }
        return lhs.day < rhs.day
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(identifier: "UTC") else {
            preconditionFailure("UTC time zone unavailable")
        }
        calendar.timeZone = utc
        return calendar
    }()

    private func toUTCDate(using calendar: Calendar) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else {
            preconditionFailure("Invalid calendar date: \(year)-\(month)-\(day)")
        }
        return date
    }
}
