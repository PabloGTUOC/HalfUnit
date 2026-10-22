import Foundation
import HalfUnitCore
import OSLog
import SwiftData
import SwiftUI
import WidgetKit

struct WatchLoggerView: View {
    private static let logger = Logger(
        subsystem: "es.opinasdeque.halfunit.watchkitapp",
        category: "WatchLoggerView"
    )

    private struct UndoBannerState: Equatable {
        let drinkId: UUID
        let loggedMessage: String
    }

    let logService: LogService
    let now: @Sendable () -> Date
    let timeZone: @Sendable () -> TimeZone

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    @State private var presets: [Preset] = []
    @State private var snapshot: WatchLoggerSnapshot?
    @State private var undoBanner: UndoBannerState?
    @State private var logHapticTrigger = 0
    @State private var isShowingLogEarlier = false
    @State private var boundaryScheduleVersion = 0

    private var gridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let snapshot {
                    headerCard(snapshot: snapshot)
                }

                if let banner = undoBanner {
                    undoBannerView(banner)
                        .transition(.opacity)
                }

                presetsGrid

                actionsSection

                if let snapshot {
                    todayDrinksSection(snapshot: snapshot)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .sensoryFeedback(.success, trigger: logHapticTrigger)
        .sheet(isPresented: $isShowingLogEarlier) {
            LogEarlierSheetView(
                presets: presets,
                locale: locale
            ) { preset, offset in
                logPresetEarlier(preset, offset: offset)
            }
        }
        .task {
            reloadState()
        }
        .task(id: undoBanner?.drinkId) {
            guard undoBanner != nil else {
                return
            }
            do {
                try await Task.sleep(for: .seconds(5))
                withAnimation {
                    undoBanner = nil
                }
            } catch {
                // Cancelled when a newer drink is logged or undone.
            }
        }
        .task(id: boundaryScheduleVersion) {
            while !Task.isCancelled {
                let boundaryHour = snapshot?.dayBoundaryHour ?? LogicalDay.defaultBoundaryHour
                let delaySeconds = DayBoundaryScheduler.secondsUntilNextBoundary(
                    from: now(),
                    boundaryHour: boundaryHour,
                    timeZone: timeZone()
                )
                do {
                    try await Task.sleep(for: .seconds(delaySeconds))
                    reloadState()
                } catch {
                    break
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                reloadState()
                boundaryScheduleVersion += 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            reloadState()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("NSPersistentStoreRemoteChangeNotification")
            )
        ) { _ in
            reloadState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            reloadState()
            boundaryScheduleVersion += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
            reloadState()
            boundaryScheduleVersion += 1
        }
    }

    private func headerCard(snapshot: WatchLoggerSnapshot) -> some View {
        Text(snapshot.headerText)
            .font(.headline.bold())
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.teal.opacity(0.2))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(snapshot.headerAccessibilityLabel))
    }

    private func undoBannerView(_ banner: UndoBannerState) -> some View {
        HStack(spacing: 6) {
            Text(banner.loggedMessage)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button("undo.action") {
                undoDrink(withId: banner.drinkId)
            }
            .buttonStyle(.plain)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.teal)
            .accessibilityLabel(Text("undo.accessibility"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.teal.opacity(0.18))
        )
    }

    private var presetsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(presets, id: \.id) { preset in
                Button {
                    logPreset(preset)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: PresetPresentation.symbolName(for: preset))
                            .font(.title3)
                            .foregroundStyle(Color.teal)

                        Text(PresetPresentation.formattedHU(preset.hu, locale: locale))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(PresetPresentation.localizedName(for: preset, locale: locale))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text(PresetPresentation.accessibilityLabel(for: preset, locale: locale))
                )
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 6) {
            Button {
                if let latestId = snapshot?.mostRecentTodayDrinkId {
                    undoDrink(withId: latestId)
                }
            } label: {
                Label("watch.action.undoLast", systemImage: "arrow.uturn.backward")
                    .font(.footnote.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .disabled(snapshot?.mostRecentTodayDrinkId == nil)
            .accessibilityLabel(Text("undo.accessibility"))

            Button {
                isShowingLogEarlier = true
            } label: {
                Label("watch.action.logEarlier", systemImage: "clock.arrow.circlepath")
                    .font(.footnote.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel(Text("watch.action.logEarlier.accessibility"))
        }
    }

    private func todayDrinksSection(snapshot: WatchLoggerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("today.section.drinks")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if snapshot.todayDrinks.isEmpty {
                Text("today.drinks.empty")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 4) {
                    ForEach(snapshot.todayDrinks) { row in
                        HStack(spacing: 6) {
                            Text(row.timeText)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)

                            Text(row.name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Text(row.huText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func reloadState() {
        do {
            try logService.seedDefaultPresetsIfNeeded()
            presets = try logService.presets()
            snapshot = try WatchLoggerSnapshot.load(from: logService, locale: locale)
        } catch {
            Self.logger.error(
                "Failed to load watch logger state: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func logPreset(_ preset: Preset) {
        do {
            let drink = try logService.log(preset: preset, source: .watch)
            recordLoggedDrink(drink, preset: preset)
        } catch {
            Self.logger.error("Failed to log watch drink: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func logPresetEarlier(_ preset: Preset, offset: WatchEarlierOffset) {
        do {
            let targetDate = offset.targetTimestamp(from: now())
            let drink = try logService.log(preset: preset, at: targetDate, source: .watch)
            isShowingLogEarlier = false
            recordLoggedDrink(drink, preset: preset)
        } catch {
            Self.logger.error(
                "Failed to log earlier watch drink: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func recordLoggedDrink(_ drink: Drink, preset: Preset) {
        WidgetCenter.shared.reloadAllTimelines()
        logHapticTrigger += 1
        let localizedDrinkName = PresetPresentation.localizedName(for: preset, locale: locale)
        let format = AppLocalization.string("undo.banner.logged", locale: locale)
        let message = String(format: format, locale: locale, localizedDrinkName)
        withAnimation {
            undoBanner = UndoBannerState(drinkId: drink.id, loggedMessage: message)
        }
        reloadState()
    }

    private func undoDrink(withId drinkId: UUID) {
        do {
            let activeDrinks = try logService.drinks(includeDeleted: false)
            guard let targetDrink = activeDrinks.first(where: { $0.id == drinkId }) else {
                return
            }
            try logService.undo(targetDrink)
            WidgetCenter.shared.reloadAllTimelines()
            if undoBanner?.drinkId == drinkId {
                withAnimation {
                    undoBanner = nil
                }
            }
            reloadState()
        } catch {
            Self.logger.error("Failed to undo watch drink: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private struct LogEarlierSheetView: View {
    let presets: [Preset]
    let locale: Locale
    let onSelect: (Preset, WatchEarlierOffset) -> Void

    @State private var selectedPreset: Preset?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let preset = selectedPreset {
                    Button {
                        selectedPreset = nil
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: PresetPresentation.symbolName(for: preset))
                                .foregroundStyle(Color.teal)
                            Text(PresetPresentation.localizedName(for: preset, locale: locale))
                                .font(.footnote.weight(.semibold))
                            Spacer()
                            Text(PresetPresentation.formattedHU(preset.hu, locale: locale))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel(Text("watch.logEarlier.changePreset.accessibility"))

                    Text("watch.logEarlier.chooseTime")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(WatchEarlierOffset.allCases) { offset in
                        Button {
                            onSelect(preset, offset)
                        } label: {
                            Text(offset.localizedTitle(locale: locale))
                                .font(.footnote.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityLabel(
                            Text(
                                offset.accessibilityLabel(
                                    presetKey: preset.key,
                                    fallbackName: preset.name,
                                    locale: locale
                                )
                            )
                        )
                    }
                } else {
                    Text("watch.logEarlier.choosePreset")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(presets, id: \.id) { preset in
                        Button {
                            selectedPreset = preset
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: PresetPresentation.symbolName(for: preset))
                                    .foregroundStyle(Color.teal)
                                Text(PresetPresentation.localizedName(for: preset, locale: locale))
                                    .font(.footnote.weight(.medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(PresetPresentation.formattedHU(preset.hu, locale: locale))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel(
                            Text(PresetPresentation.accessibilityLabel(for: preset, locale: locale))
                        )
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }
}
