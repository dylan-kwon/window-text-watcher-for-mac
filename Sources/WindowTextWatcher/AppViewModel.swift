import AppKit
import CoreGraphics
import Foundation
import UserNotifications

@MainActor
final class AppViewModel: ObservableObject {
    @Published var windows: [CaptureWindow] = []
    @Published var selectedWindowID: CGWindowID?
    @Published var latestFrame: CGImage?
    @Published var region = CGRect(x: 0, y: 0, width: 1, height: 1)
    @Published var targetText = "" {
        didSet {
            detectionGate.reset()
        }
    }
    @Published var caseSensitive = false {
        didSet {
            detectionGate.reset()
        }
    }
    @Published var cooldownSeconds: Double = 5
    @Published var recognizedText = ""
    @Published var isCapturing = false
    @Published var isChangingCapture = false
    @Published var monitoringIssue: MonitoringIssue?
    @Published var isTargetDetected = false
    @Published var needsScreenRecordingPermission = false
    @Published var statusText = "캡처할 창을 선택하세요."
    @Published var notificationStatusText = "알림 권한 확인 중…"

    private let captureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private let notificationService = NotificationService()
    private var lastOCRDate = Date.distantPast
    private var isOCRInFlight = false
    private var detectionGate = DetectionGate(cooldown: 5)
    private let ocrInterval: TimeInterval = 0.45
    private var monitoringHealth = MonitoringHealth()
    private var healthTimer: Timer?
    private var captureSessionID = UUID()

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        let launchOptions = LaunchOptions(arguments: arguments)

        captureService.onFrame = { [weak self] image in
            self?.handleFrame(image)
        }
        captureService.onHeartbeat = { [weak self] in
            guard let self, self.isCapturing else {
                return
            }
            self.monitoringHealth.receivedHeartbeat(at: ProcessInfo.processInfo.systemUptime)
            self.processLatestFrame()
        }
        captureService.onFailure = { [weak self] error in
            self?.handleCaptureFailure(error)
        }

        notificationService.onPresented = { [weak self] identifier in
            guard identifier.hasPrefix("test-") else {
                return
            }

            DispatchQueue.main.async {
                self?.notificationStatusText = "테스트 알림 표시 확인됨"
            }
        }

