import XCTest
@testable import WindowTextWatcher

final class ScreenCaptureAccessPolicyTests: XCTestCase {
    func testAuthorizedStateCanLoadWindows() {
        XCTAssertTrue(
            ScreenCaptureAccessPolicy.canLoadWindows(
                hasPermission: true
            )
        )
    }

    func testLegacyPreflightFailureStillAttemptsWindowEnumeration() {
        XCTAssertTrue(
            ScreenCaptureAccessPolicy.canLoadWindows(
                hasPermission: false
            )
        )
    }

    func testPermissionMessageExplainsHowToRecover() {
        let message = ScreenCaptureAccessPolicy.permissionRequiredMessage

        XCTAssertTrue(message.contains("화면 기록"))
        XCTAssertTrue(message.contains("권한"))
    }
}
