import Foundation

struct TextMatcher {
    let target: String
    let caseSensitive: Bool

    init(
        target: String,
        caseSensitive: Bool = false
    ) {
        self.target = target
        self.caseSensitive = caseSensitive
    }

    func matches(_ recognizedText: String) -> Bool {
        let normalizedTarget = Self.normalize(target)
        let normalizedRecognizedText = Self.normalize(recognizedText)

        guard !normalizedTarget.isEmpty else {
            return false
        }

        if caseSensitive {
            return normalizedRecognizedText.contains(normalizedTarget)
        }

        return normalizedRecognizedText.range(
            of: normalizedTarget,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }

    private static func normalize(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
