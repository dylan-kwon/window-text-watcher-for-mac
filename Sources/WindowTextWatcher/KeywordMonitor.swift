import Foundation

struct KeywordMonitor {
    private(set) var keywords: [String] = []
    private(set) var matchedKeywords: [String] = []
    private var gates: [String: DetectionGate] = [:]

    @discardableResult
    mutating func add(_ text: String) -> Bool {
        let keyword = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { component in
                !component.isEmpty
            }
            .joined(separator: " ")

        guard !keyword.isEmpty, !keywords.contains(keyword) else {
            return false
        }

        keywords.append(keyword)
        return true
    }

    mutating func remove(_ keyword: String) {
        keywords.removeAll { candidate in
            candidate == keyword
        }
        matchedKeywords.removeAll { candidate in
            candidate == keyword
        }
        gates.removeValue(forKey: keyword)
    }

    mutating func reset() {
        gates.removeAll()
        matchedKeywords.removeAll()
    }

    mutating func evaluate(
        _ text: String,
        caseSensitive: Bool,
        cooldown: TimeInterval,
        ignoreWhitespace: Bool = false,
        now: Date = Date()
    ) -> [String] {
        matchedKeywords = []
        var notifications: [String] = []

        for keyword in keywords {
            let isMatch = TextMatcher(
                target: keyword,
                caseSensitive: caseSensitive,
                ignoreWhitespace: ignoreWhitespace
            ).matches(text)

            if isMatch {
                matchedKeywords.append(keyword)
            }

            var gate = gates[keyword] ?? DetectionGate()
            gate.cooldown = max(0, cooldown)

            if gate.shouldNotify(isMatch: isMatch, now: now) {
                notifications.append(keyword)
            }

            gates[keyword] = gate
        }

        return notifications
    }
}
