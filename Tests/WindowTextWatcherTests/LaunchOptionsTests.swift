import XCTest
@testable import WindowTextWatcher

final class LaunchOptionsTests: XCTestCase {
    func testTestNotificationFlagIsDetected() {
        let options = LaunchOptions(
            arguments: ["WindowTextWatcher", "--test-notification"]
        )

        XCTAssertTrue(options.shouldSendTestNotification)
    }

    func testNormalLaunchDoesNotSendTestNotification() {
        let options = LaunchOptions(
            arguments: ["WindowTextWatcher"]
        )

        XCTAssertFalse(options.shouldSendTestNotification)
    }
}
