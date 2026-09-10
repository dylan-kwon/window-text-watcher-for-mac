import Foundation

struct DetectionGate {
    var cooldown: TimeInterval

    private var lastNotificationDate: Date?

    init(cooldown: TimeInterval) {
        self.cooldown = max(0, cooldown)
    }

    mutating func shouldNotify(
        isMatch: Bool,
        now: Date = Date()
    ) -> Bool {
        guard isMatch else {
            return false
        }

        if let lastNotificationDate,
           now.timeIntervalSince(lastNotificationDate) < cooldown {
            return false
        }

        lastNotificationDate = now
        return true
    }

    mutating func reset() {
        lastNotificationDate = nil
    }
}
