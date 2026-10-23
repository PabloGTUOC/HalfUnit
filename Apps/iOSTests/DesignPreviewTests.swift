import Foundation
import HalfUnitCore
import SwiftUI
import Testing
import UIKit

@testable import HalfUnit

@Suite("Design Preview Generation Tests")
struct DesignPreviewTests {
    private static let symbols: [(key: String, label: String)] = [
        ("halfunit.beer.bottle", "Beer Bottle\n0.33 l"),
        ("halfunit.beer.mug", "Beer Mug\n0.5 l"),
        ("halfunit.wine.small", "Wine Small\n0.1 l"),
        ("halfunit.wine.glass", "Wine Glass\n0.2 l"),
        ("halfunit.shot", "Shot\n2-4 cl"),
        ("halfunit.longdrink", "Long Drink\nHighball"),
    ]

    private static let baselineComparisonSymbols: [(key: String, label: String, isSystem: Bool)] = [
        ("halfunit.beer.bottle", "Bottle", false),
        ("halfunit.beer.mug", "Beer Mug", false),
        ("halfunit.wine.small", "Small Wine", false),
        ("halfunit.wine.glass", "Wine Glass", false),
        ("halfunit.shot", "Shot", false),
        ("halfunit.longdrink", "Highball", false),
        ("wineglass", "SF wineglass", true),
        ("mug", "SF mug", true),
    ]

    private static let colorTokens: [(name: String, color: Color, lightHex: String, darkHex: String)] = [
        ("AccentColor", BrandColors.accent, BrandColors.accentHex.light, BrandColors.accentHex.dark),
        ("BrandFill", BrandColors.brandFill, BrandColors.brandFillHex.light, BrandColors.brandFillHex.dark),
        ("BrandInk", BrandColors.brandInk, BrandColors.brandInkHex.light, BrandColors.brandInkHex.dark),
        (
            "StreakCardBackground", BrandColors.streakCardBackground,
            BrandColors.streakCardBackgroundHex.light, BrandColors.streakCardBackgroundHex.dark
        ),
        (
            "StreakCardText", BrandColors.streakCardText,
            BrandColors.streakCardTextHex.light, BrandColors.streakCardTextHex.dark
        ),
        (
            "HighlightBackground", BrandColors.highlightBackground,
            BrandColors.highlightBackgroundHex.light, BrandColors.highlightBackgroundHex.dark
        ),
        (
            "HighlightText", BrandColors.highlightText,
            BrandColors.highlightTextHex.light, BrandColors.highlightTextHex.dark
        ),
        ("ChartLow", BrandColors.chartLow, BrandColors.chartLowHex.light, BrandColors.chartLowHex.dark),
        ("ChartHigh", BrandColors.chartHigh, BrandColors.chartHighHex.light, BrandColors.chartHighHex.dark),
        (
            "PresetTileBackground", BrandColors.presetTileBackground,
            BrandColors.presetTileBackgroundHex.light, BrandColors.presetTileBackgroundHex.dark
        ),
    ]

    @Test("Render design preview sheet to $(SRCROOT)/.build/design-preview.png")
    @MainActor
    func renderDesignPreviewSheet() throws {
        let previewContent =
            makePreviewContent()
            .frame(width: 860)
            .background(Color(uiColor: .systemGroupedBackground))

        let renderer = ImageRenderer(content: previewContent)
        renderer.scale = 2.0

        guard let uiImage = renderer.uiImage else {
            Issue.record("Failed to render DesignPreview to UIImage")
            return
        }

        guard let pngData = uiImage.pngData() else {
            Issue.record("Failed to generate PNG data from rendered image")
            return
        }

        // Locate repository root via compile-time #filePath
        let currentFile = URL(fileURLWithPath: #filePath)
        let repoRoot =
            currentFile
            .deletingLastPathComponent()  // Apps/iOSTests
            .deletingLastPathComponent()  // Apps
            .deletingLastPathComponent()  // repo root

        let buildDir = repoRoot.appendingPathComponent(".build", isDirectory: true)
        let outputURL = buildDir.appendingPathComponent("design-preview.png")

        do {
            try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
            try pngData.write(to: outputURL, options: .atomic)
            #expect(FileManager.default.fileExists(atPath: outputURL.path))
            print("Successfully rendered design preview sheet to: \(outputURL.path)")
        } catch {
            print("Could not write outside simulator container (\(error)). Writing to tmp as fallback.")
            let fallbackURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                "design-preview.png")
            try pngData.write(to: fallbackURL, options: .atomic)
            #expect(FileManager.default.fileExists(atPath: fallbackURL.path))
        }
    }

