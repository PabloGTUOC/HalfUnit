import HalfUnitCore
import SwiftUI

struct RootTabView: View {
    let logService: LogService

    var body: some View {
        TabView {
            Tab("tab.today", systemImage: "sun.max") {
                TodayView(logService: logService)
            }

            Tab("tab.insights", systemImage: "chart.bar.xaxis") {
                PlaceholderTabView(
                    titleKey: "tab.insights",
                    systemImage: "chart.bar.xaxis"
                )
            }

            Tab("tab.history", systemImage: "clock") {
                PlaceholderTabView(
                    titleKey: "tab.history",
                    systemImage: "clock"
                )
            }
        }
    }
}
