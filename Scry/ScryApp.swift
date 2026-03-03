import SwiftUI

@main
struct ScryApp: App {
    @StateObject private var controller = CaptureController()

    var body: some Scene {
        MenuBarExtra("Scry", systemImage: "camera.on.rectangle") {
            ContentView()
                .environmentObject(controller)
        }
        .menuBarExtraStyle(.menu)
    }
}
