import Foundation
import HalfUnitCore
import SwiftData
import SwiftUI
import Testing
import UIKit
import UserNotifications

@testable import HalfUnit

final class FakeNotificationCenterClient: NotificationCenterClient, @unchecked Sendable {
    var authStatus: UNAuthorizationStatus = .notDetermined
    var requestAuthGranted: Bool = true
    var requestAuthCallCount: Int = 0
    var requestedOptions: UNAuthorizationOptions?
    var pendingRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthCallCount += 1
        requestedOptions = options
        if requestAuthGranted {
            authStatus = .authorized
            return true
        } else {
            authStatus = .denied
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authStatus
    }

    func add(_ request: UNNotificationRequest) async throws {
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }
}

final class FakeAppLockAuthenticator: AppLockAuthenticator, @unchecked Sendable {
    var isAvailable: Bool = true
    var shouldSucceed: Bool = true
    var authenticateCallCount: Int = 0
    var lastReason: String?

    func canAuthenticate() -> Bool {
        isAvailable
    }

    func authenticate(localizedReason: String) async throws -> Bool {
        authenticateCallCount += 1
        lastReason = localizedReason
        return shouldSucceed
    }
}

private final class FakeRemindersHealthClient: HealthStoreClient, @unchecked Sendable {
    var isAvailable = true
    var authorization: HealthWriteAuthorization = .authorized

    func writeAuthorization() async -> HealthWriteAuthorization {
        guard isAvailable else {
            return .unavailable
        }
        return authorization
    }

    func requestWriteAuthorization() async throws {}
    func save(_ samples: [HealthDrinkSample]) async throws {}
    func deleteSamples(withSyncIdentifiers ids: [String]) async throws {}
}

@Suite("Reminders and App Lock Tests")
struct RemindersAndLockTests {
    private static let englishLocale = Locale(identifier: "en_US")
    private static let germanLocale = Locale(identifier: "de_DE")

    // MARK: - Reminder Scheduler Tests

