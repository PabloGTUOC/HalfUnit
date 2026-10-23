import CoreData
import Foundation
import HalfUnitCore
import OSLog
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct TodayView: View {
    private static let logger = Logger(subsystem: "es.opinasdeque.halfunit", category: "TodayView")
    private static let externalChangeDebounceDuration: Duration = .milliseconds(300)

    private struct UndoBannerState: Equatable {
        let drink: Drink
        let loggedMessage: String

        static func == (lhs: UndoBannerState, rhs: UndoBannerState) -> Bool {
            lhs.drink.id == rhs.drink.id && lhs.loggedMessage == rhs.loggedMessage
        }
    }

    private struct BoundaryScheduleToken: Equatable {
        let boundaryHour: Int
        let revision: Int
    }

    let logService: LogService
    let healthSync: HealthSync
    let dayBoundaryScheduler: DayBoundaryScheduler

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    @ScaledMetric(relativeTo: .title2) private var symbolFrame: CGFloat = 36

    @State private var presets: [Preset] = []
    @State private var screenSnapshot: TodayScreenSnapshot?
    @State private var undoBanner: UndoBannerState?
    @State private var logHapticTrigger = 0
    @State private var isShowingSettings = false
    @State private var presetForCustomLog: Preset?
    @State private var isShowingCustomDatePicker = false
    @State private var dayBoundaryHour = LogicalDay.defaultBoundaryHour
    @State private var boundaryScheduleRevision = 0
    @State private var externalChangeReloadTask: Task<Void, Never>?

    private var gridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let snapshot = screenSnapshot {
                        streakCardSection(model: snapshot.streakCard)
                    }

                    presetsGridSection

                    if let snapshot = screenSnapshot {
                        todayDrinksSection(snapshot: snapshot)
                    }
                }
                .padding()
            }
            .navigationTitle("tab.today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(BrandColors.accent)
                    }
                    .accessibilityLabel(Text("settings.open.accessibility"))
                }
            }
            .background(BrandColors.appBackground.ignoresSafeArea())
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(
                    logService: logService,
                    healthSync: healthSync
                )
            }
            .sheet(isPresented: $isShowingCustomDatePicker) {
                if let preset = presetForCustomLog {
                    LogEarlierDatePickerSheet(
                        preset: preset,
                        now: dayBoundaryScheduler.now,
                        timeZone: dayBoundaryScheduler.timeZone,
                        locale: locale,
                        onLog: { timestamp in
                            logPresetAt(preset, at: timestamp)
                            isShowingCustomDatePicker = false
                        },
                        onDismiss: {
                            isShowingCustomDatePicker = false
                        }
                    )
                }
            }
            .onAppear {
                reloadState()
            }
            .safeAreaInset(edge: .bottom) {
                if let banner = undoBanner {
                    undoBannerView(banner)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sensoryFeedback(.success, trigger: logHapticTrigger)
            .task {
                reloadState()
            }
            .task(id: BoundaryScheduleToken(boundaryHour: dayBoundaryHour, revision: boundaryScheduleRevision)) {
                await runDayBoundaryScheduleLoop(boundaryHour: dayBoundaryHour)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }
                reloadAndRescheduleBoundary()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
                    .receive(on: RunLoop.main)
            ) { _ in
                reloadAndRescheduleBoundary()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                reloadAndRescheduleBoundary()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                reloadAndRescheduleBoundary()
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
            .task(id: undoBanner?.drink.id) {
                guard undoBanner != nil else {
                    return
                }
                do {
                    try await Task.sleep(for: .seconds(5))
                    withAnimation {
                        undoBanner = nil
                    }
                } catch {
                    // Task cancelled when a newer drink is logged or undone.
                }
            }
        }
    }

    private func streakCardSection(model: StreakCardModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.headline)
                .font(.title.bold())
                .foregroundStyle(BrandColors.streakCardText)
                .fixedSize(horizontal: false, vertical: true)

            if let previousStreakText = model.previousStreakText {
                Text(previousStreakText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BrandColors.streakCardText.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(model.subtitle)
                .font(.subheadline)
                .foregroundStyle(BrandColors.streakCardText.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BrandColors.streakCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(BrandColors.streakCardText.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var presetsGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("today.section.quickLog")
                .font(.headline)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(presets, id: \.id) { preset in
                    Button {
                        logPreset(preset)
                    } label: {
                        HStack(spacing: 12) {
                            PresetPresentation.image(for: PresetPresentation.symbolName(for: preset))
                                .font(.title2)
                                .foregroundStyle(BrandColors.accent)
                                .frame(width: symbolFrame, height: symbolFrame, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(PresetPresentation.localizedName(for: preset, locale: locale))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                Text(PresetPresentation.formattedHU(preset.hu, locale: locale))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(BrandColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        Text(PresetPresentation.accessibilityLabel(for: preset, locale: locale))
                    )
                    .contextMenu {
                        Menu {
                            ForEach(EarlierOffset.allCases) { offset in
                                Button(offset.localizedTitle(locale: locale)) {
                                    logPresetEarlier(preset, offset: offset)
                                }
                            }
                            Button {
                                presetForCustomLog = preset
                                isShowingCustomDatePicker = true
                            } label: {
                                Label("today.logEarlier.chooseDateTime", systemImage: "calendar")
                            }
                        } label: {
                            Label("today.logEarlier.menuTitle", systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
            }
        }
    }

    private func todayDrinksSection(snapshot: TodayScreenSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("today.section.drinks")
                    .font(.headline)

                Spacer()

                Text(snapshot.todayTotalText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if snapshot.todayDrinks.isEmpty {
                Text("today.drinks.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(snapshot.todayDrinks) { row in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                    .font(.body.weight(.medium))
                                Text(row.timeText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(row.huText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(BrandColors.cardBackground)
                        )
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func undoBannerView(_ banner: UndoBannerState) -> some View {
        HStack(spacing: 12) {
            Text(banner.loggedMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BrandColors.highlightText)

            Spacer()

            Button("undo.action") {
                undoLastDrink(banner.drink)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(BrandColors.highlightText)
            .accessibilityLabel(Text("undo.accessibility"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BrandColors.highlightBackground)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        )
    }

    private func reloadState() {
        do {
            try logService.seedDefaultPresetsIfNeeded()
            presets = try logService.presets()
            screenSnapshot = try TodayScreenSnapshot.load(from: logService, locale: locale)
            let currentSettings = try logService.settings()
            dayBoundaryHour = currentSettings.dayBoundaryHour
        } catch {
            Self.logger.error("Failed to load Today state: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func reloadAndRescheduleBoundary() {
        reloadState()
        boundaryScheduleRevision += 1
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

    private func runDayBoundaryScheduleLoop(boundaryHour: Int) async {
        var referenceDate = dayBoundaryScheduler.now()
        while !Task.isCancelled {
            let nextBoundary = dayBoundaryScheduler.nextBoundaryDate(
                after: referenceDate,
                boundaryHour: boundaryHour
            )
            let delay = max(0.05, nextBoundary.timeIntervalSince(dayBoundaryScheduler.now()))
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            reloadState()
            referenceDate = max(dayBoundaryScheduler.now(), nextBoundary)
        }
    }

    private func logPreset(_ preset: Preset) {
        logPresetAt(preset, at: nil)
    }

    private func logPresetEarlier(_ preset: Preset, offset: EarlierOffset) {
        let targetTimestamp = offset.targetTimestamp(from: dayBoundaryScheduler.now())
        logPresetAt(preset, at: targetTimestamp)
    }

    private func logPresetAt(_ preset: Preset, at timestamp: Date?) {
        do {
            let (drink, _) = try Self.logAndReconcile(
                preset: preset,
                at: timestamp,
                logService: logService,
                healthSync: healthSync
            )
            logHapticTrigger += 1
            let localizedDrinkName = PresetPresentation.localizedName(for: preset, locale: locale)
            let format = AppLocalization.string("undo.banner.logged", locale: locale)
            let message = String(format: format, locale: locale, localizedDrinkName)
            withAnimation {
                undoBanner = UndoBannerState(drink: drink, loggedMessage: message)
            }
            reloadState()
        } catch {
            Self.logger.error("Failed to log drink: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func undoLastDrink(_ drink: Drink) {
        do {
            _ = try Self.undoAndReconcile(
                drink: drink,
                logService: logService,
                healthSync: healthSync
            )
            withAnimation {
                undoBanner = nil
            }
            reloadState()
        } catch {
            Self.logger.error("Failed to undo drink: \(error.localizedDescription, privacy: .private)")
        }
    }

    @MainActor
    @discardableResult
    static func logAndReconcile(
        preset: Preset,
        at timestamp: Date? = nil,
        logService: LogService,
        healthSync: HealthSync
    ) throws -> (drink: Drink, reconcileTask: Task<HealthSync.Status, Never>) {
        let drink = try logService.log(preset: preset, at: timestamp, source: .phone)
        WidgetCenter.shared.reloadAllTimelines()
        let task = Task { @MainActor in
            await HalfUnitApp.reconcileHealth(healthSync: healthSync)
            return healthSync.lastStatus
        }
        return (drink, task)
    }

    @MainActor
    @discardableResult
    static func undoAndReconcile(
        drink: Drink,
        logService: LogService,
        healthSync: HealthSync
    ) throws -> Task<HealthSync.Status, Never> {
        try logService.undo(drink)
        WidgetCenter.shared.reloadAllTimelines()
        return Task { @MainActor in
            await HalfUnitApp.reconcileHealth(healthSync: healthSync)
            return healthSync.lastStatus
        }
    }
}

struct LogEarlierDatePickerSheet: View {
    let preset: Preset
    let now: () -> Date
    let timeZone: () -> TimeZone
    let locale: Locale
    let onLog: (Date) -> Void
    let onDismiss: () -> Void

    @State private var selectedDate: Date

    init(
        preset: Preset,
        now: @escaping () -> Date,
        timeZone: @escaping () -> TimeZone,
        locale: Locale,
        onLog: @escaping (Date) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.preset = preset
        self.now = now
        self.timeZone = timeZone
        self.locale = locale
        self.onLog = onLog
        self.onDismiss = onDismiss
        _selectedDate = State(initialValue: now())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    PresetPresentation.image(for: PresetPresentation.symbolName(for: preset))
                        .font(.title2)
                        .foregroundStyle(BrandColors.accent)
                        .frame(width: 32, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(PresetPresentation.localizedName(for: preset, locale: locale))
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(PresetPresentation.formattedHU(preset.hu, locale: locale))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BrandColors.cardBackground)
                )

                DatePicker(
                    "today.logEarlier.datePrompt",
                    selection: $selectedDate,
                    in: ...now(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .environment(\.timeZone, timeZone())
                .environment(\.locale, locale)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                Spacer()
            }
            .padding()
            .navigationTitle("today.logEarlier.sheetTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("today.logEarlier.cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("today.logEarlier.logAction") {
                        let validatedDate = min(selectedDate, now())
                        onLog(validatedDate)
                    }
                    .font(.headline)
                }
            }
        }
    }
}