        refreshNotificationStatus()
        notificationService.requestAuthorization { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.refreshNotificationStatus()

                if granted && launchOptions.shouldSendTestNotification {
                    self.sendTestNotification()
                }
            }
        }
    }

    func refreshNotificationStatus() {
        notificationService.getAuthorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                switch status {
                case .authorized:
                    self.notificationStatusText = "알림 권한: 허용됨"
                case .provisional:
                    self.notificationStatusText = "알림 권한: 임시 허용됨"
                case .ephemeral:
                    self.notificationStatusText = "알림 권한: 일시 허용됨"
                case .denied:
                    self.notificationStatusText = "알림 권한: 거부됨"
                case .notDetermined:
                    self.notificationStatusText = "알림 권한: 미설정"
                @unknown default:
                    self.notificationStatusText = "알림 권한: 알 수 없음"
                }
            }
        }
    }

    func sendTestNotification() {
        notificationStatusText = "테스트 알림 전송 중…"

        notificationService.sendTestNotification { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                switch result {
                case .success(let identifier):
                    self.notificationStatusText = "테스트 알림 전송 요청 성공 · 표시 대기 중…"
                    self.verifyTestNotificationDelivery(
                        identifier: identifier
                    )
                case .failure(let error):
                    self.notificationStatusText = "테스트 알림 실패: \(error.localizedDescription)"
                }
            }
        }
    }

    private func verifyTestNotificationDelivery(
        identifier: String
    ) {
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1
        ) { [weak self] in
            guard let self else {
                return
            }

            self.notificationService.isDelivered(
                identifier: identifier
            ) { [weak self] isDelivered in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }

                    if isDelivered {
                        self.notificationStatusText = "테스트 알림 전달 확인됨"
                    } else if self.notificationStatusText != "테스트 알림 표시 확인됨" {
                        self.notificationStatusText = "테스트 알림 전송 성공 · 배너 표시 설정 확인 필요"
                    }
                }
            }
        }
    }

    func refreshWindows() {
        guard ScreenCaptureAccessPolicy.canLoadWindows(
            hasPermission: CGPreflightScreenCaptureAccess()
        ) else {
            windows = []
            selectedWindowID = nil
            needsScreenRecordingPermission = true
            statusText = ScreenCaptureAccessPolicy.permissionRequiredMessage
            return
        }

        statusText = "창 목록 불러오는 중…"

        Task {
            do {
                let loadedWindows = try await captureService.loadWindows()
                windows = loadedWindows
                needsScreenRecordingPermission = false

                if let selectedWindowID,
                   !loadedWindows.contains(where: { $0.id == selectedWindowID }) {
                    self.selectedWindowID = nil
                }

                statusText = loadedWindows.isEmpty
                    ? "캡처 가능한 창이 없습니다. 화면 기록 권한을 확인하세요."
                    : "\(loadedWindows.count)개 창을 찾았습니다."
            } catch {
                needsScreenRecordingPermission = !CGPreflightScreenCaptureAccess()
                statusText = "창 목록 오류: \(error.localizedDescription)"
            }
        }
    }

    func requestScreenRecordingPermission() {
        statusText = "화면 기록 권한 요청 중…"

        let granted = CGRequestScreenCaptureAccess()

        guard granted else {
            windows = []
            selectedWindowID = nil
            needsScreenRecordingPermission = true
            statusText = "화면 기록 권한이 허용되지 않았습니다. 시스템 설정에서 Window Text Watcher을 허용하세요."
            return
        }

        needsScreenRecordingPermission = false
        statusText = "화면 기록 권한이 허용되었습니다. 창 목록을 불러옵니다…"
        refreshWindows()
    }

    func refreshWindowsIfAuthorized() {
        guard !isCapturing else {
            return
        }

        refreshWindows()
    }

    func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func startCapture() {
        guard !isCapturing, !isChangingCapture else {
            return
        }

        guard let selectedWindowID,
              let window = windows.first(where: { $0.id == selectedWindowID }) else {
            statusText = "먼저 캡처할 창을 선택하세요."
            return
        }

        statusText = "캡처 시작 중…"
        detectionGate.reset()
        captureSessionID = UUID()
        let sessionID = captureSessionID
        isCapturing = true
        isChangingCapture = true
        isOCRInFlight = false
        lastOCRDate = .distantPast
        latestFrame = nil
        recognizedText = ""
        isTargetDetected = false
        monitoringIssue = nil
        monitoringHealth.start(at: ProcessInfo.processInfo.systemUptime)
        startHealthTimer()

        Task {
            defer {
                isChangingCapture = false
            }
            do {
                try await captureService.start(window: window)
                guard captureSessionID == sessionID else {
                    return
                }
                statusText = "캡처 중 · 미리보기에서 OCR 영역을 드래그하세요."
            } catch {
                guard captureSessionID == sessionID else {
                    return
                }
                handleCaptureFailure(error)
            }
        }
    }

    func stopCapture() {
        guard !isChangingCapture else {
            return
        }
        isChangingCapture = true
        isCapturing = false
        captureSessionID = UUID()
        healthTimer?.invalidate()
        healthTimer = nil
        monitoringHealth.stop()
        monitoringIssue = nil
        isOCRInFlight = false
        isTargetDetected = false
        statusText = "캡처가 중지되었습니다."

        Task {
            await captureService.stop()
            isChangingCapture = false
        }
    }

    private func startHealthTimer() {
        healthTimer?.invalidate()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkMonitoringHealth()
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        healthTimer = timer
    }

    private func checkMonitoringHealth() {
        let newIssue = monitoringHealth.check(
            at: ProcessInfo.processInfo.systemUptime,
            cooldown: cooldownSeconds
        )
        monitoringIssue = monitoringHealth.issue
        if monitoringIssue != nil {
            isTargetDetected = false
        }
        if let newIssue {
            notificationService.sendMonitoringFailureNotification(issue: newIssue) { [weak self] result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        self?.notificationStatusText = "감시 이상 알림 전송 실패: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func handleCaptureFailure(_ error: Error) {
        guard isCapturing else {
            return
        }
        monitoringHealth.streamFailed()
        checkMonitoringHealth()
        isCapturing = false
        captureSessionID = UUID()
        isOCRInFlight = false
        isTargetDetected = false
        statusText = "캡처 중단: \(error.localizedDescription)"
    }

    func resetRegion() {
        region = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    private func handleFrame(_ image: CGImage) {
        guard isCapturing else {
            return
        }
        latestFrame = image
        monitoringHealth.receivedFrame(at: ProcessInfo.processInfo.systemUptime)
        processLatestFrame()
    }

    private func processLatestFrame() {
        guard isCapturing,
              let image = latestFrame,
              !isOCRInFlight,
              Date().timeIntervalSince(lastOCRDate) >= ocrInterval else {
            return
        }

        isOCRInFlight = true
        lastOCRDate = Date()
        let currentRegion = region
        let sessionID = captureSessionID
        monitoringHealth.ocrStarted(at: ProcessInfo.processInfo.systemUptime)

        ocrService.recognize(
            image: image,
            topLeftNormalizedRegion: currentRegion
        ) { [weak self] result in
            guard let self,
                  self.isCapturing,
                  self.captureSessionID == sessionID else {
                return
            }

            self.isOCRInFlight = false

            switch result {
            case .success(let text):
                self.monitoringHealth.ocrFinished(
                    succeeded: true,
                    at: ProcessInfo.processInfo.systemUptime
                )
                self.handleRecognizedText(text)
                self.statusText = "캡처 중 · 미리보기에서 OCR 영역을 드래그하세요."
            case .failure(let error):
                self.monitoringHealth.ocrFinished(
                    succeeded: false,
                    at: ProcessInfo.processInfo.systemUptime
                )
                self.statusText = "OCR 오류: \(error.localizedDescription)"
            }
            self.checkMonitoringHealth()
        }
    }

    private func handleRecognizedText(_ text: String) {
        recognizedText = text

        let matcher = TextMatcher(
            target: targetText,
            caseSensitive: caseSensitive
        )
        let isMatch = matcher.matches(text)
        isTargetDetected = isMatch
        detectionGate.cooldown = max(0, cooldownSeconds)

        if detectionGate.shouldNotify(isMatch: isMatch) {
            notificationService.sendDetectedNotification(
                target: targetText,
                recognizedText: text
            )
        }
    }
}
