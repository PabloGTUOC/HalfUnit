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

        public static let colorTokens: [(name: String, color: Color, hex: BrandColors.AppearanceHex)] = [
            ("AccentColor", BrandColors.accent, BrandColors.accentHex),
            ("BrandFill", BrandColors.brandFill, BrandColors.brandFillHex),
            ("BrandInk", BrandColors.brandInk, BrandColors.brandInkHex),
            ("StreakCardBackground", BrandColors.streakCardBackground, BrandColors.streakCardBackgroundHex),
            ("StreakCardText", BrandColors.streakCardText, BrandColors.streakCardTextHex),
            ("HighlightBackground", BrandColors.highlightBackground, BrandColors.highlightBackgroundHex),
            ("HighlightText", BrandColors.highlightText, BrandColors.highlightTextHex),
            ("ChartLow", BrandColors.chartLow, BrandColors.chartLowHex),
            ("ChartHigh", BrandColors.chartHigh, BrandColors.chartHighHex),
            ("PresetTileBackground", BrandColors.presetTileBackground, BrandColors.presetTileBackgroundHex),
        ]

        public init() {}

        public var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection

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
