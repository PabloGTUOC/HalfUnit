import AppIntents
import HalfUnitCore
import SwiftUI
import WidgetKit

#if TESTING
    @testable import HalfUnit
#endif

// MARK: - Color Helpers

private func streakCardBackgroundColor(for renderingMode: WidgetRenderingMode) -> Color {
    renderingMode == .accented ? Color.primary.opacity(0.12) : BrandColors.streakCardBackground
}

private func streakCardTextColor(for renderingMode: WidgetRenderingMode) -> Color {
    renderingMode == .accented ? Color.primary : BrandColors.streakCardText
}

private func tileBackgroundColor(for renderingMode: WidgetRenderingMode) -> Color {
    renderingMode == .accented ? Color.primary.opacity(0.08) : BrandColors.cardBackground
}

private func widgetAccentColor(for renderingMode: WidgetRenderingMode) -> Color {
    renderingMode == .accented ? Color.primary : BrandColors.accent
}

// MARK: - Small Home Widget View

struct SmallHomeWidgetView: View {
    let snapshot: WidgetEntrySnapshot
    var renderingMode: WidgetRenderingMode = .fullColor

    private var textColor: Color {
        streakCardTextColor(for: renderingMode)
    }

    private var cardBackground: Color {
        streakCardBackgroundColor(for: renderingMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if snapshot.isDrinkingToday {
                Text(snapshot.streakHeadline)
                    .font(.headline.bold())
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(snapshot.todayTotalHUText)
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(textColor)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let previousStreakText = snapshot.previousStreakText {
                    Text(previousStreakText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(textColor.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                Text("\(snapshot.currentStreakDays)")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(textColor)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(snapshot.streakHeadline)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(textColor.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(snapshot.streakAccessibilityLabel))
    }
}

// MARK: - Medium Home Widget View

struct MediumHomeWidgetView: View {
    let snapshot: WidgetEntrySnapshot
    var renderingMode: WidgetRenderingMode = .fullColor

    private var textColor: Color {
        streakCardTextColor(for: renderingMode)
    }

    private var cardBackground: Color {
        streakCardBackgroundColor(for: renderingMode)
    }

    private var tileBackground: Color {
        tileBackgroundColor(for: renderingMode)
    }

    private var accent: Color {
        widgetAccentColor(for: renderingMode)
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = (proxy.size.width - 8) * 0.40
            HStack(spacing: 8) {
                streakCard
                    .frame(width: cardWidth, height: proxy.size.height)

                presetsGrid
                    .frame(maxWidth: .infinity, maxHeight: proxy.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            if snapshot.isDrinkingToday {
                Text(snapshot.streakHeadline)
                    .font(.subheadline.bold())
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(snapshot.todayTotalHUText)
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(textColor)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let previousStreakText = snapshot.previousStreakText {
                    Text(previousStreakText)
                        .font(.caption2)
                        .foregroundStyle(textColor.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            } else {
                Text("\(snapshot.currentStreakDays)")
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(textColor)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(snapshot.streakHeadline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(textColor.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(snapshot.streakAccessibilityLabel))
    }

    private var presetsGrid: some View {
        let buttons = Array(snapshot.presetButtons.prefix(6))
        let topRow = Array(buttons.prefix(3))
        let bottomRow = Array(buttons.dropFirst(3).prefix(3))

        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(topRow) { button in
                    compactPresetTile(for: button)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 6) {
                ForEach(bottomRow) { button in
                    compactPresetTile(for: button)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func compactPresetTile(for button: WidgetPresetButtonModel) -> some View {
        Button(intent: WidgetLogDrinkIntent(preset: button.entity)) {
            VStack(spacing: 2) {
                PresetPresentation.image(for: button.symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                    .widgetAccentable()
                    .frame(width: 22, height: 22, alignment: .center)

                Text(button.huText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tileBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(button.accessibilityLabel))
    }
}

// MARK: - Large Home Widget View

struct LargeHomeWidgetView: View {
    @Environment(\.locale) private var environmentLocale

    let snapshot: WidgetEntrySnapshot
    var renderingMode: WidgetRenderingMode = .fullColor

    private var effectiveLocale: Locale {
        environmentLocale
    }

    private var textColor: Color {
        streakCardTextColor(for: renderingMode)
    }

    private var cardBackground: Color {
        streakCardBackgroundColor(for: renderingMode)
    }

    private var tileBackground: Color {
        tileBackgroundColor(for: renderingMode)
    }

    private var accent: Color {
        widgetAccentColor(for: renderingMode)
    }

    var body: some View {
        VStack(spacing: 8) {
            streakCardTop

            presetsGrid

            if snapshot.todayTotalHU > Decimal(0) {
                todayTotalLine
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var streakCardTop: some View {
        VStack(alignment: .leading, spacing: 3) {
            if snapshot.isDrinkingToday {
                HStack(alignment: .firstTextBaseline) {
                    Text(snapshot.streakHeadline)
                        .font(.headline.bold())
                        .foregroundStyle(textColor)

                    Spacer(minLength: 4)

                    Text(snapshot.todayTotalHUText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(textColor)
                        .widgetAccentable()
                }

                if let previousStreakText = snapshot.previousStreakText {
                    Text(previousStreakText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(textColor.opacity(0.85))
                        .lineLimit(1)
                }

                Text(snapshot.lastDrinkSubtitle)
                    .font(.caption2)
                    .foregroundStyle(textColor.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(snapshot.currentStreakDays)")
                        .font(.system(.title, design: .rounded).bold())
                        .foregroundStyle(textColor)
                        .widgetAccentable()

                    Text(snapshot.streakHeadline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Text(snapshot.lastDrinkSubtitle)
                    .font(.caption2)
                    .foregroundStyle(textColor.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(snapshot.streakAccessibilityLabel))
    }

    private var presetsGrid: some View {
        let buttons = Array(snapshot.presetButtons.prefix(6))
        let row1 = Array(buttons.prefix(2))
        let row2 = Array(buttons.dropFirst(2).prefix(2))
        let row3 = Array(buttons.dropFirst(4).prefix(2))

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(row1) { button in
                    watchStylePresetTile(for: button)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                ForEach(row2) { button in
                    watchStylePresetTile(for: button)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                ForEach(row3) { button in
                    watchStylePresetTile(for: button)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func watchStylePresetTile(for button: WidgetPresetButtonModel) -> some View {
        Button(intent: WidgetLogDrinkIntent(preset: button.entity)) {
            VStack(spacing: 2) {
                PresetPresentation.image(for: button.symbolName)
                    .font(.title3)
                    .foregroundStyle(accent)
                    .widgetAccentable()
                    .frame(width: 28, height: 28, alignment: .center)

                Text(button.huText)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(button.localizedName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tileBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(button.accessibilityLabel))
    }

    private var todayTotalLine: some View {
        let format = AppLocalization.string("watch.header.todayHU", locale: effectiveLocale)
        let text = String(format: format, locale: effectiveLocale, snapshot.todayTotalHUText)
        return Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(accent)
            .widgetAccentable()
            .frame(maxWidth: .infinity, alignment: .center)
            .lineLimit(1)
    }
}
