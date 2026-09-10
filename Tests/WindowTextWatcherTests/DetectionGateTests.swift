import XCTest
@testable import WindowTextWatcher

final class DetectionGateTests: XCTestCase {
    func testRepeatsWhileMatchRemainsAfterCooldown() {
        var gate = DetectionGate(cooldown: 5)
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(gate.shouldNotify(isMatch: true, now: now))
        XCTAssertFalse(gate.shouldNotify(isMatch: true, now: now.addingTimeInterval(4)))
        XCTAssertTrue(gate.shouldNotify(isMatch: true, now: now.addingTimeInterval(5)))
        XCTAssertFalse(gate.shouldNotify(isMatch: true, now: now.addingTimeInterval(9)))
        XCTAssertTrue(gate.shouldNotify(isMatch: true, now: now.addingTimeInterval(10)))
    }

    func testDoesNotNotifyWhileTextIsMissing() {
        var gate = DetectionGate(cooldown: 5)
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertFalse(gate.shouldNotify(isMatch: false, now: now))
        XCTAssertFalse(gate.shouldNotify(isMatch: false, now: now.addingTimeInterval(10)))
    }

    func testCooldownAlsoAppliesAfterTextDisappearsAndReappears() {
        var gate = DetectionGate(cooldown: 5)
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(gate.shouldNotify(isMatch: true, now: now))
        XCTAssertFalse(gate.shouldNotify(isMatch: false, now: now.addingTimeInterval(1)))
        XCTAssertFalse(gate.shouldNotify(isMatch: true, now: now.addingTimeInterval(2)))
        XCTAssertTrue(gate.shouldNotify(isMatch: true, now: now.addingTimeInterval(6)))
    }

    func testZeroCooldownAllowsEveryMatchingSample() {
        var gate = DetectionGate(cooldown: 0)
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(gate.shouldNotify(isMatch: true, now: now))
        XCTAssertTrue(gate.shouldNotify(isMatch: true, now: now.addingTimeInterval(0.45)))
    }
}
