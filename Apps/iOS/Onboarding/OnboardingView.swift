import HalfUnitCore
import OSLog
import SwiftUI

struct OnboardingView: View {
    private static let logger = Logger(subsystem: "es.opinasdeque.halfunit", category: "Onboarding")

    let logService: LogService
    let healthSync: HealthSync
    let onDismiss: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var currentStep = 0
    @State private var presets: [Preset] = []
    @State private var isRequestingHealth = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentStep) {
                    unitExplanationScreen
                        .tag(0)

                    presetSelectionScreen
                        .tag(1)

                    healthPermissionScreen
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
            .background(BrandColors.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .task {
                reloadPresets()
            }
        }
    }

    // MARK: - Screen 1: What is a HU
    private var unitExplanationScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                Image(systemName: "drop.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(BrandColors.accent)
                    .accessibilityHidden(true)

                Text("onboarding.screen1.title")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 16) {
                    explanationRow(
                        symbol: "info.circle",
                        textKey: "onboarding.screen1.p1"
                    )
                    explanationRow(
                        symbol: "equal.circle",
                        textKey: "onboarding.screen1.p2"
                    )
                    explanationRow(
                        symbol: "chart.bar",
                        textKey: "onboarding.screen1.p3"
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BrandColors.cardBackground)
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("disclaimer.title")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("disclaimer.body")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)

                Spacer(minLength: 24)

                Button {
                    withAnimation {
                        currentStep = 1
                    }
                } label: {
                    Text("onboarding.action.continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandColors.brandFill)
            }
            .padding()
        }
    }

    private func explanationRow(symbol: String, textKey: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(BrandColors.accent)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            Text(textKey)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Screen 2: Choose or adjust presets
    private var presetSelectionScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 10)

                Text("onboarding.screen2.title")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text("onboarding.screen2.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(presets, id: \.id) { preset in
                        Button {
                            togglePreset(preset)
                        } label: {
                            HStack(spacing: 14) {
                                PresetPresentation.image(for: PresetPresentation.symbolName(for: preset))
                                    .font(.title2)
                                    .foregroundStyle(preset.isHidden ? Color.secondary : BrandColors.accent)
                                    .frame(width: 32, alignment: .center)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(PresetPresentation.localizedName(for: preset, locale: locale))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(preset.isHidden ? .secondary : .primary)

                                    Text(PresetPresentation.formattedHU(preset.hu, locale: locale))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: preset.isHidden ? "eye.slash" : "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(preset.isHidden ? Color.secondary : BrandColors.accent)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(BrandColors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        preset.isHidden ? Color.clear : BrandColors.accent.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(presetAccessibilityLabel(for: preset))
                    }
                }

                Text("onboarding.screen2.editLater")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Spacer(minLength: 20)

                Button {
                    withAnimation {
                        currentStep = 2
                    }
                } label: {
                    Text("onboarding.action.continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandColors.brandFill)
            }
            .padding()
        }
    }

    private func presetAccessibilityLabel(for preset: Preset) -> String {
        let name = PresetPresentation.localizedName(for: preset, locale: locale)
        let hu = PresetPresentation.formattedHU(preset.hu, locale: locale)
        let statusKey = preset.isHidden ? "onboarding.screen2.status.hidden" : "onboarding.screen2.status.visible"
        let status = AppLocalization.string(statusKey, locale: locale)
        let format = AppLocalization.string("onboarding.screen2.toggleAccessibility", locale: locale)
        return String(format: format, locale: locale, name, hu, status)
    }

    private func togglePreset(_ preset: Preset) {
        do {
            try logService.setPresetHidden(preset, !preset.isHidden)
            reloadPresets()
        } catch {
            Self.logger.error("Failed to toggle preset: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func reloadPresets() {
        do {
            try logService.seedDefaultPresetsIfNeeded()
            presets = try logService.presets(includeHidden: true)
        } catch {
            Self.logger.error("Failed to load presets: \(error.localizedDescription, privacy: .private)")
        }
    }

    // MARK: - Screen 3: Apple Health
    private var healthPermissionScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                Image(systemName: "heart.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(BrandColors.accent)
                    .accessibilityHidden(true)

                Text("onboarding.screen3.title")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                VStack(spacing: 16) {
                    Text("onboarding.screen3.reason")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("onboarding.screen3.explanation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BrandColors.cardBackground)
                )

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    Button {
                        allowAppleHealthAndFinish()
                    } label: {
                        if isRequestingHealth {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 50)
                        } else {
                            Text("onboarding.screen3.allowAction")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BrandColors.brandFill)
                    .disabled(isRequestingHealth)

                    Button {
                        completeOnboardingAndDismiss()
                    } label: {
                        Text("onboarding.screen3.notNowAction")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(isRequestingHealth)
                }
            }
            .padding()
        }
    }

    private func allowAppleHealthAndFinish() {
        isRequestingHealth = true
        Task { @MainActor in
            if !HealthPreferences.isSyncEnabled() {
                HealthPreferences.setSyncEnabled(true)
            }
            _ = await healthSync.requestAuthorization()
            await HalfUnitApp.reconcileHealth(healthSync: healthSync)
            completeOnboardingAndDismiss()
        }
    }

    private func completeOnboardingAndDismiss() {
        OnboardingPreferences.setCompleted(true)
        onDismiss()
    }
}
