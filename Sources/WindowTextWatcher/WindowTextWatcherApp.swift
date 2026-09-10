import SwiftUI

@main
struct WindowTextWatcherApp: App {
    @StateObject private var model = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 1120, height: 760)
    }
}
