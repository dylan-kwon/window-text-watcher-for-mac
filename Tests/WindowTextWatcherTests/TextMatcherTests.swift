import XCTest
@testable import WindowTextWatcher

final class TextMatcherTests: XCTestCase {
    func testWhitespaceRemainsSignificantByDefault() {
        XCTAssertFalse(TextMatcher(target: "낚시금지").matches("낚시 금지"))
    }

    func testIgnoresWhitespaceInBothKeywordAndRecognizedText() {
        let matcher = TextMatcher(target: "낚시금지", ignoreWhitespace: true)
        let spacedMatcher = TextMatcher(target: "낚시 금지", ignoreWhitespace: true)

        XCTAssertTrue(matcher.matches("여기는 낚시 금지 구역"))
        XCTAssertTrue(matcher.matches("낚시\n\t금지"))
        XCTAssertTrue(matcher.matches("낚시\u{00A0}금지"))
        XCTAssertTrue(spacedMatcher.matches("낚시금지"))
        XCTAssertFalse(matcher.matches("낚시 가능"))
        XCTAssertFalse(TextMatcher(target: " \n\t", ignoreWhitespace: true).matches("낚시"))
    }

    func testWhitespaceOptionPreservesCaseSensitivity() {
        let matcher = TextMatcher(target: "Fish On", caseSensitive: true, ignoreWhitespace: true)

        XCTAssertTrue(matcher.matches("FishOn"))
        XCTAssertFalse(matcher.matches("FISH ON"))
        XCTAssertTrue(TextMatcher(target: "Fish On", ignoreWhitespace: true).matches("FISHON"))
    }

    func testMatchesSubstringIgnoringCaseByDefault() {
        let matcher = TextMatcher(target: "Fish On")

        XCTAssertTrue(matcher.matches("status: FISH ON!"))
    }

    func testNormalizesWhitespaceBeforeMatching() {
        let matcher = TextMatcher(target: "알림 등장")

        XCTAssertTrue(matcher.matches("알림\n\t  등장"))
    }

    func testEmptyTargetNeverMatches() {
        let matcher = TextMatcher(target: "   ")

        XCTAssertFalse(matcher.matches("anything"))
    }

    func testCaseSensitiveMode() {
        let matcher = TextMatcher(
            target: "BITE",
            caseSensitive: true
        )

        XCTAssertFalse(matcher.matches("bite"))
        XCTAssertTrue(matcher.matches("BITE"))
    }
}
