import Foundation
import AppKit

/// Look up a localized string from the in-memory translation table.
/// Use this everywhere instead of NSLocalizedString / Text("key").
/// - Parameters:
///   - key: The string key in translations.json
///   - args: Optional format arguments (for %lld / %@ placeholders)
/// - Returns: The localized string in the currently active language
func loc(_ key: String, _ args: CVarArg...) -> String {
    let format = LocalizationService.translated(key)
    return args.isEmpty ? format : String(format: format, arguments: args)
}

/// Manages the app's language preference and provides localized strings.
final class LocalizationService {

    // MARK: - Language definition

    enum Language: String, CaseIterable, Identifiable {
        case system = ""
        case zhHans = "zh-Hans"
        case en = "en"
        case ja = "ja"

        var id: String { rawValue }

        /// Display name in the language itself
        var displayName: String {
            switch self {
            case .system: return loc("settings.language.follow.system")
            case .zhHans: return "中文"
            case .en:     return "English"
            case .ja:     return "日本語"
            }
        }

        /// BCP 47 language tag used for AppleLanguages
        var localeIdentifier: String {
            switch self {
            case .system: return Self.currentSystemLanguage
            case .zhHans: return "zh-Hans"
            case .en:     return "en"
            case .ja:     return "ja"
            }
        }

        /// The system's active language code (e.g. "zh-Hans", "ja", "en")
        fileprivate static var currentSystemLanguage: String {
            if #available(macOS 13, *) {
                let lang = Locale.current.language
                if let script = lang.script?.identifier {
                    return "\(lang.languageCode?.identifier ?? "en")-\(script)"
                }
                switch lang.languageCode?.identifier {
                case "zh": return "zh-Hans"
                case "ja": return "ja"
                default:   return "en"
                }
            } else {
                let fullId = Locale.current.identifier
                let parts = fullId.components(separatedBy: "_")
                if parts.count >= 2 {
                    switch parts[0] {
                    case "zh": return "zh-Hans"
                    case "ja": return "ja"
                    default:   return "en"
                    }
                }
                return parts.first ?? "en"
            }
        }
    }

    // MARK: - Singleton & state

    static let shared = LocalizationService()

    /// The currently selected language.
    /// **system** = follow the macOS system language setting.
    var selectedLanguage: Language {
        didSet {
            UserDefaults.standard.set(
                selectedLanguage.rawValue.isEmpty ? nil : selectedLanguage.rawValue,
                forKey: .selectedLanguage
            )
        }
    }

    /// The effective language code to use for lookups right now.
    /// When `selectedLanguage == .system`, returns the system language.
    var effectiveLanguageCode: String {
        if selectedLanguage == .system {
            return Language.currentSystemLanguage
        }
        return selectedLanguage.rawValue
    }

    // MARK: - Translation table

    private static var translations: [String: [String: String]] = [:]
    private static var loaded = false

    private static func ensureLoaded() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.module.url(forResource: "translations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
        else {
            print("loc: failed to load translations.json from \(Bundle.module.bundlePath)")
            return
        }
        translations = json
    }

    /// Look up a translation key for the effective language.
    static func translated(_ key: String) -> String {
        ensureLoaded()
        let lang = shared.effectiveLanguageCode

        // Exact match
        if let entry = translations[key], let value = entry[lang] {
            return value
        }
        // Fall back to English
        if let entry = translations[key], let value = entry["en"] {
            return value
        }
        // Ultimate fallback: show the key
        return key
    }

    // MARK: - Init

    private init() {
        // Restore saved preference
        if let saved = UserDefaults.standard.string(forKey: .selectedLanguage),
           !saved.isEmpty {
            selectedLanguage = Language(rawValue: saved) ?? .system
        } else {
            selectedLanguage = .system
        }
    }

    // MARK: - Apply language & restart

    /// Save language preference and restart the app.
    func applyLanguage(_ language: Language) {
        selectedLanguage = language

        // Set AppleLanguages so system APIs also use the right language
        let codes = language.rawValue.isEmpty
            ? [Language.currentSystemLanguage]
            : [language.rawValue]
        UserDefaults.standard.set(codes, forKey: .appleLanguages)
        UserDefaults.standard.synchronize()

        restartApp()
    }

    /// Launch a new instance of ourselves, then exit.
    private func restartApp() {
        let execPath = CommandLine.arguments[0]

        let task = Process()
        task.executableURL = URL(fileURLWithPath: execPath)

        // Pass along any command-line arguments (e.g. test flags)
        if CommandLine.arguments.count > 1 {
            task.arguments = Array(CommandLine.arguments.dropFirst())
        }

        do {
            try task.run()
            // Small delay so the new process can start before we exit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            print("loc: failed to restart app: \(error)")
        }
    }
}

// MARK: - UserDefaults keys

private extension String {
    static let selectedLanguage = "com.localpaste.selectedLanguage"
    static let appleLanguages = "AppleLanguages"
}
