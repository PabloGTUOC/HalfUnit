import SwiftUI

#if DEBUG
    public struct DesignPreviewView: View {
        public static let symbols: [(key: String, name: String)] = [
            ("halfunit.beer.bottle", "Beer Bottle (0.33l)"),
            ("halfunit.beer.mug", "Beer Mug (0.5l)"),
            ("halfunit.wine.small", "Wine Small (0.1l)"),
            ("halfunit.wine.glass", "Wine Glass (0.2l)"),
            ("halfunit.shot", "Shot Glass (2-4cl)"),
            ("halfunit.longdrink", "Long Drink (Highball)"),
        ]

        public static let baselineComparisonSymbols: [(key: String, name: String, isSystem: Bool)] = [
            ("halfunit.beer.bottle", "Bottle", false),
            ("halfunit.beer.mug", "Mug", false),
            ("halfunit.wine.small", "Wine (S)", false),
            ("halfunit.wine.glass", "Wine (L)", false),
            ("halfunit.shot", "Shot", false),
            ("halfunit.longdrink", "Highball", false),
            ("wineglass", "SF wineglass", true),
            ("mug", "SF mug", true),
        ]

        public static let colorTokens: [(name: String, color: Color, hex: BrandColors.AppearanceHex)] = [
            ("AccentColor", BrandColors.accent, BrandColors.accentHex),
            ("BrandFill", BrandColors.brandFill, BrandColors.brandFillHex),
            ("BrandInk", BrandColors.brandInk, BrandColors.brandInkHex),
            ("AppBackground", BrandColors.appBackground, BrandColors.appBackgroundHex),
            ("CardBackground", BrandColors.cardBackground, BrandColors.cardBackgroundHex),
            ("StreakCardBackground", BrandColors.streakCardBackground, BrandColors.streakCardBackgroundHex),
            ("StreakCardText", BrandColors.streakCardText, BrandColors.streakCardTextHex),
            ("HighlightBackground", BrandColors.highlightBackground, BrandColors.highlightBackgroundHex),
            ("HighlightText", BrandColors.highlightText, BrandColors.highlightTextHex),
            ("ChartLow", BrandColors.chartLow, BrandColors.chartLowHex),
            ("ChartHigh", BrandColors.chartHigh, BrandColors.chartHighHex),
        ]

        public init() {}

        public var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection

                    // Baseline Alignment Row with "Aa" at body size + Apple comparison
                    baselineAlignmentSection
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Mock Preset Tile on AppBackground (Light & Dark)
                    mockPresetTileSection
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Light Appearance
                    appearanceSection(isDark: false)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .environment(\.colorScheme, .light)

                    // Dark Appearance
                    appearanceSection(isDark: true)
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .environment(\.colorScheme, .dark)

                    // Color Tokens Swatches
                    colorTokensSection
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("Design Preview")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .systemGroupedBackground))
        }

        private var headerSection: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sanzo Wada #263 & Custom Symbols")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(BrandColors.brandInk)
                Text("Slate #34454C · Burnt Sienna #AE5224 · Pinkish Cinnamon #EEB480 · Turquoise Green #B5DECC")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        private var baselineAlignmentSection: some View {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Baseline Alignment & Apple Reference Comparison")
                        .font(.headline)
                        .foregroundStyle(BrandColors.brandInk)
                    Text("Inline after 'Aa' at body size, comparing with Apple's wineglass and mug")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    ForEach(Self.baselineComparisonSymbols, id: \.key) { item in
                        VStack(spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("Aa")
                                    .font(.body)
                                    .foregroundStyle(BrandColors.brandInk)
                                PresetPresentation.image(for: item.key)
                                    .font(.body)
                                    .foregroundStyle(item.isSystem ? Color.secondary : BrandColors.accent)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            Text(item.name)
                                .font(.system(size: 8, weight: item.isSystem ? .bold : .regular))
                                .foregroundStyle(item.isSystem ? BrandColors.brandInk : Color.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }

        private var mockPresetTileSection: some View {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preset Tile Mock on Faded Burnt Sienna Backgrounds")
                        .font(.headline)
                        .foregroundStyle(BrandColors.brandInk)
                    Text("Preset tile (CardBackground, icon @ 36pt frame + 'Beer · 1 HU') on AppBackground")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Light (#F9F1ED)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        mockPresetTile(isDark: false)
                            .padding(12)
                            .background(BrandColors.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .environment(\.colorScheme, .light)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dark (#221814)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        mockPresetTile(isDark: true)
                            .padding(12)
                            .background(BrandColors.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .environment(\.colorScheme, .dark)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }

        private func mockPresetTile(isDark: Bool) -> some View {
            HStack(spacing: 12) {
                PresetPresentation.image(for: "halfunit.beer.mug")
                    .font(.title2)
                    .foregroundStyle(BrandColors.accent)
                    .frame(width: 36, height: 36, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Beer")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isDark ? Color.white : BrandColors.brandInk)

                    Text("1 HU")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BrandColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }

        private func appearanceSection(isDark: Bool) -> some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(isDark ? "Dark Appearance" : "Light Appearance")
                        .font(.headline)
                        .foregroundStyle(isDark ? Color.white : Color.black)
                    Spacer()
                    Text(isDark ? "Dark Mode" : "Light Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Symbols at Large Title
                symbolRow(size: .largeTitle, label: "Large Title", isDark: isDark)

                // Symbols at Title
                symbolRow(size: .title2, label: "Title", isDark: isDark)

                // Symbols at Body
                symbolRow(size: .body, label: "Body", isDark: isDark)
            }
        }

        private func symbolRow(size: Font, label: String, isDark: Bool) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    ForEach(Self.symbols, id: \.key) { symbol in
                        VStack(spacing: 4) {
                            PresetPresentation.image(for: symbol.key)
                                .font(size)
                                .foregroundStyle(BrandColors.accent)
                                .frame(width: 44, height: 44)
                        }
                    }
                }
            }
        }

        private var colorTokensSection: some View {
            VStack(alignment: .leading, spacing: 14) {
                Text("Color Tokens & Contrast")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(Self.colorTokens, id: \.name) { token in
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(token.color)
                                .frame(height: 48)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )

                            Text(token.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)

                            Text("L: \(token.hex.light) / D: \(token.hex.dark)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
#endif
