import Foundation
import HalfUnitCore

enum OnboardingGating {
    @MainActor
    static func shouldShowOnboarding(
        logService: LogService,
        defaults: UserDefaults = HealthPreferences.appGroupUserDefaults
    ) -> Bool {
        if OnboardingPreferences.isCompleted(in: defaults) {
            return false
        }
        do {
            let drinks = try logService.drinks(includeDeleted: true)
            if !drinks.isEmpty {
                OnboardingPreferences.setCompleted(true, in: defaults)
                return false
            }
        } catch {
            // If fetch fails, fall through to showing onboarding
        }
        return true
    }
}
