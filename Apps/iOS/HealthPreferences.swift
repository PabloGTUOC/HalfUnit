import Foundation

enum HealthPreferences {
    static let syncEnabledKey = "isHealthSyncEnabled"
    static let defaultAppGroupIdentifier = "group.es.opinasdeque.halfunit"

    static var appGroupUserDefaults: UserDefaults {
        let suiteName =
            (Bundle.main.object(forInfoDictionaryKey: "HalfUnitAppGroup") as? String)
            ?? defaultAppGroupIdentifier
        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func isSyncEnabled(in defaults: UserDefaults = appGroupUserDefaults) -> Bool {
        guard defaults.object(forKey: syncEnabledKey) != nil else {
            return true
        }
        return defaults.bool(forKey: syncEnabledKey)
    }

    static func setSyncEnabled(
        _ isEnabled: Bool,
        in defaults: UserDefaults = appGroupUserDefaults
    ) {
        defaults.set(isEnabled, forKey: syncEnabledKey)
    }
}
