struct LaunchOptions {
    let shouldSendTestNotification: Bool

    init(arguments: [String]) {
        shouldSendTestNotification = arguments.contains(
            "--test-notification"
        )
    }
}
