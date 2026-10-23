import Foundation
import HalfUnitCore

enum EarlierOffset: Int, CaseIterable, Identifiable, Sendable {
    case minutes15 = 15
    case minutes30 = 30
    case hours1 = 60
    case hours2 = 120
    case hours3 = 180

    var id: Int { rawValue }

    var seconds: TimeInterval {
        TimeInterval(rawValue * 60)
    }

    var catalogKey: String {
        switch self {
        case .minutes15:
            "watch.logEarlier.offset.15m"
        case .minutes30:
            "watch.logEarlier.offset.30m"
        case .hours1:
            "watch.logEarlier.offset.1h"
        case .hours2:
            "watch.logEarlier.offset.2h"
        case .hours3:
            "watch.logEarlier.offset.3h"
        }
    }

    func targetTimestamp(from now: Date) -> Date {
        now.addingTimeInterval(-seconds)
    }

    func localizedTitle(locale: Locale = .current) -> String {
        AppLocalization.string(catalogKey, locale: locale)
    }

    func accessibilityLabel(
        presetKey: String?,
        fallbackName: String,
        locale: Locale = .current
    ) -> String {
        let displayName = PresetPresentation.localizedName(
            presetKey: presetKey,
            fallbackName: fallbackName,
            locale: locale
        )
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let spokenName = languageCode == "de" ? displayName : displayName.lowercased(with: locale)
        let offsetTitle = localizedTitle(locale: locale)
        let format = AppLocalization.string("watch.logEarlier.offset.accessibility", locale: locale)
        return String(format: format, locale: locale, spokenName, offsetTitle)
    }
}

typealias WatchEarlierOffset = EarlierOffset
