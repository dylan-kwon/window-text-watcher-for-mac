struct NotificationDeliveryVerifier {
    static func isDelivered(
        identifier: String,
        deliveredIdentifiers: [String]
    ) -> Bool {
        deliveredIdentifiers.contains(identifier)
    }
}
