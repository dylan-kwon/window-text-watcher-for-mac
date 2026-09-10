import XCTest
@testable import WindowTextWatcher

final class NotificationMessageTests: XCTestCase {
    func testDetectedNotificationMessageContainsTargetAndPreview() {
        let message = NotificationMessage.detected(
            target: "완료",
            recognizedText: "작업이\n  완료되었습니다"
        )

        XCTAssertEqual(message.title, "OCR 텍스트 감지")
        XCTAssertTrue(message.body.contains("완료 감지됨"))
        XCTAssertTrue(message.body.contains("작업이 완료되었습니다"))
    }

    func testTestNotificationMessageIsClearlyIdentified() {
        let message = NotificationMessage.test

        XCTAssertEqual(message.title, "Window Text Watcher")
        XCTAssertTrue(message.body.contains("테스트 알림"))
    }
}
