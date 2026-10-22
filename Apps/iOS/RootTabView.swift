import HalfUnitCore
import SwiftUI

struct RootTabView: View {
    let logService: LogService
    let healthSync: HealthSync
    let dayBoundaryScheduler: DayBoundaryScheduler

    var body: some View {
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
    }
}
