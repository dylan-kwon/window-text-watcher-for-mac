import Foundation

enum MonitoringIssue: Hashable {
    case captureStalled
    case captureStopped
    case ocrStalled
    case ocrFailed

    var message: String {
        switch self {
        case .captureStalled:
            return "10초 이상 정상 화면 캡처가 확인되지 않습니다. 대상 창과 화면 기록 권한을 확인하세요."
        case .captureStopped:
            return "화면 캡처가 예기치 않게 중단되었습니다. 캡처를 다시 시작하세요."
        case .ocrStalled:
            return "10초 이상 OCR 처리가 진행되지 않습니다. 캡처를 다시 시작하세요."
        case .ocrFailed:
            return "OCR 처리가 3회 연속 실패했습니다. 대상 창과 OCR 영역을 확인하세요."
        }
    }
}

struct MonitoringHealth {
    private(set) var issue: MonitoringIssue?
    private var startedAt: TimeInterval?
    private var lastHeartbeat: TimeInterval?
    private var lastFrame: TimeInterval?
    private var pendingOCRSince: TimeInterval?
    private var ocrInFlightSince: TimeInterval?
    private var nextPendingOCRSince: TimeInterval?
    private var consecutiveOCRFailures = 0
    private var hasStreamFailed = false
    private var lastNotificationTimes: [MonitoringIssue: TimeInterval] = [:]
    private let timeout: TimeInterval = 10

    mutating func start(at time: TimeInterval) {
        self = MonitoringHealth()
        startedAt = time
    }

    mutating func stop() {
        self = MonitoringHealth()
    }

    mutating func receivedHeartbeat(at time: TimeInterval) {
        lastHeartbeat = time
    }

    mutating func receivedFrame(at time: TimeInterval) {
        lastHeartbeat = time
        lastFrame = time
        if pendingOCRSince == nil {
            pendingOCRSince = time
        }
        if ocrInFlightSince != nil, nextPendingOCRSince == nil {
            nextPendingOCRSince = time
        }
    }

    mutating func ocrStarted(at time: TimeInterval) {
        ocrInFlightSince = time
        nextPendingOCRSince = nil
        if pendingOCRSince == nil {
            pendingOCRSince = time
        }
    }

    mutating func ocrFinished(succeeded: Bool, at time: TimeInterval) {
        ocrInFlightSince = nil
        if succeeded {
            consecutiveOCRFailures = 0
            pendingOCRSince = nextPendingOCRSince
        } else {
            consecutiveOCRFailures += 1
        }
        nextPendingOCRSince = nil
    }

    mutating func streamFailed() {
        hasStreamFailed = true
    }

    mutating func check(
        at time: TimeInterval,
        cooldown: TimeInterval = DetectionGate.defaultCooldown
    ) -> MonitoringIssue? {
        guard let startedAt else {
            return nil
        }

        if hasStreamFailed {
            issue = .captureStopped
        } else if time - (lastHeartbeat ?? startedAt) >= timeout
                    || (lastFrame == nil && time - startedAt >= timeout) {
            issue = .captureStalled
        } else if consecutiveOCRFailures >= 3 {
            issue = .ocrFailed
        } else if let pendingSince = pendingOCRSince ?? ocrInFlightSince,
                  time - pendingSince >= timeout {
            issue = .ocrStalled
        } else {
            issue = nil
            lastNotificationTimes.removeAll()
        }

        guard let issue else {
            return nil
        }

        if let lastNotificationTime = lastNotificationTimes[issue],
           time - lastNotificationTime < max(0, cooldown) {
            return nil
        }

        lastNotificationTimes[issue] = time
        return issue
    }
}
