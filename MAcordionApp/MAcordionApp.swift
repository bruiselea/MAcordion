import SwiftUI
import MAcordionCore

@main
struct MAcordionApp: App {
    @StateObject private var keyboardHandler = KeyboardHandler()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(mode: .hinge)
                .environmentObject(keyboardHandler)
                .frame(minWidth: 980, minHeight: 680)
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            DiagnosticsSettingsView(mode: .hinge)
        }
    }
}