    @MainActor
    private func makePreviewContent() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Half Unit — Design Preview")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(BrandColors.brandInk)

                Text(
                    "Sanzo Wada #263 Palette · Burnt Sienna Main Accent · Six Custom SF Symbols (Filled Paths)"
                )
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            // Baseline Alignment Row (Inline after "Aa" at body size + Apple comparison)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Baseline Alignment & Reference Comparison (Body Size)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: BrandColors.slateHex))
                    Text(
                        "Each custom symbol standing on baseline inline after 'Aa' at body size, with Apple system symbols at the end for visual comparison"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    ForEach(Self.baselineComparisonSymbols, id: \.key) { item in
                        VStack(spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("Aa")
                                    .font(.body)
                                    .foregroundStyle(Color(hex: BrandColors.slateHex))
                                PresetPresentation.image(for: item.key)
                                    .font(.body)
                                    .foregroundStyle(
                                        item.isSystem
                                            ? Color.secondary
                                            : Color(hex: BrandColors.burntSiennaHex)
                                    )
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            Text(item.label)
                                .font(.system(size: 9, weight: item.isSystem ? .bold : .medium))
                                .foregroundStyle(item.isSystem ? Color(hex: BrandColors.slateHex) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.08), lineWidth: 1))

            // Light Appearance Card
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Light Appearance")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: BrandColors.slateHex))
                    Spacer()
                    Text("Accent: Burnt Sienna #AE5224")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: BrandColors.burntSiennaHex))
                }

                symbolSizesBlock(
                    tintColor: Color(hex: BrandColors.burntSiennaHex),
                    labelColor: Color(hex: BrandColors.slateHex)
                )
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.08), lineWidth: 1))
            .environment(\.colorScheme, .light)

            // Dark Appearance Card
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Dark Appearance")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: BrandColors.turquoiseGreenHex))
                    Spacer()
                    Text("Accent: Pinkish Cinnamon #EEB480")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: BrandColors.pinkishCinnamonHex))
                }

                symbolSizesBlock(
                    tintColor: Color(hex: BrandColors.pinkishCinnamonHex),
                    labelColor: Color(hex: BrandColors.turquoiseGreenHex)
                )
            }
            .padding(20)
            .background(Color(hex: BrandColors.darkBackgroundHex))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(
                    Color.white.opacity(0.12), lineWidth: 1)
            )
            .environment(\.colorScheme, .dark)

            // Color Swatches
            VStack(alignment: .leading, spacing: 16) {
                Text("Color Tokens (Sanzo Wada #263)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(BrandColors.brandInk)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12
                ) {
                    ForEach(Self.colorTokens, id: \.name) { token in
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(token.color)
                                .frame(height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                )

                            Text(token.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)

                            Text("L: \(token.lightHex)  D: \(token.darkHex)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.08), lineWidth: 1))
        }
        .padding(24)
    }

    @MainActor
    private func symbolSizesBlock(tintColor: Color, labelColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Large Title
            VStack(alignment: .leading, spacing: 4) {
                Text("largeTitle")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                HStack(spacing: 20) {
                    ForEach(Self.symbols, id: \.key) { item in
                        VStack(spacing: 6) {
                            PresetPresentation.image(for: item.key)
                                .font(.largeTitle)
                                .foregroundStyle(tintColor)
                                .frame(width: 50, height: 50)

                            Text(item.label)
                                .font(.system(size: 9, weight: .medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(labelColor)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Divider()

            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("title")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                HStack(spacing: 20) {
                    ForEach(Self.symbols, id: \.key) { item in
                        PresetPresentation.image(for: item.key)
                            .font(.title2)
                            .foregroundStyle(tintColor)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Divider()

            // Body
            VStack(alignment: .leading, spacing: 4) {
                Text("body")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                HStack(spacing: 20) {
                    ForEach(Self.symbols, id: \.key) { item in
                        PresetPresentation.image(for: item.key)
                            .font(.body)
                            .foregroundStyle(tintColor)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

extension Color {
    fileprivate init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if let rgb = UInt64(cleaned, radix: 16), cleaned.count == 6 {
            let r = Double((rgb >> 16) & 0xFF) / 255.0
            let g = Double((rgb >> 8) & 0xFF) / 255.0
            let b = Double(rgb & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b)
        } else {
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
        }
    }
}
