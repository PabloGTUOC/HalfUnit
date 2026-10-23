import HalfUnitCore
import SwiftUI

struct RootTabView: View {
    let logService: LogService
    let healthSync: HealthSync
    let dayBoundaryScheduler: DayBoundaryScheduler

    @State private var isShowingOnboarding = false

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-openSettings") {
            SettingsView(
                logService: logService,
                healthSync: healthSync
            )
        } else if ProcessInfo.processInfo.arguments.contains("-showOnboarding") {
            OnboardingView(
                logService: logService,
                healthSync: healthSync,
                onDismiss: {}
            )
        } else {
            TabView {
                Tab("tab.today", systemImage: "sun.max") {
                    TodayView(
                        logService: logService,
                        healthSync: healthSync,
                        dayBoundaryScheduler: dayBoundaryScheduler
                    )
                }

                Tab("tab.insights", systemImage: "chart.bar.xaxis") {
                    InsightsView(logService: logService)
                }

                Tab("tab.history", systemImage: "clock") {
                    HistoryView(
                        logService: logService,
                        healthSync: healthSync
                    )
                }
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                OnboardingView(
                    logService: logService,
                    healthSync: healthSync,
                    onDismiss: {
                        isShowingOnboarding = false
                    }
                )
            }
            .task {
                if ProcessInfo.processInfo.arguments.contains("-showOnboarding") {
                    isShowingOnboarding = true
                    return
                }
                if OnboardingGating.shouldShowOnboarding(logService: logService) {
                    isShowingOnboarding = true
                }
            }
        }
    }
}
