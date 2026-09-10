import XCTest
@testable import WindowTextWatcher

final class TextMatcherTests: XCTestCase {
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
