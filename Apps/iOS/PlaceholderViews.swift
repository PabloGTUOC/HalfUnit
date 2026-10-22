import SwiftUI

struct PlaceholderTabView: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "placeholder.comingSoon",
                systemImage: systemImage
            )
            .navigationTitle(titleKey)
        }
    }
}

struct SettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "placeholder.comingSoon",
                systemImage: "gearshape"
            )
            .navigationTitle("settings.title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