    @Test(
        "Reminder scheduler: enable when not determined and granted schedules daily repeating notification with localized body"
    )
    func reminderEnableGranted() async throws {
        let fakeClient = FakeNotificationCenterClient()
        fakeClient.authStatus = .notDetermined
        fakeClient.requestAuthGranted = true

        let scheduler = ReminderScheduler(client: fakeClient)
        let result = await scheduler.enable(minutes: 21 * 60 + 30, locale: Self.englishLocale)

        #expect(result == .scheduled)
        #expect(fakeClient.requestAuthCallCount == 1)
        #expect(fakeClient.requestedOptions == [.alert, .sound])

        let pending = await fakeClient.pendingNotificationRequests()
        #expect(pending.count == 1)
        let request = try #require(pending.first)
        #expect(request.identifier == ReminderScheduler.reminderIdentifier)
        #expect(request.content.body == "Anything to log today?")
        #expect(request.content.title == "Half Unit")

        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == true)
        #expect(trigger.dateComponents.hour == 21)
        #expect(trigger.dateComponents.minute == 30)
    }

    @Test("Reminder scheduler: German localized notification body matches product spec")
    func reminderGermanLocalization() async throws {
        let fakeClient = FakeNotificationCenterClient()
        fakeClient.authStatus = .authorized

        let scheduler = ReminderScheduler(client: fakeClient)
        let result = await scheduler.enable(minutes: 20 * 60, locale: Self.germanLocale)

        #expect(result == .scheduled)
        let pending = await fakeClient.pendingNotificationRequests()
        let request = try #require(pending.first)
        #expect(request.content.body == "Heute etwas einzutragen?")
    }

    @Test("Reminder scheduler: enable when denied returns .denied and schedules nothing")
    func reminderEnableDenied() async {
        let fakeClient = FakeNotificationCenterClient()
        fakeClient.authStatus = .denied

        let scheduler = ReminderScheduler(client: fakeClient)
        let result = await scheduler.enable(minutes: 21 * 60, locale: Self.englishLocale)

        #expect(result == .denied)
        #expect(fakeClient.requestAuthCallCount == 0)
        let pending = await fakeClient.pendingNotificationRequests()
        #expect(pending.isEmpty)
        #expect(fakeClient.removedIdentifiers.contains(ReminderScheduler.reminderIdentifier))
    }

    @Test("Reminder scheduler: disable removes pending notification request")
    func reminderDisable() async {
        let fakeClient = FakeNotificationCenterClient()
        fakeClient.authStatus = .authorized
        let scheduler = ReminderScheduler(client: fakeClient)

        _ = await scheduler.enable(minutes: 21 * 60, locale: Self.englishLocale)
        #expect(await fakeClient.pendingNotificationRequests().count == 1)

        await scheduler.disable()
        #expect(await fakeClient.pendingNotificationRequests().isEmpty)
        #expect(fakeClient.removedIdentifiers.contains(ReminderScheduler.reminderIdentifier))
    }

    @Test("Reminder scheduler: time change updates hour and minute date components trigger")
    func reminderTimeChange() async throws {
        let fakeClient = FakeNotificationCenterClient()
        fakeClient.authStatus = .authorized
        let scheduler = ReminderScheduler(client: fakeClient)

        _ = await scheduler.enable(minutes: 20 * 60, locale: Self.englishLocale)
        var pending = await fakeClient.pendingNotificationRequests()
        var trigger = try #require(pending.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 20)
        #expect(trigger.dateComponents.minute == 0)

        try await scheduler.scheduleNotification(minutes: 22 * 60 + 15, locale: Self.englishLocale)
        pending = await fakeClient.pendingNotificationRequests()
        #expect(pending.count == 1)
        trigger = try #require(pending.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 22)
        #expect(trigger.dateComponents.minute == 15)
    }

    @Test("Reminder scheduler: syncFromSettings re-schedules on launch or cancels when disabled")
    func reminderSyncFromSettings() async throws {
        let fakeClient = FakeNotificationCenterClient()
        fakeClient.authStatus = .authorized
        let scheduler = ReminderScheduler(client: fakeClient)

        // Enabled in settings: re-schedules notification
        let resultEnabled = await scheduler.syncFromSettings(
            enabled: true,
            reminderMinutes: 19 * 60 + 45,
            locale: Self.englishLocale
        )
        #expect(resultEnabled == .scheduled)
        var pending = await fakeClient.pendingNotificationRequests()
        #expect(pending.count == 1)
        let trigger = try #require(pending.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 19)
        #expect(trigger.dateComponents.minute == 45)

        // Disabled in settings: cancels notification
        let resultDisabled = await scheduler.syncFromSettings(
            enabled: false,
            reminderMinutes: 19 * 60 + 45,
            locale: Self.englishLocale
        )
        #expect(resultDisabled == .scheduled)
        pending = await fakeClient.pendingNotificationRequests()
        #expect(pending.isEmpty)
    }

    // MARK: - App Lock State Machine Tests

    @Test("App lock state machine: launch locked when enabled, unlocked when disabled")
    @MainActor
    func appLockLaunchLocked() {
        let fakeAuth = FakeAppLockAuthenticator()

        let machineLocked = AppLockStateMachine(isAppLockEnabled: true, authenticator: fakeAuth)
        #expect(machineLocked.isAppLockEnabled == true)
        #expect(machineLocked.isLocked == true)
        #expect(machineLocked.isShielded == true)

        let machineUnlocked = AppLockStateMachine(isAppLockEnabled: false, authenticator: fakeAuth)
        #expect(machineUnlocked.isAppLockEnabled == false)
        #expect(machineUnlocked.isLocked == false)
        #expect(machineUnlocked.isShielded == false)
    }

    @Test("App lock state machine: unlock success transitions to unlocked; failure stays locked")
    @MainActor
    func appLockUnlockSuccessAndFailure() async {
        let fakeAuth = FakeAppLockAuthenticator()
        let machine = AppLockStateMachine(isAppLockEnabled: true, authenticator: fakeAuth)

        // Failure
        fakeAuth.shouldSucceed = false
        let failureSuccess = await machine.unlock(reason: "Unlock Half Unit")
        #expect(failureSuccess == false)
        #expect(machine.isLocked == true)
        #expect(machine.isShielded == true)
        #expect(fakeAuth.authenticateCallCount == 1)
        #expect(fakeAuth.lastReason == "Unlock Half Unit")

        // Success
        fakeAuth.shouldSucceed = true
        let success = await machine.unlock(reason: "Unlock Half Unit")
        #expect(success == true)
        #expect(machine.isLocked == false)
        #expect(machine.isShielded == false)
        #expect(fakeAuth.authenticateCallCount == 2)
    }

    @Test(
        "App lock state machine: background -> locked again; inactive shields privacy overlay without locking until background"
    )
    @MainActor
    func appLockBackgroundLifecycle() async {
        let fakeAuth = FakeAppLockAuthenticator()
        fakeAuth.shouldSucceed = true
        let machine = AppLockStateMachine(isAppLockEnabled: true, authenticator: fakeAuth)

        // Unlock first
        _ = await machine.unlock(reason: "Test")
        #expect(machine.isLocked == false)
        #expect(machine.isShielded == false)

        // Swipe up to app switcher -> inactive: shielded for snapshot, but still unlocked if user comes back
        machine.handleScenePhaseChange(to: .inactive)
        #expect(machine.isShielded == true)
        #expect(machine.isLocked == false)

        // User taps back into app from app switcher without going to background
        machine.handleScenePhaseChange(to: .active)
        #expect(machine.isShielded == false)
        #expect(machine.isLocked == false)

        // Now app goes to background
        machine.handleScenePhaseChange(to: .inactive)
        machine.handleScenePhaseChange(to: .background)
        #expect(machine.isLocked == true)
        #expect(machine.isShielded == true)

        // Return to active foreground -> must remain locked and shielded
        machine.handleScenePhaseChange(to: .active)
        #expect(machine.isLocked == true)
        #expect(machine.isShielded == true)
    }

    @Test("App lock state machine: lock disabled has no privacy shield on background")
    @MainActor
    func appLockDisabledNoShield() {
        let fakeAuth = FakeAppLockAuthenticator()
        let machine = AppLockStateMachine(isAppLockEnabled: false, authenticator: fakeAuth)

        machine.handleScenePhaseChange(to: .inactive)
        #expect(machine.isShielded == false)
        machine.handleScenePhaseChange(to: .background)
        #expect(machine.isShielded == false)
        #expect(machine.isLocked == false)
        machine.handleScenePhaseChange(to: .active)
        #expect(machine.isShielded == false)
        #expect(machine.isLocked == false)
    }

    @Test(
        "AppLockShieldContainerView and state machine hide content from accessibility and disable hit testing while shielded"
    )
    @MainActor
    func appLockShieldAccessibilityState() async {
        let fakeAuth = FakeAppLockAuthenticator()
        fakeAuth.shouldSucceed = true
        let machine = AppLockStateMachine(isAppLockEnabled: true, authenticator: fakeAuth)

        let container = AppLockShieldContainerView(stateMachine: machine) {
            Text("Sensitive Data")
        }

        // On launch when enabled: shielded, so content is NOT accessible
        #expect(machine.isShielded == true)
        #expect(machine.isContentAccessible == false)
        #expect(container.isContentAccessible == false)

        // After unlock succeeds: unshielded, so content IS accessible
        _ = await machine.unlock(reason: "Unlock")
        #expect(machine.isShielded == false)
        #expect(machine.isContentAccessible == true)
        #expect(container.isContentAccessible == true)

        // On inactive / background: shielded, content is NOT accessible
        machine.handleScenePhaseChange(to: .inactive)
        #expect(machine.isShielded == true)
        #expect(machine.isContentAccessible == false)
        #expect(container.isContentAccessible == false)

        machine.handleScenePhaseChange(to: .background)
        #expect(machine.isShielded == true)
        #expect(machine.isContentAccessible == false)
        #expect(container.isContentAccessible == false)

        // When app lock is disabled: content is always accessible
        machine.disable()
        #expect(machine.isShielded == false)
        #expect(machine.isContentAccessible == true)
        #expect(container.isContentAccessible == true)

        machine.handleScenePhaseChange(to: .background)
        #expect(machine.isShielded == false)
        #expect(machine.isContentAccessible == true)
        #expect(container.isContentAccessible == true)
    }

    @Test("App lock state machine: toggle-on requires auth and handles unavailable/failure/success")
    @MainActor
    func appLockToggleOnRequiresAuth() async {
        let fakeAuth = FakeAppLockAuthenticator()
        let machine = AppLockStateMachine(isAppLockEnabled: false, authenticator: fakeAuth)

        // 1. Unavailable
        fakeAuth.isAvailable = false
        let unavailResult = await machine.requestEnable(reason: "Enable")
        #expect(unavailResult == .unavailable)
        #expect(machine.isAppLockEnabled == false)
        #expect(fakeAuth.authenticateCallCount == 0)

        // 2. Available but auth failed
        fakeAuth.isAvailable = true
        fakeAuth.shouldSucceed = false
        let failResult = await machine.requestEnable(reason: "Enable")
        #expect(failResult == .failed)
        #expect(machine.isAppLockEnabled == false)
        #expect(fakeAuth.authenticateCallCount == 1)

        // 3. Available and auth succeeded
        fakeAuth.shouldSucceed = true
        let successResult = await machine.requestEnable(reason: "Enable")
        #expect(successResult == .enabled)
        #expect(machine.isAppLockEnabled == true)
        #expect(machine.isLocked == false)
        #expect(machine.isShielded == false)
        #expect(fakeAuth.authenticateCallCount == 2)

        // 4. Disable
        machine.disable()
        #expect(machine.isAppLockEnabled == false)
        #expect(machine.isLocked == false)
        #expect(machine.isShielded == false)
    }

    // MARK: - Settings Integration Tests

    @Test("Settings screen snapshot and actions: reminders and app lock toggle, timing, and persistence")
    @MainActor
    func settingsRemindersAndLockActions() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let service = LogService(
            context: container.mainContext,
            now: { t0 },
            timeZone: { TimeZone(identifier: "UTC")! }
        )
        let healthClient = FakeRemindersHealthClient()
        let healthSync = HealthSync(
            context: container.mainContext,
            client: healthClient,
            isEnabled: { true }
        )
        let fakeNotifyClient = FakeNotificationCenterClient()
        fakeNotifyClient.authStatus = .authorized
        let reminderScheduler = ReminderScheduler(client: fakeNotifyClient)

        let fakeAuth = FakeAppLockAuthenticator()
        fakeAuth.isAvailable = true
        fakeAuth.shouldSucceed = true
        let lockStateMachine = AppLockStateMachine(isAppLockEnabled: false, authenticator: fakeAuth)

        // Baseline snapshot
        let snapshot0 = try SettingsScreenSnapshot.load(
            from: service,
            healthSync: healthSync,
            authenticator: fakeAuth,
            locale: Self.englishLocale
        )
        #expect(snapshot0.remindersEnabled == false)
        #expect(snapshot0.reminderMinutes == ReminderScheduler.defaultReminderMinutes)
        #expect(snapshot0.appLockEnabled == false)
        #expect(snapshot0.isAppLockAvailable == true)

        // Enable reminders
        let reminderResult = await SettingsActions.setRemindersEnabled(
            true,
            minutes: 20 * 60 + 30,
            logService: service,
            reminderScheduler: reminderScheduler,
            locale: Self.englishLocale
        )
        #expect(reminderResult == .scheduled)

        let settingsAfterReminder = try service.settings()
        #expect(settingsAfterReminder.remindersEnabled == true)
        #expect(settingsAfterReminder.reminderMinutes == 20 * 60 + 30)

        // Update reminder time
        try await SettingsActions.setReminderTime(
            minutes: 21 * 60,
            logService: service,
            reminderScheduler: reminderScheduler,
            locale: Self.englishLocale
        )
        let settingsAfterTime = try service.settings()
        #expect(settingsAfterTime.reminderMinutes == 21 * 60)

        // Enable App Lock
        let lockResult = await SettingsActions.setAppLockEnabled(
            true,
            logService: service,
            stateMachine: lockStateMachine,
            authReason: "Test"
        )
        #expect(lockResult == .enabled)
        let settingsAfterLock = try service.settings()
        #expect(settingsAfterLock.appLockEnabled == true)

        // Verify loaded snapshot reflects updated settings
        let snapshot1 = try SettingsScreenSnapshot.load(
            from: service,
            healthSync: healthSync,
            authenticator: fakeAuth,
            locale: Self.englishLocale
        )
        #expect(snapshot1.remindersEnabled == true)
        #expect(snapshot1.reminderMinutes == 21 * 60)
        #expect(snapshot1.appLockEnabled == true)

        // Disable App Lock
        let disableLockResult = await SettingsActions.setAppLockEnabled(
            false,
            logService: service,
            stateMachine: lockStateMachine,
            authReason: "Test"
        )
        #expect(disableLockResult == .enabled)
        let settingsAfterLockDisabled = try service.settings()
        #expect(settingsAfterLockDisabled.appLockEnabled == false)

        // Disable reminders
        let disableReminderResult = await SettingsActions.setRemindersEnabled(
            false,
            minutes: nil,
            logService: service,
            reminderScheduler: reminderScheduler,
            locale: Self.englishLocale
        )
        #expect(disableReminderResult == .scheduled)
        let settingsAfterRemindersDisabled = try service.settings()
        #expect(settingsAfterRemindersDisabled.remindersEnabled == false)
    }
}
