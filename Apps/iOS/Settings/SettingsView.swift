import CoreData
import Foundation
import HalfUnitCore
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct SettingsView: View {
    private static let logger = Logger(subsystem: "es.opinasdeque.halfunit", category: "SettingsView")

    private enum PresetEditorSheetState: Identifiable {
        case add
        case edit(SettingsPresetItem)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let item):
                return item.id.uuidString
            }
        }
    }

    private struct ActiveFileExport {
        let document: ExportDataDocument
        let contentType: UTType
        let defaultFilename: String
    }

    let logService: LogService
    let healthSync: HealthSync

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    @State private var snapshot: SettingsScreenSnapshot?
    @State private var presetEditorSheet: PresetEditorSheetState?
    @State private var activeExport: ActiveFileExport?
    @State private var isShowingFileExporter = false
    @State private var isShowingRestoreConfirmation = false
    @State private var isShowingFileImporter = false
    @State private var statusBannerMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let snapshot {
                    presetsSection(snapshot: snapshot)
                    dayBoundarySection(snapshot: snapshot)
                    displayUnitSection(snapshot: snapshot)
                    healthSection(snapshot: snapshot)
                    dataSection(snapshot: snapshot)
                    aboutSection(snapshot: snapshot)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $presetEditorSheet) { sheetState in
                switch sheetState {
                case .add:
                    PresetEditorSheet(
                        mode: .add,
                        initialDraft: SettingsPresetDraft(locale: locale),
                        locale: locale,
                        onSave: { draft in
                            saveNewPreset(draft)
                        }
                    )
                case .edit(let item):
                    PresetEditorSheet(
                        mode: .edit,
                        initialDraft: SettingsPresetDraft(item: item, locale: locale),
                        locale: locale,
                        onSave: { draft in
                            saveEditedPreset(item: item, draft: draft)
                        }
                    )
                }
            }
            .confirmationDialog(
                "settings.data.restore.confirm.title",
                isPresented: $isShowingRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("settings.data.restore.confirm.action") {
                    isShowingFileImporter = true
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("settings.data.restore.confirm.message")
            }
            .fileExporter(
                isPresented: $isShowingFileExporter,
                document: activeExport?.document,
                contentType: activeExport?.contentType ?? .commaSeparatedText,
                defaultFilename: activeExport?.defaultFilename ?? "HalfUnit-export"
            ) { result in
                if case .failure(let error) = result {
                    Self.logger.error("File export failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleRestoreImportResult(result)
            }
            .task {
                reloadState()
            }
        }
    }

    private func presetsSection(snapshot: SettingsScreenSnapshot) -> some View {
        Section {
            ForEach(snapshot.presets) { item in
                HStack(spacing: 12) {
                    Button {
                        presetEditorSheet = .edit(item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbolName)
                                .font(.title3)
                                .foregroundStyle(item.isHidden ? Color.secondary : Color.teal)
                                .frame(width: 28, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.displayName)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(item.isHidden ? .secondary : .primary)

                                    if item.isHidden {
                                        Text("settings.presets.hiddenBadge")
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(Color.secondary.opacity(0.16))
                                            )
                                    }
                                }

                                Text(item.summaryText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        Text(
                            String(
                                format: AppLocalization.string(
                                    "settings.presets.row.accessibility",
                                    locale: locale
                                ),
                                locale: locale,
                                item.displayName,
                                item.summaryText
                            )
                        )
                    )

                    Button {
                        togglePresetHidden(item)
                    } label: {
                        Image(systemName: item.isHidden ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(
                        Text(
                            String(
                                format: AppLocalization.string(
                                    item.isHidden
                                        ? "settings.presets.unhide.accessibility"
                                        : "settings.presets.hide.accessibility",
                                    locale: locale
                                ),
                                locale: locale,
                                item.displayName
                            )
                        )
                    )
                }
            }
            .onMove { fromOffsets, toOffset in
                movePresets(fromOffsets: fromOffsets, toOffset: toOffset)
            }

            Button {
                presetEditorSheet = .add
            } label: {
                Label("settings.presets.add", systemImage: "plus.circle")
            }
            .accessibilityLabel(Text("settings.presets.add"))
        } header: {
            Text("settings.section.presets")
        } footer: {
            Text("settings.presets.footer")
        }
    }

    private func dayBoundarySection(snapshot: SettingsScreenSnapshot) -> some View {
        Section {
            Picker(
                "settings.dayBoundary.label",
                selection: Binding(
                    get: { snapshot.dayBoundaryHour },
                    set: { newHour in
                        updateDayBoundary(to: newHour)
                    }
                )
            ) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(SettingsScreenSnapshot.formatBoundaryHour(hour, locale: locale))
                        .tag(hour)
                }
            }
            .accessibilityLabel(Text("settings.dayBoundary.label"))
        } header: {
            Text("settings.section.dayBoundary")
        } footer: {
            Text("settings.dayBoundary.footer")
        }
    }

    private func displayUnitSection(snapshot: SettingsScreenSnapshot) -> some View {
        Section {
            Picker(
                "settings.displayUnit.label",
                selection: Binding(
                    get: { snapshot.displayUnit },
                    set: { newUnit in
                        updateDisplayUnit(newUnit)
                    }
                )
            ) {
                ForEach(DisplayUnit.allCases, id: \.self) { unit in
                    Text(LocalizedStringKey(SettingsScreenSnapshot.displayUnitLabelKey(for: unit)))
                        .tag(unit)
                }
            }
            .accessibilityLabel(Text("settings.displayUnit.label"))
        } header: {
            Text("settings.section.displayUnit")
        } footer: {
            Text("settings.displayUnit.footer")
        }
    }

    private func healthSection(snapshot: SettingsScreenSnapshot) -> some View {
        Section {
            Toggle(
                "settings.health.toggle",
                isOn: Binding(
                    get: { snapshot.isHealthSyncEnabled },
                    set: { isEnabled in
                        setHealthSyncEnabled(isEnabled)
                    }
                )
            )
            .tint(.teal)
            .accessibilityLabel(Text("settings.health.toggle"))

            HStack {
                Text("settings.health.status.label")
                Spacer()
                Text(snapshot.healthStatusText)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Button {
                requestHealthAuthorization()
            } label: {
                Text("settings.health.allow")
            }
            .accessibilityLabel(Text("settings.health.allow"))
        } header: {
            Text("settings.section.health")
        } footer: {
            Text("settings.health.footer")
        }
    }

    private func dataSection(snapshot: SettingsScreenSnapshot) -> some View {
        Section {
            Button {
                exportCSV(for: snapshot.todayDay)
            } label: {
                Label("settings.data.exportCSV", systemImage: "tablecells")
            }
            .accessibilityLabel(Text("settings.data.exportCSV"))

            Button {
                exportBackupJSON(for: snapshot.todayDay)
            } label: {
                Label("settings.data.backupJSON", systemImage: "arrow.down.doc")
            }
            .accessibilityLabel(Text("settings.data.backupJSON"))

            Button {
                isShowingRestoreConfirmation = true
            } label: {
                Label("settings.data.restore", systemImage: "arrow.up.doc")
            }
            .accessibilityLabel(Text("settings.data.restore"))

            if let statusBannerMessage {
                Text(statusBannerMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("settings.section.data")
        } footer: {
            Text("settings.data.footer")
        }
    }

    private func aboutSection(snapshot: SettingsScreenSnapshot) -> some View {
        Section {
            HStack {
                Text("settings.about.version")
                Spacer()
                Text(snapshot.appVersionText)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Text("settings.about.privacy")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("settings.about.guidanceNote")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Link(destination: SettingsAboutLinks.germanyURL) {
                HStack {
                    Text("settings.about.link.germany")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(Text("settings.about.link.germany"))

            Link(destination: SettingsAboutLinks.ukURL) {
                HStack {
                    Text("settings.about.link.uk")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(Text("settings.about.link.uk"))
        } header: {
            Text("settings.section.about")
        }
    }

    private func reloadState() {
        do {
            snapshot = try SettingsScreenSnapshot.load(
                from: logService,
                healthSync: healthSync,
                locale: locale
            )
        } catch {
            Self.logger.error("Failed to load Settings state: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func saveNewPreset(_ draft: SettingsPresetDraft) {
        guard
            draft.isValid,
            let volumeMl = draft.parsedVolumeMl,
            let abvPercent = draft.parsedAbvPercent
        else {
            return
        }
        do {
            _ = try logService.addPreset(
                name: draft.resolvedNameForStorage(locale: locale),
                symbolName: draft.symbolName,
                hu: draft.hu,
                volumeMl: volumeMl,
                abvPercent: abvPercent
            )
            WidgetCenter.shared.reloadAllTimelines()
            reloadState()
        } catch {
            Self.logger.error("Failed to add preset: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func saveEditedPreset(item: SettingsPresetItem, draft: SettingsPresetDraft) {
        guard
            draft.isValid,
            let volumeMl = draft.parsedVolumeMl,
            let abvPercent = draft.parsedAbvPercent
        else {
            return
        }
        do {
            let allPresets = try logService.presets(includeHidden: true)
            guard let preset = allPresets.first(where: { $0.id == item.id }) else {
                return
            }
            try logService.updatePreset(
                preset,
                name: draft.resolvedNameForStorage(locale: locale),
                symbolName: draft.symbolName,
                hu: draft.hu,
                volumeMl: volumeMl,
                abvPercent: abvPercent
            )
            if preset.isHidden != draft.isHidden {
                try logService.setPresetHidden(preset, draft.isHidden)
            }
            WidgetCenter.shared.reloadAllTimelines()
            reloadState()
        } catch {
            Self.logger.error("Failed to update preset: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func togglePresetHidden(_ item: SettingsPresetItem) {
        do {
            let allPresets = try logService.presets(includeHidden: true)
            guard let preset = allPresets.first(where: { $0.id == item.id }) else {
                return
            }
            try logService.setPresetHidden(preset, !item.isHidden)
            WidgetCenter.shared.reloadAllTimelines()
            reloadState()
        } catch {
            Self.logger.error("Failed to toggle preset visibility: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func movePresets(fromOffsets: IndexSet, toOffset: Int) {
        do {
            try logService.movePresets(fromOffsets: fromOffsets, toOffset: toOffset)
            WidgetCenter.shared.reloadAllTimelines()
            reloadState()
        } catch {
            Self.logger.error("Failed to reorder presets: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func updateDayBoundary(to hour: Int) {
        do {
            try logService.changeDayBoundary(to: hour)
            WidgetCenter.shared.reloadAllTimelines()
            reloadState()
        } catch {
            Self.logger.error("Failed to change day boundary: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func updateDisplayUnit(_ unit: DisplayUnit) {
        do {
            try logService.updateDisplayUnit(unit)
            WidgetCenter.shared.reloadAllTimelines()
            reloadState()
        } catch {
            Self.logger.error("Failed to update display unit: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func setHealthSyncEnabled(_ isEnabled: Bool) {
        Task { @MainActor in
            _ = await SettingsActions.setHealthSyncEnabled(isEnabled, healthSync: healthSync)
            reloadState()
        }
    }

    private func requestHealthAuthorization() {
        Task { @MainActor in
            _ = await SettingsActions.allowAppleHealth(healthSync: healthSync)
            reloadState()
        }
    }

    private func exportCSV(for day: LogicalDay) {
        do {
            let data = try CSVExporter.exportData(from: logService) { presetKey, storedName in
                PresetPresentation.localizedName(
                    presetKey: presetKey,
                    fallbackName: storedName,
                    locale: locale
                )
            }
            activeExport = ActiveFileExport(
                document: ExportDataDocument(data: data),
                contentType: .commaSeparatedText,
                defaultFilename: SettingsScreenSnapshot.csvDefaultFilename(for: day)
            )
            isShowingFileExporter = true
        } catch {
            Self.logger.error("Failed to prepare CSV export: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func exportBackupJSON(for day: LogicalDay) {
        do {
            let data = try BackupCodec.export(from: logService)
            activeExport = ActiveFileExport(
                document: ExportDataDocument(data: data),
                contentType: .json,
                defaultFilename: SettingsScreenSnapshot.backupDefaultFilename(for: day)
            )
            isShowingFileExporter = true
        } catch {
            Self.logger.error("Failed to prepare JSON backup: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func handleRestoreImportResult(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: url)
                Task { @MainActor in
                    do {
                        try await SettingsActions.restoreBackup(
                            from: data,
                            into: modelContext,
                            logService: logService,
                            healthSync: healthSync
                        )
                        statusBannerMessage = AppLocalization.string(
                            "settings.data.restore.success",
                            locale: locale
                        )
                        reloadState()
                    } catch {
                        Self.logger.error("Failed to restore backup: \(error.localizedDescription, privacy: .public)")
                        statusBannerMessage = AppLocalization.string(
                            "settings.data.restore.failed",
                            locale: locale
                        )
                    }
                }
            } catch {
                Self.logger.error("Failed to read backup file: \(error.localizedDescription, privacy: .public)")
                statusBannerMessage = AppLocalization.string(
                    "settings.data.restore.failed",
                    locale: locale
                )
            }
        case .failure(let error):
            Self.logger.error("File import cancelled or failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private struct PresetEditorSheet: View {
    enum Mode {
        case add
        case edit
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let locale: Locale
    let onSave: (SettingsPresetDraft) -> Void

    @State private var draft: SettingsPresetDraft

    init(
        mode: Mode,
        initialDraft: SettingsPresetDraft,
        locale: Locale,
        onSave: @escaping (SettingsPresetDraft) -> Void
    ) {
        self.mode = mode
        self.locale = locale
        self.onSave = onSave
        self._draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("settings.preset.name")
                        Spacer()
                        TextField("settings.preset.name.placeholder", text: $draft.nameText)
                            .multilineTextAlignment(.trailing)
                    }

                    let formattedHU = PresetPresentation.formattedHU(draft.hu, locale: locale)
                    Stepper {
                        HStack {
                            Text("settings.preset.hu")
                            Spacer()
                            Text(formattedHU)
                                .foregroundStyle(.secondary)
                        }
                    } onIncrement: {
                        draft.stepHU(by: 1)
                    } onDecrement: {
                        draft.stepHU(by: -1)
                    }
                    .accessibilityLabel(
                        Text(
                            String(
                                format: AppLocalization.string(
                                    "history.edit.hu.accessibility",
                                    locale: locale
                                ),
                                locale: locale,
                                formattedHU
                            )
                        )
                    )
                }

                Section("settings.preset.symbol") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 52), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(SettingsPresetSymbol.allCases) { symbol in
                            let isSelected = (draft.symbolName == symbol.rawValue)
                            Button {
                                draft.symbolName = symbol.rawValue
                            } label: {
                                Image(systemName: symbol.rawValue)
                                    .font(.title3)
                                    .foregroundStyle(isSelected ? Color.white : Color.teal)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                isSelected
                                                    ? Color.teal
                                                    : Color(.secondarySystemGroupedBackground)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(LocalizedStringKey(symbol.accessibilityKey)))
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    HStack {
                        Text("settings.preset.volume")
                        Spacer()
                        TextField("settings.preset.volume", text: $draft.volumeMlText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("settings.preset.abv")
                        Spacer()
                        TextField("settings.preset.abv", text: $draft.abvPercentText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("settings.preset.grams")
                        Spacer()
                        Text(draft.formattedGramsText(locale: locale))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                if mode == .edit {
                    Section {
                        Toggle("settings.preset.hidden", isOn: $draft.isHidden)
                            .tint(.teal)
                    }
                }
            }
            .navigationTitle(
                mode == .add
                    ? LocalizedStringKey("settings.preset.add.title")
                    : LocalizedStringKey("settings.preset.edit.title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }
}
