import Charts
import CoreData
import Foundation
import HalfUnitCore
import OSLog
import SwiftData
import SwiftUI

struct InsightsView: View {
    private static let logger = Logger(subsystem: "es.opinasdeque.halfunit", category: "InsightsView")
    private static let externalChangeDebounceDuration: Duration = .milliseconds(300)

    let logService: LogService
    let now: @Sendable () -> Date
    let timeZone: @Sendable () -> TimeZone

    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedPeriodOption: InsightsPeriodOption = .last3Months
    @State private var customFromDate: Date
    @State private var customThroughDate: Date
    @State private var dayBoundaryHour = LogicalDay.defaultBoundaryHour
    @State private var snapshot: InsightsScreenSnapshot?
    @State private var externalChangeReloadTask: Task<Void, Never>?

    init(
        logService: LogService,
        now: @escaping @Sendable () -> Date = Date.init,
        timeZone: @escaping @Sendable () -> TimeZone = { TimeZone.autoupdatingCurrent }
    ) {
        self.logService = logService
        self.now = now
        self.timeZone = timeZone
        let currentDate = now()
        self._customFromDate = State(initialValue: currentDate.addingTimeInterval(-29 * 86_400))
        self._customThroughDate = State(initialValue: currentDate)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot {
                    if snapshot.isEmpty {
                        ContentUnavailableView(
                            "insights.empty.title",
                            systemImage: "chart.bar.xaxis",
                            description: Text("insights.empty.subtitle")
                        )
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                periodPickerSection
                                summarySection(snapshot.summary)
                                heatmapSection(snapshot: snapshot)
                                weeklyChartSection(snapshot: snapshot)
                                weekdaySection(snapshot: snapshot)
                                drinkTypeSection(snapshot: snapshot)
                                streaksSection(snapshot.streaks)
                            }
                            .padding()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("tab.insights")
            .task {
                reloadState()
            }
            .onChange(of: selectedPeriodOption) { _, _ in
                reloadState()
            }
            .onChange(of: customFromDate) { _, _ in
                if selectedPeriodOption == .custom {
                    reloadState()
                }
            }
            .onChange(of: customThroughDate) { _, _ in
                if selectedPeriodOption == .custom {
                    reloadState()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }
                reloadState()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: ModelContext.didSave)
                    .receive(on: RunLoop.main)
            ) { _ in
                scheduleExternalChangeReload()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                scheduleExternalChangeReload()
            }
            .onDisappear {
                externalChangeReloadTask?.cancel()
                externalChangeReloadTask = nil
            }
        }
    }

    private var periodPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("insights.period.picker", selection: $selectedPeriodOption) {
                ForEach(InsightsPeriodOption.allCases) { option in
                    Text(LocalizedStringKey(option.pickerLabelKey))
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(Text("insights.period.picker"))

            if selectedPeriodOption == .custom {
                VStack(spacing: 8) {
                    DatePicker(
                        "insights.period.custom.from",
                        selection: $customFromDate,
                        displayedComponents: [.date]
                    )
                    DatePicker(
                        "insights.period.custom.through",
                        selection: $customThroughDate,
                        displayedComponents: [.date]
                    )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    private func summarySection(_ summary: InsightsSummaryModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("insights.summary.title")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.drinkingDaysText)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    Text(summary.drinkingDayShareText)
                    Text("·")
                    Text(summary.alcoholFreeDaysText)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let deltaText = summary.deltaText {
                    Text(deltaText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.teal.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.teal.opacity(0.24), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                metricCard(
                    title: "insights.summary.total.label",
                    primary: summary.totalPrimaryText,
                    secondary: summary.totalSecondaryText
                )

                metricCard(
                    title: "insights.summary.averagePerDrinkingDay.label",
                    primary: summary.averagePerDrinkingDayText,
                    secondary: nil
                )
            }

            metricCard(
                title: "insights.summary.heaviestDay.label",
                primary: summary.heaviestDayText,
                secondary: nil
            )
        }
    }

    private func metricCard(
        title: LocalizedStringKey,
        primary: String,
        secondary: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(primary)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            if let secondary {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private func heatmapSection(snapshot: InsightsScreenSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights.heatmap.title")
                .font(.headline)

            if snapshot.heatmapCells.isEmpty {
                Text("insights.drinkType.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    heatmapGrid(cells: snapshot.heatmapCells)
                        .padding(.vertical, 4)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .accessibilityLabel(Text(snapshot.heatmapSummaryAccessibilityLabel))
            }
        }
    }

    private func heatmapGrid(cells: [InsightsHeatmapCellModel]) -> some View {
        let groupedByWeek = Dictionary(grouping: cells, by: \.weekIndex)
        let maxWeekIndex = cells.map(\.weekIndex).max() ?? 0
        let collapseIndividualAccessibility = cells.count > 120

        return HStack(alignment: .top, spacing: 4) {
            ForEach(0...maxWeekIndex, id: \.self) { weekIndex in
                let weekCells = groupedByWeek[weekIndex] ?? []
                let cellByWeekday = Dictionary(
                    uniqueKeysWithValues: weekCells.map { ($0.weekday, $0) }
                )
                VStack(spacing: 4) {
                    ForEach(Weekday.allCases, id: \.rawValue) { weekday in
                        if let cell = cellByWeekday[weekday] {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    cell.intensity > 0
                                        ? Color.teal.opacity(cell.intensity)
                                        : Color.secondary.opacity(0.18)
                                )
                                .frame(width: 14, height: 14)
                                .accessibilityHidden(collapseIndividualAccessibility)
                                .accessibilityLabel(Text(cell.accessibilityLabel))
                        } else {
                            Color.clear
                                .frame(width: 14, height: 14)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    private func weeklyChartSection(snapshot: InsightsScreenSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights.weekly.title")
                .font(.headline)

            Chart(snapshot.weeklyBars) { bar in
                BarMark(
                    x: .value("Week", bar.weekStartDate, unit: .weekOfYear),
                    y: .value("Amount", bar.displayValue)
                )
                .foregroundStyle(Color.teal.gradient)
                .cornerRadius(3)
                .accessibilityLabel(bar.accessibilityLabel)
            }
            .frame(height: 180)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .accessibilityLabel(Text(snapshot.weeklySummaryAccessibilityLabel))
        }
    }

    private func weekdaySection(snapshot: InsightsScreenSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights.weekday.title")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                if let topSentence = snapshot.topWeekdaySentence {
                    Text(topSentence)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                } else {
                    Text("insights.weekday.noDrinkingDays")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    ForEach(snapshot.weekdayRows) { row in
                        HStack(spacing: 10) {
                            Text(row.shortName)
                                .font(.subheadline.weight(row.isTop ? .semibold : .regular))
                                .frame(width: 44, alignment: .leading)

                            GeometryReader { proxy in
                                let fraction =
                                    row.share.map {
                                        min(1.0, max(0.0, NSDecimalNumber(decimal: $0).doubleValue))
                                    } ?? 0
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 8)

                                    Capsule()
                                        .fill(row.isTop ? Color.teal : Color.teal.opacity(0.6))
                                        .frame(width: proxy.size.width * fraction, height: 8)
                                }
                                .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(height: 16)

                            Text("\(row.drinkingDays)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)

                            Text(row.sharePercentText)
                                .font(.caption.monospacedDigit().weight(row.isTop ? .semibold : .regular))
                                .foregroundStyle(row.isTop ? .primary : .secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(row.accessibilityLabel))
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func drinkTypeSection(snapshot: InsightsScreenSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights.drinkType.title")
                .font(.headline)

            if snapshot.drinkTypeRows.isEmpty {
                Text("insights.drinkType.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(snapshot.drinkTypeRows) { row in
                        HStack(spacing: 12) {
                            Image(systemName: row.symbolName)
                                .font(.body)
                                .foregroundStyle(Color.teal)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                    .font(.body.weight(.medium))
                                Text(row.countText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(row.primaryAmountText)
                                    .font(.subheadline.weight(.semibold))
                                if snapshot.displayUnit != .grams {
                                    Text(row.gramsText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func streaksSection(_ streaks: InsightsStreaksModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights.streaks.title")
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                metricCard(
                    title: "insights.streaks.ever",
                    primary: streaks.longestEverText,
                    secondary: nil
                )

                metricCard(
                    title: "insights.streaks.thisYear",
                    primary: streaks.longestThisYearText,
                    secondary: nil
                )
            }
        }
    }

    private func reloadState() {
        do {
            let settings = try logService.settings()
            let resolvedBoundary =
                (0...23).contains(settings.dayBoundaryHour)
                ? settings.dayBoundaryHour
                : LogicalDay.defaultBoundaryHour
            dayBoundaryHour = resolvedBoundary

            let currentZone = timeZone()
            let customFromDay = LogicalDay.of(
                customFromDate,
                boundaryHour: resolvedBoundary,
                timeZone: currentZone
            )
            let customThroughDay = LogicalDay.of(
                customThroughDate,
                boundaryHour: resolvedBoundary,
                timeZone: currentZone
            )

            snapshot = try InsightsScreenSnapshot.load(
                from: logService,
                periodOption: selectedPeriodOption,
                customFrom: customFromDay,
                customThrough: customThroughDay,
                locale: locale
            )
        } catch {
            Self.logger.error(
                "Failed to load Insights state: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    private func scheduleExternalChangeReload() {
        externalChangeReloadTask?.cancel()
        externalChangeReloadTask = Task { @MainActor in
            do {
                try await Task.sleep(for: Self.externalChangeDebounceDuration)
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            reloadState()
        }
    }
}
