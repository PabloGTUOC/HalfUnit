import CoreData
import Foundation
import HalfUnitCore
import OSLog
import SwiftData
import SwiftUI
import WidgetKit

struct HistoryView: View {
    private static let logger = Logger(subsystem: "es.opinasdeque.halfunit", category: "HistoryView")
    private static let externalChangeDebounceDuration: Duration = .milliseconds(300)

    let logService: LogService
    let healthSync: HealthSync

    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    @State private var searchQuery = ""
    @State private var snapshot: HistoryScreenSnapshot?
    @State private var editingItem: HistoryDrinkItem?
    @State private var externalChangeReloadTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot {
                    if snapshot.isEmptyStore {
                        ContentUnavailableView(
                            "history.empty.title",
                            systemImage: "clock",
                            description: Text("history.empty.subtitle")
                        )
                    } else if snapshot.isSearchEmpty {
                        ContentUnavailableView(
                            "history.search.empty.title",
                            systemImage: "magnifyingglass",
                            description: Text("history.search.empty.subtitle")
                        )
                    } else {
                        List {
                            ForEach(snapshot.sections) { section in
                                Section {
                                    ForEach(section.items) { item in
                                        Button {
                                            editingItem = item
                                        } label: {
                                            drinkRow(
                                                item: item,
                                                displayUnit: snapshot.displayUnit
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel(Text(item.accessibilityLabel))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteItem(item)
                                            } label: {
                                                Label("common.delete", systemImage: "trash")
                                            }
                                            .accessibilityLabel(Text(item.deleteAccessibilityLabel))
                                        }
                                    }
                                } header: {
                                    HStack {
                                        Text(section.title)
                                        Spacer()
                                        Text(section.totalDisplayText)
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("tab.history")
            .searchable(
                text: $searchQuery,
                prompt: Text("history.search.prompt")
            )
            .sheet(item: $editingItem) { item in
                HistoryEditSheet(
                    item: item,
                    presets: snapshot?.presetOptions ?? [],
                    locale: locale,
                    onSave: { edit in
                        saveEdit(for: item, edit: edit)
                    }
                )
            }
            .task {
                reloadState()
            }
            .onChange(of: searchQuery) { _, _ in
                reloadState()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }
                reloadState()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: ModelContext.didSave)
                    .receive(on: RunLoop.main)
            ) { _ in
                scheduleExternalChangeReload()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                scheduleExternalChangeReload()
            }
            .onDisappear {
                externalChangeReloadTask?.cancel()
                externalChangeReloadTask = nil
            }
        }
    }

    private func drinkRow(item: HistoryDrinkItem, displayUnit: DisplayUnit) -> some View {
        HStack(spacing: 12) {
            PresetPresentation.image(for: item.symbolName)
                .font(.title3)
                .foregroundStyle(BrandColors.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.localizedName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(item.timeText)
                    if let volumeMl = item.volumeMl {
                        Text("·")
                        Text(
                            String(
                                format: AppLocalization.string("unit.mlValue", locale: locale),
                                locale: locale,
                                Int64(volumeMl)
                            )
                        )
                    }
                    if let abv = item.abvPercent {
                        let abvNumber = PresetPresentation.formattedHUNumber(abv, locale: locale)
                        Text("·")
                        Text(
                            String(
                                format: AppLocalization.string("unit.abvValue", locale: locale),
                                locale: locale,
                                abvNumber
                            )
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.primaryAmountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if displayUnit != .grams {
                    Text(item.gramsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func deleteItem(_ item: HistoryDrinkItem) {
        do {
            let activeDrinks = try logService.drinks(includeDeleted: false)
            if let drink = activeDrinks.first(where: { $0.id == item.id }) {
                _ = try Self.deleteAndReconcile(
                    drink: drink,
                    logService: logService,
                    healthSync: healthSync
                )
                reloadState()
            }
        } catch {
            Self.logger.error(
                "Failed to delete drink: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    private func saveEdit(for item: HistoryDrinkItem, edit: DrinkEdit) {
        do {
            let activeDrinks = try logService.drinks(includeDeleted: false)
            if let drink = activeDrinks.first(where: { $0.id == item.id }) {
                _ = try Self.editAndReconcile(
                    drink: drink,
                    edit: edit,
                    logService: logService,
                    healthSync: healthSync
                )
                reloadState()
            }
        } catch {
            Self.logger.error(
                "Failed to edit drink: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    private func reloadState() {
        do {
            try logService.seedDefaultPresetsIfNeeded()
            snapshot = try HistoryScreenSnapshot.load(
                from: logService,
                searchQuery: searchQuery,
                locale: locale
            )
        } catch {
            Self.logger.error(
                "Failed to load History state: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    private func scheduleExternalChangeReload() {
        externalChangeReloadTask?.cancel()
        externalChangeReloadTask = Task { @MainActor in
            do {
                try await Task.sleep(for: Self.externalChangeDebounceDuration)
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            reloadState()
        }
    }

    @MainActor
    @discardableResult
    static func deleteAndReconcile(
        drink: Drink,
        logService: LogService,
        healthSync: HealthSync
    ) throws -> Task<HealthSync.Status, Never> {
        try logService.delete(drink)
        WidgetCenter.shared.reloadAllTimelines()
        return Task { @MainActor in
            await HalfUnitApp.reconcileHealth(healthSync: healthSync)
            return healthSync.lastStatus
        }
    }

    @MainActor
    @discardableResult
    static func editAndReconcile(
        drink: Drink,
        edit: DrinkEdit,
        logService: LogService,
        healthSync: HealthSync
    ) throws -> Task<HealthSync.Status, Never> {
        try logService.edit(drink, edit)
        WidgetCenter.shared.reloadAllTimelines()
        return Task { @MainActor in
            await HalfUnitApp.reconcileHealth(healthSync: healthSync)
            return healthSync.lastStatus
        }
    }
}

private struct HistoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: HistoryDrinkItem
    let presets: [HistoryPresetOption]
    let locale: Locale
    let onSave: (DrinkEdit) -> Void

    @State private var draft: HistoryDrinkEditDraft

    init(
        item: HistoryDrinkItem,
        presets: [HistoryPresetOption],
        locale: Locale,
        onSave: @escaping (DrinkEdit) -> Void
    ) {
        self.item = item
        self.presets = presets
        self.locale = locale
        self.onSave = onSave
        self._draft = State(initialValue: HistoryDrinkEditDraft(item: item, locale: locale))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "history.edit.time",
                        selection: $draft.timestamp,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Picker(
                        "history.edit.preset",
                        selection: Binding(
                            get: { draft.selectedPresetId },
                            set: { newId in
                                if let newId,
                                    let selected = presets.first(where: { $0.id == newId })
                                {
                                    draft.applyPreset(selected, locale: locale)
                                } else {
                                    draft.selectedPresetId = newId
                                }
                            }
                        )
                    ) {
                        if item.presetId == nil
                            || !presets.contains(where: { $0.id == item.presetId })
                        {
                            let customFormat = AppLocalization.string(
                                "history.edit.preset.custom",
                                locale: locale
                            )
                            Text(String(format: customFormat, locale: locale, item.localizedName))
                                .tag(item.presetId)
                        }

                        ForEach(presets) { preset in
                            Text(preset.localizedName)
                                .tag(Optional(preset.id))
                        }
                    }

                    let formattedHU = PresetPresentation.formattedHU(draft.hu, locale: locale)
                    Stepper {
                        HStack {
                            Text("history.edit.hu")
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

                Section {
                    HStack {
                        Text("history.edit.volume")
                        Spacer()
                        TextField(
                            "history.edit.volume.placeholder",
                            text: $draft.volumeMlText
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)

                        if !draft.volumeMlText.isEmpty {
                            Button {
                                draft.volumeMlText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("history.edit.volume.clear"))
                        }
                    }

                    HStack {
                        Text("history.edit.abv")
                        Spacer()
                        TextField(
                            "history.edit.abv.placeholder",
                            text: $draft.abvPercentText
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)

                        if !draft.abvPercentText.isEmpty {
                            Button {
                                draft.abvPercentText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("history.edit.abv.clear"))
                        }
                    }
                }

                Section("history.edit.note") {
                    HStack {
                        TextField(
                            "history.edit.note.placeholder",
                            text: $draft.noteText,
                            axis: .vertical
                        )

                        if !draft.noteText.isEmpty {
                            Button {
                                draft.noteText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("history.edit.note.clear"))
                        }
                    }
                }
            }
            .navigationTitle("history.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        let edit = draft.buildDrinkEdit(presets: presets)
                        onSave(edit)
                        dismiss()
                    }
                }
            }
        }
    }
}
