import Foundation

enum OnboardingPreferences {
    static let completedKey = "hasCompletedOnboarding"

    static func isCompleted(
        in defaults: UserDefaults = HealthPreferences.appGroupUserDefaults
    ) -> Bool {
        defaults.bool(forKey: completedKey)
    }

    static func setCompleted(
        _ completed: Bool = true,
        in defaults: UserDefaults = HealthPreferences.appGroupUserDefaults
    ) {
        defaults.set(completed, forKey: completedKey)
    }

    static func reset(
        in defaults: UserDefaults = HealthPreferences.appGroupUserDefaults
    ) {
        defaults.removeObject(forKey: completedKey)
    }
}
