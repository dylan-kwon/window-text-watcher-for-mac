import Foundation

struct TextMatcher {
    let target: String
    let caseSensitive: Bool
    let ignoreWhitespace: Bool

    init(
        target: String,
        caseSensitive: Bool = false,
        ignoreWhitespace: Bool = false
    ) {
        self.target = target
        self.caseSensitive = caseSensitive
        self.ignoreWhitespace = ignoreWhitespace
    }

    func matches(_ recognizedText: String) -> Bool {
        let normalizedTarget = normalize(target)
        let normalizedRecognizedText = normalize(recognizedText)

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

    private func normalize(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { component in
                !component.isEmpty
            }
            .joined(separator: ignoreWhitespace ? "" : " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
