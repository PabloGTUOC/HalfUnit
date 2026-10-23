import AppIntents
import HalfUnitCore
import SwiftUI
import WidgetKit

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

private struct SmallHomeWidgetView: View {
    let snapshot: WidgetEntrySnapshot
    let renderingMode: WidgetRenderingMode

    private var accentColor: Color {
        renderingMode == .accented ? .primary : BrandColors.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .widgetAccentable()

                Text("widget.ios.header")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            if snapshot.isDrinkingToday {
                Text(snapshot.streakHeadline)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(snapshot.todayTotalHUText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .widgetAccentable()
                    .lineLimit(1)

                if let previousStreakText = snapshot.previousStreakText {
                    Text(previousStreakText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("\(snapshot.currentStreakDays)")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(accentColor)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(snapshot.streakHeadline)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(snapshot.streakAccessibilityLabel))
    }
}

private struct MediumHomeWidgetView: View {
    let snapshot: WidgetEntrySnapshot
    let renderingMode: WidgetRenderingMode

    private var accentColor: Color {
        renderingMode == .accented ? .primary : BrandColors.accent
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    if snapshot.isDrinkingToday {
                        Text(snapshot.streakHeadline)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                            .widgetAccentable()
                            .lineLimit(1)

                        Text(snapshot.todayTotalHUText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accentColor)
                            .widgetAccentable()
                            .lineLimit(1)
                    } else {
                        Text(snapshot.streakHeadline)
                            .font(.headline.bold())
                            .foregroundStyle(.primary)
                            .widgetAccentable()
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let previousStreakText = snapshot.previousStreakText {
                        Text(previousStreakText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(snapshot.streakAccessibilityLabel))

                Spacer(minLength: 4)

                Text(snapshot.lastDrinkSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                ForEach(snapshot.presetButtons) { button in
                    Button(intent: WidgetLogDrinkIntent(preset: button.entity)) {
                        HStack(spacing: 6) {
                            PresetPresentation.image(for: button.symbolName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(accentColor)
                                .widgetAccentable()
                                .frame(width: 22, height: 22, alignment: .center)

                            Text(button.localizedName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Spacer(minLength: 2)

                            Text(button.huText)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(BrandColors.cardBackground)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(button.accessibilityLabel))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
