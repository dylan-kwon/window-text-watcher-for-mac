import XCTest
@testable import WindowTextWatcher

final class MonitoringHealthTests: XCTestCase {
    func testInactiveAndManualStopNeverAlert() {
        var health = MonitoringHealth()
        XCTAssertNil(health.check(at: 100))
        health.start(at: 100)
        health.stop()
        XCTAssertNil(health.check(at: 200))
    }

    func testMissingCaptureHasGracePeriodAndRepeatsAfterCooldown() {
        var health = MonitoringHealth()
        health.start(at: 0)
        XCTAssertNil(health.check(at: 9))
        XCTAssertEqual(health.check(at: 10), .captureStalled)
        XCTAssertNil(health.check(at: 11))
        XCTAssertNil(health.check(at: 12.9))
        XCTAssertEqual(health.check(at: 13), .captureStalled)
        XCTAssertNil(health.check(at: 13.1))
        XCTAssertEqual(health.check(at: 100), .captureStalled)
    }

    func testIdleCaptureDoesNotRequireNewOCR() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        health.ocrStarted(at: 1)
        health.ocrFinished(succeeded: true, at: 2)
        health.receivedHeartbeat(at: 30)
        XCTAssertNil(health.check(at: 30))
    }

    func testIdleWithoutFirstUsableFrameStillAlerts() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedHeartbeat(at: 10)
        XCTAssertEqual(health.check(at: 10), .captureStalled)
    }

    func testHangingOCRAndRecoveryAllowAnotherIncident() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        health.ocrStarted(at: 1)
        health.receivedHeartbeat(at: 11)
        XCTAssertEqual(health.check(at: 11), .ocrStalled)
        health.ocrFinished(succeeded: true, at: 12)
        health.receivedHeartbeat(at: 12)
        XCTAssertNil(health.check(at: 12))
        XCTAssertNil(health.issue)
        health.receivedFrame(at: 13)
        health.ocrStarted(at: 13)
        health.receivedHeartbeat(at: 23)
        XCTAssertEqual(health.check(at: 23), .ocrStalled)
    }

    func testRepeatedOCRFailuresAlertButTransientFailureDoesNot() {
        var health = MonitoringHealth()
        health.start(at: 0)
        for time in 1...3 {
            health.receivedFrame(at: Double(time))
            health.ocrStarted(at: Double(time))
            health.ocrFinished(succeeded: false, at: Double(time))
            if time < 3 {
                XCTAssertNil(health.check(at: Double(time)))
            }
        }
        XCTAssertEqual(health.check(at: 3), .ocrFailed)
    }

    func testFramesWithoutOCRProgressAlert() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        health.receivedFrame(at: 11)
        XCTAssertEqual(health.check(at: 11), .ocrStalled)
    }

    func testCaptureRecoveryAllowsLaterCaptureAlert() {
        var health = MonitoringHealth()
        health.start(at: 0)
        XCTAssertEqual(health.check(at: 10), .captureStalled)
        health.receivedFrame(at: 11)
        health.ocrStarted(at: 11)
        health.ocrFinished(succeeded: true, at: 12)
        XCTAssertNil(health.check(at: 12))
        XCTAssertNil(health.issue)
        XCTAssertEqual(health.check(at: 21), .captureStalled)
    }

    func testHealthyHeartbeatDoesNotHideUnprocessedLatestFrame() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        health.ocrStarted(at: 1)
        health.ocrFinished(succeeded: true, at: 2)
        health.receivedFrame(at: 3)
        health.receivedHeartbeat(at: 13)
        XCTAssertEqual(health.check(at: 13), .ocrStalled)
    }

    func testSuccessfulEmptyOCRResetsFailureCount() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        health.ocrStarted(at: 1)
        health.ocrFinished(succeeded: false, at: 2)
        health.ocrStarted(at: 3)
        health.ocrFinished(succeeded: false, at: 4)
        health.ocrStarted(at: 5)
        health.ocrFinished(succeeded: true, at: 6)
        health.receivedHeartbeat(at: 7)
        XCTAssertNil(health.check(at: 7))
        health.ocrStarted(at: 8)
        health.ocrFinished(succeeded: false, at: 9)
        XCTAssertNil(health.check(at: 9))
    }

    func testStreamFailureIsImmediateAndRestartResetsState() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.streamFailed()
        XCTAssertEqual(health.check(at: 1), .captureStopped)
        XCTAssertNil(health.check(at: 2))
        health.start(at: 3)
        XCTAssertNil(health.check(at: 4))
        XCTAssertNil(health.issue)
    }

    func testOCRCompletionPreservesFramesReceivedWhileProcessing() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        health.ocrStarted(at: 1)
        health.receivedFrame(at: 2)
        health.receivedFrame(at: 3)
        health.ocrFinished(succeeded: true, at: 4)
        health.receivedHeartbeat(at: 12)

        XCTAssertEqual(health.check(at: 12), .ocrStalled)

        health.ocrStarted(at: 13)
        health.ocrFinished(succeeded: true, at: 14)
        health.receivedHeartbeat(at: 14)

        XCTAssertNil(health.check(at: 14))
        XCTAssertNil(health.issue)
    }

    func testStartingDelayedOCRDoesNotResetPendingTimeout() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        health.ocrStarted(at: 10)
        health.receivedHeartbeat(at: 11)

        XCTAssertEqual(health.check(at: 11), .ocrStalled)
    }

    func testOCRRetryDoesNotResetPendingTimeout() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        health.ocrStarted(at: 1)
        health.ocrFinished(succeeded: false, at: 9)
        health.ocrStarted(at: 10)
        health.receivedHeartbeat(at: 11)

        XCTAssertEqual(health.check(at: 11), .ocrStalled)
    }

    func testFailedIdleOCRRetainsPendingTimeout() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        health.ocrStarted(at: 1)
        health.ocrFinished(succeeded: true, at: 2)
        health.receivedHeartbeat(at: 3)
        health.ocrStarted(at: 3)
        health.ocrFinished(succeeded: false, at: 4)
        health.receivedHeartbeat(at: 13)

        XCTAssertEqual(health.check(at: 13), .ocrStalled)
    }

    func testPersistentStreamFailureRepeatsUntilManualStop() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.streamFailed()

        XCTAssertEqual(health.check(at: 1), .captureStopped)
        XCTAssertNil(health.check(at: 3.9))
        XCTAssertEqual(health.check(at: 4), .captureStopped)

        health.stop()

        XCTAssertNil(health.check(at: 11))
        XCTAssertNil(health.issue)
    }

    func testHangingOCRRepeatsUntilRecovery() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        health.ocrStarted(at: 1)
        health.receivedHeartbeat(at: 11)

        XCTAssertEqual(health.check(at: 11), .ocrStalled)
        XCTAssertNil(health.check(at: 13.9))
        XCTAssertEqual(health.check(at: 14), .ocrStalled)

        health.ocrFinished(succeeded: true, at: 17)
        health.receivedHeartbeat(at: 22)

        XCTAssertNil(health.check(at: 22))
        XCTAssertNil(health.issue)
    }

    func testPersistentOCRFailuresRepeatAfterCooldown() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.receivedFrame(at: 1)
        for time in 1...3 {
            health.ocrStarted(at: Double(time))
            health.ocrFinished(succeeded: false, at: Double(time))
        }

        XCTAssertEqual(health.check(at: 3), .ocrFailed)
        XCTAssertNil(health.check(at: 5.9))
        XCTAssertEqual(health.check(at: 6), .ocrFailed)
    }

    func testCooldownChangesUseTimeOfLastNotification() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.streamFailed()

        XCTAssertEqual(health.check(at: 1, cooldown: 30), .captureStopped)
        XCTAssertNil(health.check(at: 6, cooldown: 30))
        XCTAssertEqual(health.check(at: 6, cooldown: 5), .captureStopped)
        XCTAssertNil(health.check(at: 11, cooldown: 10))
        XCTAssertEqual(health.check(at: 16, cooldown: 10), .captureStopped)
    }

    func testZeroAndNegativeCooldownAllowEveryCheck() {
        var health = MonitoringHealth()
        health.start(at: 0)
        health.streamFailed()

        XCTAssertEqual(health.check(at: 1, cooldown: 0), .captureStopped)
        XCTAssertEqual(health.check(at: 1, cooldown: 0), .captureStopped)
        XCTAssertEqual(health.check(at: 1, cooldown: -1), .captureStopped)
    }

    func testNewIssueAlertsImmediatelyWithinPreviousIssueCooldown() {
        var health = MonitoringHealth()
        health.start(at: 0)

        XCTAssertEqual(health.check(at: 10), .captureStalled)

        health.streamFailed()

        XCTAssertEqual(health.check(at: 11), .captureStopped)
        XCTAssertNil(health.check(at: 12))
        XCTAssertEqual(health.check(at: 16), .captureStopped)
    }

    func testRecoveryResetsNotificationCooldown() {
        var health = MonitoringHealth()
        health.start(at: 0)

        XCTAssertEqual(health.check(at: 10, cooldown: 60), .captureStalled)

        health.receivedFrame(at: 11)
        health.ocrStarted(at: 11)
        health.ocrFinished(succeeded: true, at: 12)

        XCTAssertNil(health.check(at: 12, cooldown: 60))
        XCTAssertEqual(health.check(at: 21, cooldown: 60), .captureStalled)
    }
}
