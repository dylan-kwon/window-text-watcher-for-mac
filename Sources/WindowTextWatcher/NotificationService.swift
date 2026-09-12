import Foundation
import UserNotifications

struct NotificationMessage {
    let title: String
    let body: String

    static func detected(
        target: String,
        recognizedText: String
    ) -> NotificationMessage {
        let singleLine = recognizedText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let preview = String(singleLine.prefix(120))
        let body: String

        if preview.isEmpty {
            body = "감지 문자열: \(target)"
        } else {
            body = "\(target) 감지됨 · \(preview)"
        }

        return NotificationMessage(
            title: "OCR 텍스트 감지",
            body: body
        )
    }

    static func monitoringFailure(issue: MonitoringIssue) -> NotificationMessage {
        NotificationMessage(
            title: "실시간 감시 이상",
            body: issue.message
        )
    }

    static let test = NotificationMessage(
        title: "Window Text Watcher",
        body: "시스템 테스트 알림이 정상적으로 전달되었습니다."
    )
}

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    var onPresented: ((String) -> Void)?

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization(
        completion: ((Bool) -> Void)? = nil
    ) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            completion?(granted)
        }
    }

    func getAuthorizationStatus(
        completion: @escaping (UNAuthorizationStatus) -> Void
    ) {
        center.getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    func sendDetectedNotification(
        target: String,
        recognizedText: String
    ) {
        send(
            NotificationMessage.detected(
            target: target,
            recognizedText: recognizedText
            )
        )
    }

    func sendMonitoringFailureNotification(
        issue: MonitoringIssue,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        send(
            .monitoringFailure(issue: issue),
            identifier: "monitoring-\(UUID().uuidString)",
            completion: completion
        )
    }

    func sendTestNotification(
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        send(
            .test,
            identifier: "test-\(UUID().uuidString)",
            completion: completion
        )
    }

    func isDelivered(
        identifier: String,
        completion: @escaping (Bool) -> Void
    ) {
        center.getDeliveredNotifications { notifications in
            let identifiers = notifications.map { notification in
                notification.request.identifier
            }
            completion(
                NotificationDeliveryVerifier.isDelivered(
                    identifier: identifier,
                    deliveredIdentifiers: identifiers
                )
            )
        }
    }

    private func send(
        _ message: NotificationMessage,
        identifier: String = UUID().uuidString,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                completion?(.failure(error))
                return
            }

            completion?(.success(identifier))
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        onPresented?(notification.request.identifier)
        completionHandler([.banner, .sound])
    }

}
