import Foundation
import HalfUnitCore
import SwiftData
import SwiftUI
import WidgetKit

struct HalfUnitHomeWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let snapshot: WidgetEntrySnapshot
}

struct HalfUnitHomeTimelineProvider: TimelineProvider {
    let now: @Sendable () -> Date
    let timeZone: @Sendable () -> TimeZone

    init(
        now: @escaping @Sendable () -> Date = Date.init,
        timeZone: @escaping @Sendable () -> TimeZone = { TimeZone.autoupdatingCurrent }
    ) {
        self.now = now
        self.timeZone = timeZone
    }

    func placeholder(in context: Context) -> HalfUnitHomeWidgetEntry {
        HalfUnitHomeWidgetEntry(
            date: now(),
            snapshot: .placeholder()
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping @Sendable (HalfUnitHomeWidgetEntry) -> Void
    ) {
        let currentNow = now()
        if context.isPreview {
            completion(
                HalfUnitHomeWidgetEntry(
                    date: currentNow,
                    snapshot: .placeholder()
                )
            )
            return
        }

        let currentZone = timeZone()
        Task { @MainActor in
            let plan = Self.loadPlan(now: currentNow, timeZone: currentZone)
            let snapshot = plan.entries.first?.snapshot ?? .placeholder()
            completion(HalfUnitHomeWidgetEntry(date: currentNow, snapshot: snapshot))
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<HalfUnitHomeWidgetEntry>) -> Void
    ) {
        let currentNow = now()
        let currentZone = timeZone()
        Task { @MainActor in
            let plan = Self.loadPlan(now: currentNow, timeZone: currentZone)
            let entries = plan.entries.map { slice in
                HalfUnitHomeWidgetEntry(date: slice.date, snapshot: slice.snapshot)
            }
            completion(Timeline(entries: entries, policy: .after(plan.reloadAfterDate)))
        }
    }

    @MainActor
    private static func loadPlan(now: Date, timeZone: TimeZone) -> WidgetTimelinePlan {
        let container = SharedStore.shared
        let service = LogService(
            context: container.mainContext,
            now: { now },
            timeZone: { timeZone }
        )
        if let plan = try? WidgetTimelinePlan.build(
            from: service,
            now: now,
            timeZone: timeZone
        ) {
            return plan
        }

        let nextBoundary = DayBoundaryScheduler.nextBoundaryDate(
            now: now,
            boundaryHour: LogicalDay.defaultBoundaryHour,
            timeZone: timeZone
        )
        let fallbackSnapshot = WidgetEntrySnapshot.placeholder()
        return WidgetTimelinePlan(
            entries: [
                WidgetTimelineSlice(date: now, snapshot: fallbackSnapshot),
                WidgetTimelineSlice(date: nextBoundary, snapshot: fallbackSnapshot),
            ],
            reloadAfterDate: nextBoundary
        )
    }
}

struct HalfUnitHomeWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let entry: HalfUnitHomeWidgetEntry

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemMedium:
                MediumHomeWidgetView(
                    snapshot: entry.snapshot,
                    renderingMode: widgetRenderingMode
                )
            case .systemLarge:
                LargeHomeWidgetView(
                    snapshot: entry.snapshot,
                    renderingMode: widgetRenderingMode
                )
            default:
                SmallHomeWidgetView(
                    snapshot: entry.snapshot,
                    renderingMode: widgetRenderingMode
                )
            }
        }
        .containerBackground(for: .widget) {
            BrandColors.appBackground
        }
    }
}

struct HalfUnitHomeWidget: Widget {
    static let kind = "HalfUnitHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: HalfUnitHomeTimelineProvider()
        ) { entry in
            HalfUnitHomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.ios.displayName")
        .description("widget.ios.description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
