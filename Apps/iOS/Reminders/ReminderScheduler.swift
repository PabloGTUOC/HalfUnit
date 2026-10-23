import Foundation
import HalfUnitCore
import OSLog
import UserNotifications

public enum ReminderScheduleResult: Equatable, Sendable {
    case scheduled
    case denied
    case failed(String)
}

public final class ReminderScheduler: Sendable {
    private static let logger = Logger(
        subsystem: "es.opinasdeque.halfunit",
        category: "ReminderScheduler"
    )

    public static let reminderIdentifier = "es.opinasdeque.halfunit.reminder.daily"
    public static let defaultReminderMinutes = 21 * 60
    public static let shared = ReminderScheduler()

    private let client: any NotificationCenterClient

    public init(client: any NotificationCenterClient = SystemNotificationCenterClient.shared) {
        self.client = client
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await client.authorizationStatus()
    }

    public func enable(minutes: Int, locale: Locale = .current) async -> ReminderScheduleResult {
        let currentStatus = await client.authorizationStatus()
        switch currentStatus {
        case .denied:
            cancelNotification()
            return .denied
        case .notDetermined:
            do {
                let granted = try await client.requestAuthorization(options: [.alert, .sound])
                guard granted else {
                    cancelNotification()
                    return .denied
                }
            } catch {
                Self.logger.error(
                    "Failed to request notification authorization: \(error.localizedDescription, privacy: .private)"
                )
                cancelNotification()
                return .denied
            }
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            break
        }

        do {
            try await scheduleNotification(minutes: minutes, locale: locale)
            return .scheduled
        } catch {
            Self.logger.error(
                "Failed to schedule reminder notification: \(error.localizedDescription, privacy: .private)"
            )
            return .failed(error.localizedDescription)
        }
    }

    public func disable() async {
        cancelNotification()
    }

    public func cancelNotification() {
        client.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
    }

    public func scheduleNotification(minutes: Int, locale: Locale = .current) async throws {
        let hour = max(0, min(23, minutes / 60))
        let minute = max(0, min(59, minutes % 60))

        let content = UNMutableNotificationContent()
        content.title = AppLocalization.string("reminder.notification.title", locale: locale)
        content.body = AppLocalization.string("reminder.notification.body", locale: locale)
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier,
            content: content,
            trigger: trigger
        )

        try await client.add(request)
    }

    public func syncFromSettings(
        enabled: Bool,
        reminderMinutes: Int?,
        locale: Locale = .current
    ) async -> ReminderScheduleResult {
        if enabled {
            let status = await client.authorizationStatus()
            switch status {
            case .authorized, .provisional, .ephemeral:
                let minutes = reminderMinutes ?? Self.defaultReminderMinutes
                do {
                    try await scheduleNotification(minutes: minutes, locale: locale)
                    return .scheduled
                } catch {
                    Self.logger.error(
                        "Failed to sync reminder: \(error.localizedDescription, privacy: .private)"
                    )
                    return .failed(error.localizedDescription)
                }
            case .denied, .notDetermined:
                cancelNotification()
                return .denied
            @unknown default:
                cancelNotification()
                return .denied
            }
        } else {
            cancelNotification()
            return .scheduled
        }
    }
}
