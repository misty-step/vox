import Foundation

enum ElevenLabsLanguage {
    static func normalize(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let lowered = raw.lowercased()
        let primary = lowered.split(separator: "-").first?.split(separator: "_").first.map(String.init) ?? lowered

        if primary.count == 3 {
            return primary
        }

        if let mapped = twoToThreeLetter[primary] {
            return mapped
        }

        return nil
    }

    private static let twoToThreeLetter: [String: String] = [
        "en": "eng",
        "es": "spa",
        "fr": "fra",
        "de": "deu",
        "it": "ita",
        "pt": "por",
        "zh": "zho",
        "ja": "jpn",
        "ko": "kor",
        "ru": "rus",
        "nl": "nld",
        "sv": "swe",
        "no": "nor",
        "da": "dan",
        "fi": "fin",
        "pl": "pol",
        "tr": "tur"
    ]
}
