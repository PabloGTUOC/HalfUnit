import Foundation
import HalfUnitCore
import SwiftData
import SwiftUI
import WidgetKit

struct HalfUnitComplicationEntry: TimelineEntry, Sendable {
    let date: Date
    let snapshot: WidgetEntrySnapshot
}

struct HalfUnitComplicationProvider: TimelineProvider {
    let now: @Sendable () -> Date
    let timeZone: @Sendable () -> TimeZone

    init(
        now: @escaping @Sendable () -> Date = Date.init,
        timeZone: @escaping @Sendable () -> TimeZone = { TimeZone.autoupdatingCurrent }
    ) {
        self.now = now
        self.timeZone = timeZone
    }

    func placeholder(in context: Context) -> HalfUnitComplicationEntry {
        HalfUnitComplicationEntry(
            date: now(),
            snapshot: .placeholder()
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping @Sendable (HalfUnitComplicationEntry) -> Void
    ) {
        let currentNow = now()
        if context.isPreview {
            completion(
                HalfUnitComplicationEntry(
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
            completion(HalfUnitComplicationEntry(date: currentNow, snapshot: snapshot))
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<HalfUnitComplicationEntry>) -> Void
    ) {
        let currentNow = now()
        let currentZone = timeZone()
        Task { @MainActor in
            let plan = Self.loadPlan(now: currentNow, timeZone: currentZone)
            let entries = plan.entries.map { slice in
                HalfUnitComplicationEntry(date: slice.date, snapshot: slice.snapshot)
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

struct HalfUnitStreakComplication: Widget {
    static let kind = "HalfUnitStreakComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: HalfUnitComplicationProvider()
        ) { entry in
            HalfUnitComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("widget.watch.displayName")
        .description("widget.watch.description")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
        ])
    }
}

struct HalfUnitComplicationEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: HalfUnitComplicationEntry

    var body: some View {
        Group {
            switch widgetFamily {
            case .accessoryRectangular:
                RectangularComplicationView(snapshot: entry.snapshot)
            case .accessoryCorner:
                CornerComplicationView(snapshot: entry.snapshot)
            default:
                CircularComplicationView(snapshot: entry.snapshot)
            }
        }
        .widgetURL(URL(string: "halfunit://logger"))
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

private struct CircularComplicationView: View {
    let snapshot: WidgetEntrySnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(snapshot.currentStreakDays)")
                    .font(.system(.title3, design: .rounded).bold())
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("widget.watch.daysUnit")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(snapshot.streakAccessibilityLabel))
    }
}

private struct RectangularComplicationView: View {
    let snapshot: WidgetEntrySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.watchDaysHeadlineText)
                .font(.headline.bold())
                .widgetAccentable()
                .lineLimit(1)

            Text(snapshot.watchSubtitleText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(snapshot.streakAccessibilityLabel))
    }
}

private struct CornerComplicationView: View {
    let snapshot: WidgetEntrySnapshot

    var body: some View {
        Text(snapshot.watchShortDaysText)
            .font(.system(.title3, design: .rounded).bold())
            .widgetAccentable()
            .widgetCurvesContent()
            .widgetLabel {
                Text(snapshot.watchSubtitleText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(snapshot.streakAccessibilityLabel))
    }
}
