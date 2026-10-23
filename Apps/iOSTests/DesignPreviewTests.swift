import Foundation
import HalfUnitCore
import SwiftUI
import Testing
import UIKit

@_exported @testable import HalfUnit

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
            "AppBackground", BrandColors.appBackground,
            BrandColors.appBackgroundHex.light, BrandColors.appBackgroundHex.dark
        ),
        (
            "CardBackground", BrandColors.cardBackground,
            BrandColors.cardBackgroundHex.light, BrandColors.cardBackgroundHex.dark
        ),
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
    ]

    @Test("Measure symbol bounding boxes at 36 pt")
    @MainActor
    func measureSymbolBoundingBoxes() throws {
        let keys = [
            "wineglass",
            "mug",
            "halfunit.beer.bottle",
            "halfunit.beer.mug",
            "halfunit.wine.small",
            "halfunit.wine.glass",
            "halfunit.shot",
            "halfunit.longdrink",
        ]

        for key in keys {
            let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .regular)
            let image: UIImage?
            if key.starts(with: "halfunit.") {
                image = UIImage(named: key, in: Bundle.main, with: config)
            } else {
                image = UIImage(systemName: key, withConfiguration: config)
            }

            guard let img = image else {
                print("Could not load image for \(key)")
                continue
            }

            let box = boundingBox(for: img)
            print("SYMBOL_MEASURE [\(key)]: image.size=\(img.size), nonTransparentBox=\(box)")

            switch key {
            case "halfunit.beer.bottle", "halfunit.longdrink":
                #expect(
                    box.height >= 30.0,
                    "Expected \(key) height >= 30 pt at 36 pt, got \(box.height)"
                )
            case "halfunit.wine.glass", "halfunit.beer.mug":
                #expect(
                    box.height >= 26.0,
                    "Expected \(key) height >= 26 pt at 36 pt, got \(box.height)"
                )
            case "halfunit.wine.small", "halfunit.shot":
                #expect(
                    box.height >= 24.0,
                    "Expected \(key) height >= 24 pt at 36 pt, got \(box.height)"
                )
            default:
                break
            }
        }
    }

    private func boundingBox(for image: UIImage) -> CGRect {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        guard let cgImage = renderedImage.cgImage else { return .zero }
        let width = cgImage.width
        let height = cgImage.height

        guard let data = cgImage.dataProvider?.data,
            let ptr = CFDataGetBytePtr(data)
        else { return .zero }

        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        var foundAny = false

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * cgImage.bytesPerRow) + (x * 4)
                let alpha = ptr[pixelIndex + 3]
                if alpha > 10 {
                    foundAny = true
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        if !foundAny { return .zero }
        let scale = renderedImage.scale
        return CGRect(
            x: CGFloat(minX) / scale,
            y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        )
    }

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
                                .foregroundStyle(
                                    item.isSystem ? Color(hex: BrandColors.slateHex) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.08), lineWidth: 1))

            // Mock Preset Tiles on AppBackground (Light & Dark)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preset Tile Mock on Faded Burnt Sienna Backgrounds")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(BrandColors.brandInk)
                    Text(
                        "Preset tile (CardBackground, icon @ 36pt frame + 'Beer · 1 HU') resting on AppBackground in light (#F9F1ED) and dark (#221814)"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 20) {
                    // Light mode mock
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Light Appearance (AppBackground #F9F1ED)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: BrandColors.slateHex))

                        mockPresetTile(isDark: false)
                            .padding(16)
                            .background(BrandColors.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(
                                    Color.black.opacity(0.06), lineWidth: 1)
                            )
                            .environment(\.colorScheme, .light)
                    }
                    .frame(maxWidth: .infinity)

                    // Dark mode mock
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dark Appearance (AppBackground #221814)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: BrandColors.turquoiseGreenHex))

                        mockPresetTile(isDark: true)
                            .padding(16)
                            .background(BrandColors.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(
                                    Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .environment(\.colorScheme, .dark)
                    }
                    .frame(maxWidth: .infinity)
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
    private func mockPresetTile(isDark: Bool) -> some View {
        HStack(spacing: 12) {
            PresetPresentation.image(for: "halfunit.beer.mug")
                .font(.title2)
                .foregroundStyle(BrandColors.accent)
                .frame(width: 36, height: 36, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text("Beer")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isDark ? Color.white : Color(hex: BrandColors.slateHex))

                Text("1 HU")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
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

    @Test("Render widget preview sheet to $(SRCROOT)/.build/widget-preview.png")
    @MainActor
    func renderWidgetPreviewSheet() throws {
        let previewContent =
            makeWidgetPreviewContent()
            .frame(width: 860)
            .background(Color(uiColor: .systemGroupedBackground))

        let renderer = ImageRenderer(content: previewContent)
        renderer.scale = 2.0

        guard let uiImage = renderer.uiImage else {
            Issue.record("Failed to render WidgetPreview to UIImage")
            return
        }

        guard let pngData = uiImage.pngData() else {
            Issue.record("Failed to generate PNG data from rendered widget image")
            return
        }

        let currentFile = URL(fileURLWithPath: #filePath)
        let repoRoot =
            currentFile
            .deletingLastPathComponent()  // Apps/iOSTests
            .deletingLastPathComponent()  // Apps
            .deletingLastPathComponent()  // repo root

        let buildDir = repoRoot.appendingPathComponent(".build", isDirectory: true)
        let outputURL = buildDir.appendingPathComponent("widget-preview.png")

        do {
            try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
            try pngData.write(to: outputURL, options: .atomic)
            #expect(FileManager.default.fileExists(atPath: outputURL.path))
            print("Successfully rendered widget preview sheet to: \(outputURL.path)")
        } catch {
            print("Could not write outside simulator container (\(error)). Writing to tmp as fallback.")
            let fallbackURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                "widget-preview.png")
            try pngData.write(to: fallbackURL, options: .atomic)
            #expect(FileManager.default.fileExists(atPath: fallbackURL.path))
        }
    }

    @MainActor
    private func makeWidgetPreviewContent() -> some View {
        let streakSnapshot = Self.streakSnapshot
        let drinkingTodaySnapshot = Self.drinkingTodaySnapshot

        return VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Half Unit — Home Screen Widgets")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(BrandColors.brandInk)

                Text(
                    "Native iOS Widgets · Sanzo Wada #263 Palette · Small (170×170), Medium (364×170), Large (364×382)"
                )
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            // Section 1: Streak State
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Streak State (24 Days Without Alcohol)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(BrandColors.brandInk)
                    Text(
                        "Small: streak card filling widget · Medium: 40% streak card + 3×2 grid · Large: top card with last drink + 2×3 grid"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                widgetGroup(title: "Light Appearance", snapshot: streakSnapshot, isDark: false)
                widgetGroup(title: "Dark Appearance", snapshot: streakSnapshot, isDark: true)
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.08), lineWidth: 1))

            // Section 2: Drinking Today State
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drinking Today State (Today: 1.5 HU · Previous: 4 Days)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(BrandColors.brandInk)
                    Text(
                        "Small: Today + 1.5 HU · Medium: Today + 1.5 HU + previous streak + 3×2 grid · Large: top card with last drink + 2×3 grid + today total"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                widgetGroup(title: "Light Appearance", snapshot: drinkingTodaySnapshot, isDark: false)
                widgetGroup(title: "Dark Appearance", snapshot: drinkingTodaySnapshot, isDark: true)
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.08), lineWidth: 1))
        }
        .padding(24)
    }

    @MainActor
    private func widgetGroup(
        title: String,
        snapshot: WidgetEntrySnapshot,
        isDark: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isDark ? Color.white.opacity(0.8) : Color(hex: BrandColors.slateHex))

            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 16) {
                    SmallHomeWidgetView(snapshot: snapshot, renderingMode: .fullColor)
                        .frame(width: 170, height: 170)
                        .background(BrandColors.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                    MediumHomeWidgetView(snapshot: snapshot, renderingMode: .fullColor)
                        .frame(width: 364, height: 170)
                        .background(BrandColors.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }

                LargeHomeWidgetView(snapshot: snapshot, renderingMode: .fullColor)
                    .frame(width: 364, height: 382)
                    .background(BrandColors.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(isDark ? Color(hex: BrandColors.darkBackgroundHex) : Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06), lineWidth: 1)
        )
        .environment(\.colorScheme, isDark ? .dark : .light)
    }

    private static var streakSnapshot: WidgetEntrySnapshot {
        WidgetEntrySnapshot.placeholder(locale: Locale(identifier: "en_US"))
    }

    private static var drinkingTodaySnapshot: WidgetEntrySnapshot {
        let sundayDay = LogicalDay(year: 2026, month: 9, day: 27)
        let lastDrink = DrinkSnapshot(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_759_003_200),
            logicalDay: sundayDay,
            presetKey: "beer",
            name: "beer",
            hu: Decimal(1),
            grams: Decimal(20)
        )
        let summary = StreakSummary(
            lastDrinkingDay: LogicalDay(year: 2026, month: 9, day: 28),
            lastDrink: lastDrink,
            isDrinkingToday: true,
            currentStreakDays: 0,
            previousStreakDays: 4,
            longestStreakEver: 14,
            longestStreakThisYear: 8
        )
        return WidgetEntrySnapshot(
            summary: summary,
            todayTotalHU: Decimal(sign: .plus, exponent: -1, significand: 15),
            todayTotalGrams: Decimal(30),
            displayUnit: .hu,
            presets: PresetEntity.fallbackDefaultEntities,
            locale: Locale(identifier: "en_US")
        )
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
