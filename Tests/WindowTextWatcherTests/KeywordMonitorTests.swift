import XCTest
@testable import WindowTextWatcher

final class KeywordMonitorTests: XCTestCase {
    func testWhitespaceOptionAppliesToAllKeywords() {
        var monitor = KeywordMonitor()
        monitor.add("낚시금지")
        monitor.add("작업 완료")

        XCTAssertTrue(monitor.evaluate("낚시 금지, 작업완료", caseSensitive: false, cooldown: 3).isEmpty)
        XCTAssertEqual(
            monitor.evaluate("낚시 금지, 작업완료", caseSensitive: false, cooldown: 3, ignoreWhitespace: true),
            ["낚시금지", "작업 완료"]
        )
    }

    func testAddsKeywordsWithoutAnArtificialLimit() {
        var monitor = KeywordMonitor()

        for index in 0..<200 {
            XCTAssertTrue(monitor.add("키워드 \(index)"))
        }

        XCTAssertEqual(monitor.keywords.count, 200)
    }

    func testRejectsBlankAndDuplicateKeywordsAndNormalizesWhitespace() {
        var monitor = KeywordMonitor()

        XCTAssertFalse(monitor.add(" \n\t "))
        XCTAssertTrue(monitor.add("  작업\n 완료  "))
        XCTAssertFalse(monitor.add("작업 완료"))
        XCTAssertEqual(monitor.keywords, ["작업 완료"])
    }

    func testMatchesEachKeywordAndIgnoresUnmatchedKeywords() {
        var monitor = KeywordMonitor()
        monitor.add("완료")
        monitor.add("ERROR")
        monitor.add("대기")

        let notifications = monitor.evaluate("작업 완료, error", caseSensitive: false, cooldown: 3)

        XCTAssertEqual(notifications, ["완료", "ERROR"])
        XCTAssertEqual(monitor.matchedKeywords, ["완료", "ERROR"])
    }

    func testNewMatchHasIndependentCooldown() {
        var monitor = KeywordMonitor()
        monitor.add("완료")
        monitor.add("오류")
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(monitor.evaluate("완료", caseSensitive: false, cooldown: 3, now: now), ["완료"])
        XCTAssertEqual(monitor.evaluate("완료 오류", caseSensitive: false, cooldown: 3, now: now.addingTimeInterval(1)), ["오류"])
        XCTAssertEqual(monitor.evaluate("완료 오류", caseSensitive: false, cooldown: 3, now: now.addingTimeInterval(3)), ["완료"])
    }

    func testAddingKeywordDoesNotResetExistingCooldown() {
        var monitor = KeywordMonitor()
        monitor.add("완료")
        let now = Date(timeIntervalSince1970: 100)
        _ = monitor.evaluate("완료", caseSensitive: false, cooldown: 3, now: now)
        monitor.add("오류")

        XCTAssertEqual(monitor.evaluate("완료 오류", caseSensitive: false, cooldown: 3, now: now.addingTimeInterval(1)), ["오류"])
    }

    func testRemovalClearsMatchAndAllowsFreshDetectionWhenAddedAgain() {
        var monitor = KeywordMonitor()
        monitor.add("완료")
        let now = Date(timeIntervalSince1970: 100)
        _ = monitor.evaluate("완료", caseSensitive: false, cooldown: 3, now: now)

        monitor.remove("완료")

        XCTAssertTrue(monitor.keywords.isEmpty)
        XCTAssertTrue(monitor.matchedKeywords.isEmpty)
        XCTAssertTrue(monitor.evaluate("완료", caseSensitive: false, cooldown: 3, now: now).isEmpty)
        monitor.add("완료")
        XCTAssertEqual(monitor.evaluate("완료", caseSensitive: false, cooldown: 3, now: now), ["완료"])
    }

    func testCaseSensitivityAndMissingTextClearMatches() {
        var monitor = KeywordMonitor()
        monitor.add("ERROR")

        XCTAssertTrue(monitor.evaluate("error", caseSensitive: true, cooldown: 3).isEmpty)
        XCTAssertEqual(monitor.evaluate("ERROR", caseSensitive: true, cooldown: 3), ["ERROR"])
        XCTAssertTrue(monitor.evaluate("", caseSensitive: true, cooldown: 3).isEmpty)
        XCTAssertTrue(monitor.matchedKeywords.isEmpty)
    }

    func testResetClearsDetectionStateAndCooldownButKeepsKeywords() {
        var monitor = KeywordMonitor()
        monitor.add("완료")
        let now = Date(timeIntervalSince1970: 100)
        _ = monitor.evaluate("완료", caseSensitive: false, cooldown: 3, now: now)

        monitor.reset()

        XCTAssertEqual(monitor.keywords, ["완료"])
        XCTAssertTrue(monitor.matchedKeywords.isEmpty)
        XCTAssertEqual(monitor.evaluate("완료", caseSensitive: false, cooldown: 3, now: now), ["완료"])
    }
}
