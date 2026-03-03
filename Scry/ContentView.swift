import SwiftUI

struct ContentView: View {
    @EnvironmentObject var controller: CaptureController

    var body: some View {
        Group {
            if controller.needsAccessibility {
                Button("Grant Accessibility Access…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(statusText)
                    .foregroundStyle(.secondary)
            }
            Divider()
            Button("Quit Scry") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var statusText: String {
        guard let date = controller.lastCopied else {
            return "Press ⌘⇧4 to capture"
        }
        let seconds = Int(-date.timeIntervalSinceNow)
        switch seconds {
        case 0...5: return "Last copied: just now"
        case 6...59: return "Last copied: \(seconds)s ago"
        default:
            let mins = seconds / 60
            return "Last copied: \(mins)m ago"
        }
    }
}
