import Foundation
import HalfUnitCore
import OSLog
import SwiftData
import SwiftUI

@main
struct HalfUnitApp: App {
    private static let logger = Logger(subsystem: "es.opinasdeque.halfunit", category: "Persistence")
    static var isHealthSyncEnabled: Bool {
        get { HealthPreferences.isSyncEnabled() }
        set { HealthPreferences.setSyncEnabled(newValue) }
    }

    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    private let logService: LogService
    private let healthSync: HealthSync
    private let dayBoundaryScheduler: DayBoundaryScheduler
    private let phoneSessionBridge: PhoneSessionBridge
    private let reminderScheduler: ReminderScheduler
    private let appLockStateMachine: AppLockStateMachine

    init() {
        let container = SharedStore.shared
        let service = LogService(
            context: container.mainContext,
            now: Date.init,
            timeZone: { TimeZone.autoupdatingCurrent }
        )
        let health = HealthSync(
            context: container.mainContext,
            client: HealthKitStoreClient.shared,
            isEnabled: { Self.isHealthSyncEnabled }
        )
        let scheduler = DayBoundaryScheduler(
            now: Date.init,
            timeZone: { TimeZone.autoupdatingCurrent }
        )

        do {
            try service.seedDefaultPresetsIfNeeded()
        } catch {
            Self.logger.error("Failed to seed default presets: \(error.localizedDescription, privacy: .private)")
        }

        let sessionBridge = PhoneSessionBridge(
            context: container.mainContext,
            logService: service,
            healthSync: health,
            now: Date.init,
            dayBoundaryScheduler: scheduler
        )

        let initialSettings = try? service.settings()
        let lockEnabled = initialSettings?.appLockEnabled ?? false
        let machine = AppLockStateMachine.shared
        machine.configure(isAppLockEnabled: lockEnabled)
        let reminders = ReminderScheduler.shared

        self.modelContainer = container
        self.logService = service
        self.healthSync = health
        self.dayBoundaryScheduler = scheduler
        self.phoneSessionBridge = sessionBridge
        self.reminderScheduler = reminders
        self.appLockStateMachine = machine

        Task { @MainActor in
            await Self.reconcileAndPurgeTombstones(
                logService: service,
                healthSync: health,
                phoneSessionBridge: sessionBridge
            )
            if let settings = try? service.settings() {
                _ = await reminders.syncFromSettings(
                    enabled: settings.remindersEnabled,
                    reminderMinutes: settings.reminderMinutes
                )
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppLockShieldContainerView(stateMachine: appLockStateMachine) {
                RootTabView(
                    logService: logService,
                    healthSync: healthSync,
                    dayBoundaryScheduler: dayBoundaryScheduler
                )
            }
            .task {
                if appLockStateMachine.isAppLockEnabled && appLockStateMachine.isLocked {
                    _ = await appLockStateMachine.unlock(
                        reason: AppLocalization.string("appLock.authReason.unlock")
                    )
                }
                if let settings = try? logService.settings() {
                    _ = await reminderScheduler.syncFromSettings(
                        enabled: settings.remindersEnabled,
                        reminderMinutes: settings.reminderMinutes
                    )
                }
            }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            appLockStateMachine.handleScenePhaseChange(to: newPhase)
            guard newPhase == .active else {
                return
            }
            if appLockStateMachine.isAppLockEnabled && appLockStateMachine.isLocked {
                Task { @MainActor in
                    _ = await appLockStateMachine.unlock(
                        reason: AppLocalization.string("appLock.authReason.unlock")
                    )
                }
            }
            Task { @MainActor in
                await Self.reconcileAndPurgeTombstones(
                    logService: logService,
                    healthSync: healthSync,
                    phoneSessionBridge: phoneSessionBridge
                )
                if let settings = try? logService.settings() {
                    _ = await reminderScheduler.syncFromSettings(
                        enabled: settings.remindersEnabled,
                        reminderMinutes: settings.reminderMinutes
                    )
                }
            }
        }
    }

    @MainActor
    static func reconcileAndPurgeTombstones(
        logService: LogService,
        healthSync: HealthSync,
        phoneSessionBridge: PhoneSessionBridge? = nil
    ) async {
        do {
            if let phoneSessionBridge {
                _ = try phoneSessionBridge.performWithoutSaveObserver {
                    try logService.dedupeDrinks()
                }
            } else {
                _ = try logService.dedupeDrinks()
            }
        } catch {
            logger.error("Failed to deduplicate drinks: \(error.localizedDescription, privacy: .private)")
        }

        await reconcileHealth(healthSync: healthSync)

        do {
            if let phoneSessionBridge {
                _ = try phoneSessionBridge.performWithoutSaveObserver {
                    try logService.purgeTombstones()
                }
            } else {
                _ = try logService.purgeTombstones()
            }
        } catch {
            logger.error("Failed to purge tombstones: \(error.localizedDescription, privacy: .private)")
        }

        phoneSessionBridge?.pushCurrentStateContext()
    }

    @MainActor
    static func reconcileHealth(healthSync: HealthSync) async {
        let status = await healthSync.reconcile()
        if case .failed(let reason) = status {
            logger.error("Health sync reconcile failed: \(reason, privacy: .public)")
        }
    }
}
