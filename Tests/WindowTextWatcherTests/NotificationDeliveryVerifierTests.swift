import XCTest
@testable import WindowTextWatcher

final class NotificationDeliveryVerifierTests: XCTestCase {
    func testFindsMatchingDeliveredIdentifier() {
        XCTAssertTrue(
            NotificationDeliveryVerifier.isDelivered(
                identifier: "test-123",
                deliveredIdentifiers: ["other", "test-123"]
            )
        )
    }

    func testReturnsFalseWhenIdentifierIsMissing() {
        XCTAssertFalse(
            NotificationDeliveryVerifier.isDelivered(
                identifier: "test-123",
                deliveredIdentifiers: ["other"]
            )
        )
    }
}
