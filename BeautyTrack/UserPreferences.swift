import SwiftUI

/// Namespaced keys and enums for user-configurable app preferences.
enum UserPreferences {
    static let appearanceKey = "preferences.appearance"
    static let salonNameKey = "profile.salonName"
    static let ownerNameKey = "profile.ownerName"
    static let emailKey = "profile.email"
}

enum AppearanceOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// Returns the SwiftUI color scheme associated with the option.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
