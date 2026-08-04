import Foundation

enum L10n {
    static func string(_ key: String, fallback: String) -> String {
        Bundle.main.localizedString(
            forKey: key,
            value: fallback,
            table: nil
        )
    }

    static func format(
        _ key: String,
        fallback: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key, fallback: fallback),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
