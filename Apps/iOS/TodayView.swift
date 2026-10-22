import Foundation
import HalfUnitCore
import OSLog
import SwiftUI

struct TodayView: View {
    private static let logger = Logger(subsystem: "es.opinasdeque.halfunit", category: "TodayView")

    private struct UndoBannerState: Equatable {
        let drink: Drink
        let loggedMessage: String

        static func == (lhs: UndoBannerState, rhs: UndoBannerState) -> Bool {
            lhs.drink.id == rhs.drink.id && lhs.loggedMessage == rhs.loggedMessage
        }
    }

    let logService: LogService

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    @State private var presets: [Preset] = []
    @State private var screenSnapshot: TodayScreenSnapshot?
    @State private var undoBanner: UndoBannerState?
    @State private var logHapticTrigger = 0
    @State private var isShowingSettings = false

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
                    }
                    .accessibilityLabel(Text("settings.open.accessibility"))
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsPlaceholderView()
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
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let previousStreakText = model.previousStreakText {
                Text(previousStreakText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(model.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.teal.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.teal.opacity(0.28), lineWidth: 1)
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
                            Image(systemName: PresetPresentation.symbolName(for: preset))
                                .font(.title2)
                                .foregroundStyle(Color.teal)
                                .frame(width: 32, alignment: .center)

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
                                .fill(Color(.secondarySystemGroupedBackground))
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
                                .fill(Color(.secondarySystemGroupedBackground))
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
                .foregroundStyle(.primary)

            Spacer()

            Button("undo.action") {
                undoLastDrink(banner.drink)
            }
            .font(.subheadline.weight(.semibold))
            .tint(.teal)
            .accessibilityLabel(Text("undo.accessibility"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        )
    }

    private func reloadState() {
        do {
            try logService.seedDefaultPresetsIfNeeded()
            presets = try logService.presets()
            screenSnapshot = try TodayScreenSnapshot.load(from: logService, locale: locale)
        } catch {
            Self.logger.error("Failed to load Today state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func logPreset(_ preset: Preset) {
        do {
            let drink = try logService.log(preset: preset, source: .phone)
            logHapticTrigger += 1
            let localizedDrinkName = PresetPresentation.localizedName(for: preset, locale: locale)
            let format = AppLocalization.string("undo.banner.logged", locale: locale)
            let message = String(format: format, locale: locale, localizedDrinkName)
            withAnimation {
                undoBanner = UndoBannerState(drink: drink, loggedMessage: message)
            }
            reloadState()
        } catch {
            Self.logger.error("Failed to log drink: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func undoLastDrink(_ drink: Drink) {
        do {
            try logService.undo(drink)
            withAnimation {
                undoBanner = nil
            }
            reloadState()
        } catch {
            Self.logger.error("Failed to undo drink: \(error.localizedDescription, privacy: .public)")
        }
    }
}
