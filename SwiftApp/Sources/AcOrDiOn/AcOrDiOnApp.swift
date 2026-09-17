import SwiftUI
import AppKit

@main
struct AcOrDiOnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var accordionState = AccordionState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accordionState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var keyboardMonitor = KeyboardMonitor.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: applicationDidFinishLaunching")
        
        // Activate the app immediately
        NSApp.activate(ignoringOtherApps: true)
        
        // Also activate after a short delay to ensure window is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(window.contentView)
                print("AppDelegate: Window activated - \(window.title)")
            }
        }
        
        keyboardMonitor.startMonitoring()
        print("AcOrDiOn: Keyboard monitor started")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stopMonitoring()
        HingeSensor.shared.stop()
        AccordionSynth.shared.stop()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        print("AppDelegate: App became active")
    }
}

@MainActor
class AccordionState: ObservableObject {
    @Published var currentAngle: Double = 90.0
    @Published var angularVelocity: Double = 0.0
    @Published var volume: Double = 0.5
    @Published var octave: Int = 4
    @Published var activeNotes: Set<UInt8> = []
    @Published var sustain: Bool = false
    @Published var mode: Int = 0  // 0: Piano, 1: Button
    
    static let modeNames = ["Piano Mode", "Button Accordion"]
}
